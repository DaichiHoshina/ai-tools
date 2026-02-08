#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hook-utils.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/hook-utils.sh"
}

# =============================================================================
# 正常系テスト: read_hook_input
# =============================================================================

@test "hook-utils: read_hook_input reads JSON from stdin" {
  local input='{"key": "value"}'
  run bash -c "source '$LIB_FILE' && echo '$input' | read_hook_input"
  [ "$status" -eq 0 ]
  [ "$output" = "$input" ]
}

@test "hook-utils: read_hook_input handles multi-line JSON" {
  local input=$'{\n  "key": "value",\n  "number": 123\n}'
  run bash -c "source '$LIB_FILE' && echo '$input' | read_hook_input"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "key" ]]
  [[ "$output" =~ "value" ]]
}

# =============================================================================
# 正常系テスト: get_field
# =============================================================================

@test "hook-utils: get_field extracts top-level string field" {
  local input='{"name": "test", "value": 123}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name'"
  [ "$status" -eq 0 ]
  [ "$output" = "test" ]
}

@test "hook-utils: get_field extracts top-level number field" {
  local input='{"name": "test", "value": 123}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'value'"
  [ "$status" -eq 0 ]
  [ "$output" = "123" ]
}

@test "hook-utils: get_field returns default for missing field" {
  local input='{"name": "test"}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'missing' 'default_value'"
  [ "$status" -eq 0 ]
  [ "$output" = "default_value" ]
}

@test "hook-utils: get_field returns empty for missing field without default" {
  local input='{"name": "test"}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'missing'"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# =============================================================================
# 正常系テスト: get_nested_field
# =============================================================================

@test "hook-utils: get_nested_field extracts nested field" {
  local input='{"workspace": {"current_dir": "/home/user"}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'workspace.current_dir'"
  [ "$status" -eq 0 ]
  [ "$output" = "/home/user" ]
}

@test "hook-utils: get_nested_field extracts deeply nested field" {
  local input='{"a": {"b": {"c": "deep_value"}}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a.b.c'"
  [ "$status" -eq 0 ]
  [ "$output" = "deep_value" ]
}

@test "hook-utils: get_nested_field returns default for missing nested path" {
  local input='{"workspace": {"current_dir": "/home/user"}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'workspace.missing' 'default'"
  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "hook-utils: get_field handles invalid JSON gracefully" {
  local input='invalid json'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name' 'fallback' 2>&1"
  # jq will fail, but we check that it doesn't crash
  [ "$status" -ne 0 ]
}

@test "hook-utils: get_field handles empty JSON object" {
  local input='{}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name' 'default'"
  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: get_field handles special characters in values" {
  local input='{"key": "value with spaces & special <chars>"}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'key'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "value with spaces" ]]
}

@test "boundary: get_field handles null value" {
  local input='{"key": null}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'key' 'default'"
  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

@test "boundary: get_nested_field handles array access" {
  local input='{"items": [{"name": "first"}, {"name": "second"}]}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'items[0].name'"
  [ "$status" -eq 0 ]
  [ "$output" = "first" ]
}

# =============================================================================
# 統合テスト
# =============================================================================

@test "integration: hook-utils functions work together" {
  local input='{"workspace": {"current_dir": "/home/user"}, "prompt": "test"}'

  # First extract nested field
  dir=$(bash -c "source '$LIB_FILE' && get_nested_field '$input' 'workspace.current_dir'")
  [ "$dir" = "/home/user" ]

  # Then extract top-level field
  prompt=$(bash -c "source '$LIB_FILE' && get_field '$input' 'prompt'")
  [ "$prompt" = "test" ]
}
