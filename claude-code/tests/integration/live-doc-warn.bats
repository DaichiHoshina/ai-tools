#!/usr/bin/env bats
# =============================================================================
# Integration Tests: Live Doc Required warn (pre-tool-use.sh)
# =============================================================================
# CLAUDE.md § Library API Live Doc Required の hook 検出を確認する。
# warn-only (exit 0) + additionalContext / systemMessage に warn 文が含まれることを確認する。

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
# warn 発火テスト
# =============================================================================

@test "live-doc-warn: useState を Write する場合に warn が出る (exit 0)" {
  local content="const [count, setCount] = useState(0);"
  local input
  input=$(jq -n \
    --arg content "$content" \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/Component.tsx", "content": $content}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  # warn 文が出力に含まれること
  [[ "$output" =~ "live-doc" ]]
}

@test "live-doc-warn: axios.create を Edit する場合に warn が出る (exit 0)" {
  local new_string="const client = axios.create({ baseURL: 'https://api.example.com' });"
  local input
  input=$(jq -n \
    --arg ns "$new_string" \
    '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/api-client.ts", "old_string": "// placeholder", "new_string": $ns}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "live-doc" ]]
}

@test "live-doc-warn: FastAPI( を Write する場合に warn が出る (exit 0)" {
  local content="app = FastAPI(title='My API')"
  local input
  input=$(jq -n \
    --arg content "$content" \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/main.py", "content": $content}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "live-doc" ]]
}

# =============================================================================
# 除外対象 (warn しない) テスト
# =============================================================================

@test "live-doc-warn: .sh ファイルへの Write は warn しない" {
  local content="useEffect_helper() { echo 'useState'; }"
  local input
  input=$(jq -n \
    --arg content "$content" \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/helper.sh", "content": $content}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  # .sh ファイルは除外なので live-doc warn は出ない
  [[ ! "$output" =~ "live-doc" ]]
}

@test "live-doc-warn: .bats ファイルへの Write は warn しない" {
  local content="# useState test case"
  local input
  input=$(jq -n \
    --arg content "$content" \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/test.bats", "content": $content}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "live-doc" ]]
}

@test "live-doc-warn: library keyword を含まない Write は warn しない" {
  local content="function greet() { return 'hello'; }"
  local input
  input=$(jq -n \
    --arg content "$content" \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/utils.ts", "content": $content}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "live-doc" ]]
}

@test "live-doc-warn: hook 自身のパス (hooks/) への Write は warn しない" {
  local content="# useEffect"
  local input
  input=$(jq -n \
    --arg content "$content" \
    '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/hooks/pre-tool-use.sh", "content": $content}}')
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "live-doc" ]]
}
