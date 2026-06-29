#!/usr/bin/env bats
# =============================================================================
# Integration Tests: hook-bench baseline 鮮度 warn (pre-tool-use.sh)
# =============================================================================
# references/on-demand-rules/measure-before-hook-change.md の hook 強制実装。
# claude-code/hooks/*.sh を Edit / Write する際、24h 以内の baseline log が
# なければ warn を出す (block ではなく warn-only / exit 0)。

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"
  export ORIGINAL_HOME="$HOME"
  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude/logs"
  mkdir -p "$HOME/.claude/session-logs"
  export CLAUDE_CTX_FILE="${HOME}/_ctx_pct_unset"
  export CLAUDE_SERENA_FAIL_COUNT="${HOME}/_serena_unset"
}

teardown() {
  if [[ "$HOME" != "$ORIGINAL_HOME" && "$HOME" == /tmp/* ]]; then
    rm -rf "$HOME"
  fi
  export HOME="$ORIGINAL_HOME"
}

# =============================================================================
# warn 発火: baseline 0 件
# =============================================================================

@test "hook-bench-warn: baseline 未取得で hooks/*.sh Edit すると warn (exit 0)" {
  local input
  input=$(jq -n \
    '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/claude-code/hooks/pre-tool-use.sh", "old_string": "foo", "new_string": "bar"}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "hook-bench" ]]
  [[ "$output" =~ "未取得" ]]
}

@test "hook-bench-warn: baseline 未取得で hooks/*.sh Write すると warn (exit 0)" {
  local input
  input=$(jq -n \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/claude-code/hooks/session-start.sh", "content": "#!/bin/bash\necho hi"}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "hook-bench" ]]
}

# =============================================================================
# warn 発火: 古 baseline (>24h)
# =============================================================================

@test "hook-bench-warn: 25h 前の baseline で hooks/*.sh Edit すると warn (exit 0)" {
  local stale_log="$HOME/.claude/logs/hook-bench-stale.log"
  touch "$stale_log"
  # 25h = 90000 sec 前に mtime 設定 (-A は macOS / -d は linux 両対応で touch -t を使う)
  local ts
  ts=$(date -v-25H +%Y%m%d%H%M.%S 2>/dev/null || date -d '-25 hours' +%Y%m%d%H%M.%S)
  touch -t "$ts" "$stale_log"

  local input
  input=$(jq -n \
    '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/claude-code/hooks/pre-tool-use.sh", "old_string": "foo", "new_string": "bar"}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "hook-bench" ]]
  [[ "$output" =~ ">24h" ]]
}

# =============================================================================
# warn しない: 新鮮 baseline (<24h)
# =============================================================================

@test "hook-bench-warn: 鮮度 OK baseline (1h 前) なら warn しない" {
  local fresh_log="$HOME/.claude/logs/hook-bench-fresh.log"
  touch "$fresh_log"
  local ts
  ts=$(date -v-1H +%Y%m%d%H%M.%S 2>/dev/null || date -d '-1 hours' +%Y%m%d%H%M.%S)
  touch -t "$ts" "$fresh_log"

  local input
  input=$(jq -n \
    '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/claude-code/hooks/pre-tool-use.sh", "old_string": "foo", "new_string": "bar"}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "hook-bench" ]]
}

# =============================================================================
# warn しない: 対象外 path
# =============================================================================

@test "hook-bench-warn: lib/*.sh Edit は warn しない (hooks/ ではない)" {
  local input
  input=$(jq -n \
    '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/claude-code/lib/common.sh", "old_string": "foo", "new_string": "bar"}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "hook-bench" ]]
}

@test "hook-bench-warn: hooks 配下でも .md Edit は warn しない (.sh のみ対象)" {
  local input
  input=$(jq -n \
    '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/claude-code/hooks/README.md", "old_string": "foo", "new_string": "bar"}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "hook-bench" ]]
}
