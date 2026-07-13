#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/hook-utils/json-io.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/hook-utils/json-io.sh"
}

@test "json-io: sourcing does not produce output" {
  run bash -c "source '$LIB_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# require_jq
# =============================================================================

@test "require_jq: jq がインストール済みなら exit 0" {
  run bash -c "source '$LIB_FILE' && require_jq && echo SUCCESS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SUCCESS" ]]
}

@test "require_jq: PATH から jq を外すと exit 1" {
  run -1 env -i PATH=/nonexistent HOME="$HOME" "$BASH" -c "source '$LIB_FILE' && require_jq"
}

# =============================================================================
# read_hook_input
# =============================================================================

@test "read_hook_input: stdin の JSON をそのまま返す" {
  local input='{"key": "value"}'
  run bash -c "source '$LIB_FILE' && echo '$input' | read_hook_input"
  [ "$status" -eq 0 ]
  [ "$output" = "$input" ]
}

# =============================================================================
# append_message
# =============================================================================

@test "append_message: 両空 → 空" {
  run bash -c "source '$LIB_FILE' && append_message '' ''"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "append_message: current 値 + addition 値 → 改行結合" {
  run bash -c "source '$LIB_FILE' && append_message 'first' 'second'"
  [ "$status" -eq 0 ]
  [ "$output" = $'first\nsecond' ]
}

# =============================================================================
# get_field
# =============================================================================

@test "get_field: top-level 文字列フィールド抽出" {
  local input='{"name": "test", "value": 123}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name'"
  [ "$status" -eq 0 ]
  [ "$output" = "test" ]
}

@test "get_field: 未定義フィールドは default を返す" {
  local input='{"name": "test"}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'missing' 'default_value'"
  [ "$status" -eq 0 ]
  [ "$output" = "default_value" ]
}

@test "get_field: 不正 JSON では jq が失敗し非 0 で終了する" {
  local input='not json'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name' 'fallback'"
  [ "$status" -ne 0 ]
}

# =============================================================================
# get_nested_field
# =============================================================================

@test "get_nested_field: nested field を抽出する" {
  local input='{"workspace": {"current_dir": "/home/user"}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'workspace.current_dir'"
  [ "$status" -eq 0 ]
  [ "$output" = "/home/user" ]
}

@test "get_nested_field: 不正な path 文字列は default を返す (jq injection 防止)" {
  local input='{"a": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a | length' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

# =============================================================================
# extract_json_fields
# =============================================================================

@test "extract_json_fields: 複数フィールドを TSV で取得する" {
  local input='{"a": "x", "b": "y", "c": "z"}'
  run bash -c "source '$LIB_FILE' && extract_json_fields '$input' '.a' '.b' '.c'"
  [ "$status" -eq 0 ]
  [ "$output" = $'x\ty\tz' ]
}

@test "extract_json_fields: 不正 JSON 入力では jq が失敗し非 0 で終了する" {
  local input='not json'
  run bash -c "source '$LIB_FILE' && extract_json_fields '$input' '.a'"
  [ "$status" -ne 0 ]
}
