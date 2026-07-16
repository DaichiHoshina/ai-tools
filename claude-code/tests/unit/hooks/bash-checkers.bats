#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/lib/bash-checkers.sh — _handle_bash_tool
# pre-tool-use.sh の "Bash") case 分岐から切り出した関数の挙動確認
# =============================================================================

setup() {
  load "../../helpers/common"
  load "../../helpers/hook-invoke"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  setup_test_tmpdir
  # hint 系の session dedup を test 単位で隔離 (bash-checkers.sh の flag file)
  export CLAUDE_CODE_SESSION_ID="bc-$$-${BATS_TEST_NUMBER}"
  rm -f "/tmp/claude-serena-hint-${CLAUDE_CODE_SESSION_ID}-"* \
        "/tmp/claude-cat-read-hint-${CLAUDE_CODE_SESSION_ID}-"* 2>/dev/null || true
}

teardown() {
  teardown_test_tmpdir
}

_run_bash_hook() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{command: $c}')
  invoke_hook "Bash" "$input"
}

@test "bash-checkers: go build ./... 全体実行は Forbidden (exit 2)" {
  run bash -c 'echo "$1" | bash "$2" 2>/dev/null' _ \
    "$(jq -n --arg c 'go build ./...' '{tool_name: "Bash", tool_input: {command: $c}}')" \
    "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "bash-checkers: go build ./pkg/foo/... はブロックされない" {
  result=$(_run_bash_hook "go build ./pkg/foo/...")
  msg=$(get_system_message "$result")
  [[ "$msg" != *"go build/test"* ]]
}

@test "bash-checkers: cat で .md を読むと Read ツール推奨 hint が additionalContext に入る" {
  result=$(_run_bash_hook "cat README.md")
  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "Read ツールを使うこと" ]]
}

@test "bash-checkers: 通常の ls コマンドは additionalContext / systemMessage 無し" {
  result=$(_run_bash_hook "ls -la")
  [ "$result" = "{}" ]
}
