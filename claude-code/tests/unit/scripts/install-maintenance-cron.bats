#!/usr/bin/env bats
# Smoke test: install-maintenance-cron.sh + maintenance-cron-run.sh
#   plist 生成 / worktree guard / --repo override / runner の claude 不在検知を確認する。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROJECT_ROOT
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/install-maintenance-cron.sh"
  export RUNNER_FILE="${PROJECT_ROOT}/scripts/maintenance-cron-run.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  # bats が worktree 配下から走る場合の guard 解除 (実 worktree test は別 case で挙動確認済)
  export MAINTENANCE_CRON_ALLOW_WT=1
}

teardown() {
  [[ -d "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
}

@test "--dry-run は plist 内容を表示するだけ" {
  run bash "$SCRIPT_FILE" --dry-run --repo "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "<key>Label</key>"
  echo "$output" | grep -q "com.daichi.ai-tools-maintenance.weekly"
  echo "$output" | grep -q "maintenance-cron-run.sh"
  # plist は配置されないこと
  [ ! -f "$TEST_HOME/Library/LaunchAgents/com.daichi.ai-tools-maintenance.weekly.plist" ]
}

@test "worktree path を REPO_ROOT に渡すと error で stop する" {
  WT_PATH="$TEST_HOME/ai-tools-wt-test/claude-code"
  mkdir -p "$WT_PATH/scripts"
  cp "$RUNNER_FILE" "$WT_PATH/scripts/"
  chmod +x "$WT_PATH/scripts/maintenance-cron-run.sh"

  unset MAINTENANCE_CRON_ALLOW_WT
  run bash "$SCRIPT_FILE" --dry-run --repo "$WT_PATH"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "worktree"
}

@test "maintenance-cron-run.sh 不在 path で error" {
  run bash "$SCRIPT_FILE" --dry-run --repo "$TEST_HOME/nowhere"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "見つかりません"
}

@test "通常実行は plist を配置して手順を表示する" {
  run bash "$SCRIPT_FILE" --repo "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/Library/LaunchAgents/com.daichi.ai-tools-maintenance.weekly.plist" ]
  echo "$output" | grep -q "launchctl bootstrap"
  echo "$output" | grep -q "uninstall:"
}

@test "--enable で plist 配置 + launchctl bootstrap まで走る (mock launchctl)" {
  MOCK_BIN="$TEST_HOME/bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/launchctl" <<'MOCK'
#!/usr/bin/env bash
echo "MOCK_LAUNCHCTL: $*" >> "$HOME/.mock-launchctl.log"
case "$1" in
  bootout)   exit 0 ;;
  bootstrap) exit 0 ;;
  print)     echo "state = running"; exit 0 ;;
  *)         exit 0 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/launchctl"
  PATH="$MOCK_BIN:$PATH" run bash "$SCRIPT_FILE" --enable --repo "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/Library/LaunchAgents/com.daichi.ai-tools-maintenance.weekly.plist" ]
  echo "$output" | grep -q "launchctl bootstrap 完了"
  grep -q "bootstrap gui/" "$TEST_HOME/.mock-launchctl.log"
}

@test "runner は claude CLI 不在で exit 2 する" {
  # PATH から claude を消した状態で runner を叩く
  run env PATH="/usr/bin:/bin" CLAUDE_BIN="" bash "$RUNNER_FILE"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "claude CLI が見つかりません"
}

@test "runner は mock claude で 3 command を順に実行して log に残す" {
  MOCK_BIN="$TEST_HOME/bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/claude" <<'MOCK'
#!/usr/bin/env bash
# -p <cmd> --fallback-model sonnet の <cmd> を echo する
echo "MOCK_CLAUDE ran: $2"
MOCK
  chmod +x "$MOCK_BIN/claude"
  run env CLAUDE_BIN="$MOCK_BIN/claude" bash "$RUNNER_FILE"
  [ "$status" -eq 0 ]
  log_file="$(echo "$output" | grep -o "${TEST_HOME}/.claude/logs/maintenance-cron-.*\.log")"
  [ -f "$log_file" ]
  grep -q "MOCK_CLAUDE ran: /memory-clean" "$log_file"
  grep -q "MOCK_CLAUDE ran: /claude-update-fix --dry-run" "$log_file"
  grep -q "MOCK_CLAUDE ran: /serena-update-fix --dry-run" "$log_file"
}
