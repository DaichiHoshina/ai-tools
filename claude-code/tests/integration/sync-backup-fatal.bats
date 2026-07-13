#!/usr/bin/env bats
# =============================================================================
# Regression: create_backup の部分失敗を fatal 化する
#
#   backup 対象 item の cp -a が失敗しても warning のみで sync_to_local が
#   続行し、backup が漏れたまま上書きが進んでいた問題の修正確認。
#   live file の permission には依存せず、backup 先への cp のみを失敗させる
#   fake cp を PATH 前段に注入し、「backup のみ失敗・本体同期は成功しうる」
#   経路を再現する（backup 失敗の abort が本体同期の成否と無関係に効くことの確認）。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export TEST_HOME="$(mktemp -d)"
  export CLAUDE_DIR="${TEST_HOME}/.claude"
  mkdir -p "$CLAUDE_DIR"

  # backup 先 (.sync-backups 配下) への CLAUDE.md の cp のみ失敗させる fake cp。
  # それ以外の cp 呼び出し（本体同期側）は本物の cp に委譲する。
  export FAKE_BIN_DIR="${TEST_HOME}/fakebin"
  mkdir -p "$FAKE_BIN_DIR"
  cat > "${FAKE_BIN_DIR}/cp" <<'EOF'
#!/bin/bash
args=("$@")
last="${args[$((${#args[@]} - 1))]}"
for a in "${args[@]}"; do
  if [[ "$a" == *"/CLAUDE.md" ]]; then
    if [[ "$last" == *".sync-backups"* ]]; then
      exit 1
    fi
  fi
done
exec /bin/cp "$@"
EOF
  chmod +x "${FAKE_BIN_DIR}/cp"
}

teardown() {
  [ -n "$TEST_HOME" ] && rm -rf "$TEST_HOME"
}

run_sync() {
  run env HOME="$TEST_HOME" CLAUDE_DIR="$CLAUDE_DIR" SKIP_GIT_CHECK=true \
    bash "${PROJECT_ROOT}/claude-code/sync.sh" "$@"
}

run_sync_with_fake_cp() {
  run env HOME="$TEST_HOME" CLAUDE_DIR="$CLAUDE_DIR" SKIP_GIT_CHECK=true \
    PATH="${FAKE_BIN_DIR}:${PATH}" \
    bash "${PROJECT_ROOT}/claude-code/sync.sh" "$@"
}

sync_once() {
  env HOME="$TEST_HOME" CLAUDE_DIR="$CLAUDE_DIR" SKIP_GIT_CHECK=true \
    bash "${PROJECT_ROOT}/claude-code/sync.sh" to-local --yes > /dev/null 2>&1
}

@test "backup 先への cp のみ失敗すると、本体同期が可能でも上書き前に中断する" {
  sync_once
  [ -f "$CLAUDE_DIR/CLAUDE.md" ]
  local before_content
  before_content=$(cat "$CLAUDE_DIR/CLAUDE.md")

  run_sync_with_fake_cp to-local --yes
  [ "$status" -ne 0 ]
  [[ "$output" =~ "backup" ]]

  # 上書きされていないこと（backup 失敗で中断したため repo 側の内容に置き換わっていない）
  local after_content
  after_content=$(cat "$CLAUDE_DIR/CLAUDE.md")
  [ "$before_content" = "$after_content" ]
}

@test "backup が全 item 成功すれば従来どおり sync が続行される" {
  sync_once
  run_sync to-local --yes
  [ "$status" -eq 0 ]
  [ -d "$CLAUDE_DIR/.sync-backups" ]
}
