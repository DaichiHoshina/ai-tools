#!/usr/bin/env bats
# Smoke test: install-hook-bench-cron.sh
#   plist 生成 / worktree guard / --repo override の動作確認。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROJECT_ROOT
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/install-hook-bench-cron.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  # bats が worktree 配下から走る場合の guard 解除 (実 worktree test は別 case で挙動確認済)
  export HOOK_BENCH_CRON_ALLOW_WT=1
}

teardown() {
  [[ -d "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
}

@test "--dry-run は plist 内容を表示するだけ" {
  run bash "$SCRIPT_FILE" --dry-run --repo "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "<key>Label</key>"
  echo "$output" | grep -q "com.daichi.hook-bench.weekly"
  # plist は配置されないこと
  [ ! -f "$TEST_HOME/Library/LaunchAgents/com.daichi.hook-bench.weekly.plist" ]
}

@test "worktree path を REPO_ROOT に渡すと error で stop する" {
  WT_PATH="$TEST_HOME/ai-tools-wt-test/claude-code"
  mkdir -p "$WT_PATH/scripts"
  cp "$PROJECT_ROOT/scripts/hook-bench.sh" "$WT_PATH/scripts/"
  chmod +x "$WT_PATH/scripts/hook-bench.sh"

  unset HOOK_BENCH_CRON_ALLOW_WT
  run bash "$SCRIPT_FILE" --dry-run --repo "$WT_PATH"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qE "worktree"
}

@test "hook-bench.sh 不在 path で error" {
  run bash "$SCRIPT_FILE" --dry-run --repo "$TEST_HOME/nowhere"
  [ "$status" -eq 2 ]
  echo "$output" | grep -q "見つかりません"
}

@test "通常実行は plist を配置して手順を表示する" {
  run bash "$SCRIPT_FILE" --repo "$PROJECT_ROOT"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/Library/LaunchAgents/com.daichi.hook-bench.weekly.plist" ]
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
  [ -f "$TEST_HOME/Library/LaunchAgents/com.daichi.hook-bench.weekly.plist" ]
  echo "$output" | grep -q "launchctl bootstrap 完了"
  grep -q "bootstrap gui/" "$TEST_HOME/.mock-launchctl.log"
}

@test "--enable で launchctl bootstrap 失敗時は exit 1" {
  MOCK_BIN="$TEST_HOME/bin"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/launchctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  bootout)   exit 0 ;;
  bootstrap) echo "bootstrap failed" >&2; exit 5 ;;
  *)         exit 0 ;;
esac
MOCK
  chmod +x "$MOCK_BIN/launchctl"
  PATH="$MOCK_BIN:$PATH" run bash "$SCRIPT_FILE" --enable --repo "$PROJECT_ROOT"
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "launchctl bootstrap 失敗"
}
