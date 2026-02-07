#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hook-utils.sh
# =============================================================================

setup() {
  # PROJECT_ROOT を設定
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_PATH="${PROJECT_ROOT}/claude-code/lib/hook-utils.sh"

  # テスト用のJSON入力
  TEST_JSON='{"field1": "value1", "field2": "value2", "workspace": {"current_dir": "/test/path"}}'
  TEST_EMPTY_JSON='{}'
}

# =============================================================================
# read_hook_input()
# =============================================================================

@test "read_hook_input: reads from stdin" {
  run bash -c "echo 'test input' | source '${LIB_PATH}' && read_hook_input"
  [ "$status" -eq 0 ]
  [[ "$output" == "test input" ]]
}

@test "read_hook_input: handles empty input" {
  run bash -c "echo '' | source '${LIB_PATH}' && read_hook_input"
  [ "$status" -eq 0 ]
  [[ "$output" == "" ]]
}

@test "read_hook_input: handles multiline input" {
  run bash -c "echo -e 'line1\nline2' | source '${LIB_PATH}' && read_hook_input"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "line1" ]]
  [[ "$output" =~ "line2" ]]
}

# =============================================================================
# get_field()
# =============================================================================

@test "get_field: extracts existing field" {
  run bash -c "source '${LIB_PATH}' && get_field '$TEST_JSON' 'field1'"
  [ "$status" -eq 0 ]
  [[ "$output" == "value1" ]]
}

@test "get_field: returns default for missing field" {
  run bash -c "source '${LIB_PATH}' && get_field '$TEST_JSON' 'missing_field' 'default_value'"
  [ "$status" -eq 0 ]
  [[ "$output" == "default_value" ]]
}

@test "get_field: returns empty string when no default provided" {
  run bash -c "source "${LIB_PATH}" && get_field '$TEST_JSON' 'missing_field'"
  [ "$status" -eq 0 ]
  [[ "$output" == "" ]]
}

@test "get_field: handles empty JSON" {
  run bash -c "source "${LIB_PATH}" && get_field '$TEST_EMPTY_JSON' 'field1' 'default'"
  [ "$status" -eq 0 ]
  [[ "$output" == "default" ]]
}

@test "get_field: handles special characters in value" {
  local json='{"field": "value with spaces & symbols <>"}'
  run bash -c "source "${LIB_PATH}" && get_field '$json' 'field'"
  [ "$status" -eq 0 ]
  [[ "$output" == "value with spaces & symbols <>" ]]
}

# =============================================================================
# get_nested_field()
# =============================================================================

@test "get_nested_field: extracts nested field" {
  run bash -c "source "${LIB_PATH}" && get_nested_field '$TEST_JSON' 'workspace.current_dir'"
  [ "$status" -eq 0 ]
  [[ "$output" == "/test/path" ]]
}

@test "get_nested_field: returns default for missing nested field" {
  run bash -c "source "${LIB_PATH}" && get_nested_field '$TEST_JSON' 'workspace.missing' 'default_path'"
  [ "$status" -eq 0 ]
  [[ "$output" == "default_path" ]]
}

@test "get_nested_field: handles deep nesting" {
  local deep_json='{"level1": {"level2": {"level3": "deep_value"}}}'
  run bash -c "source "${LIB_PATH}" && get_nested_field '$deep_json' 'level1.level2.level3'"
  [ "$status" -eq 0 ]
  [[ "$output" == "deep_value" ]]
}

@test "get_nested_field: handles empty JSON" {
  run bash -c "source "${LIB_PATH}" && get_nested_field '$TEST_EMPTY_JSON' 'workspace.current_dir' '.'"
  [ "$status" -eq 0 ]
  [[ "$output" == "." ]]
}

@test "get_nested_field: handles null values" {
  local null_json='{"workspace": {"current_dir": null}}'
  run bash -c "source "${LIB_PATH}" && get_nested_field '$null_json' 'workspace.current_dir' 'default'"
  [ "$status" -eq 0 ]
  [[ "$output" == "default" ]]
}

# =============================================================================
# Integration: Real-world hook input
# =============================================================================

@test "integration: parse SessionStart hook input" {
  local session_input='{
    "session_id": "test123",
    "workspace": {
      "current_dir": "/Users/test/project"
    },
    "mcp_servers": {
      "serena": {}
    }
  }'

  run bash -c "source "${LIB_PATH}" && get_field '$session_input' 'session_id'"
  [ "$status" -eq 0 ]
  [[ "$output" == "test123" ]]

  run bash -c "source "${LIB_PATH}" && get_nested_field '$session_input' 'workspace.current_dir'"
  [ "$status" -eq 0 ]
  [[ "$output" == "/Users/test/project" ]]
}

@test "integration: parse UserPromptSubmit hook input" {
  local prompt_input='{
    "prompt": "Fix the authentication bug",
    "workspace": {
      "current_dir": "/Users/test/app"
    }
  }'

  run bash -c "source "${LIB_PATH}" && get_field '$prompt_input' 'prompt'"
  [ "$status" -eq 0 ]
  [[ "$output" == "Fix the authentication bug" ]]
}

@test "integration: handle missing jq gracefully" {
  skip "Requires mocking jq absence - complex test scenario"
}
