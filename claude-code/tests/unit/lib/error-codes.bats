#!/usr/bin/env bats
# =============================================================================
# BATS Tests for error-codes.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
}

# =============================================================================
# エラーメッセージ取得
# =============================================================================

@test "error-codes: get_error_message returns timeout message" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && get_error_message E1001"
  [ "$status" -eq 0 ]
  [ "$output" = "Session timeout" ]
}

@test "error-codes: get_error_message returns lock message" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && get_error_message E2001"
  [ "$status" -eq 0 ]
  [ "$output" = "Lock acquisition failed" ]
}

@test "error-codes: get_error_message returns progress message" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && get_error_message E3001"
  [ "$status" -eq 0 ]
  [ "$output" = "Progress file read error" ]
}

@test "error-codes: get_error_message returns input message" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && get_error_message E4001"
  [ "$status" -eq 0 ]
  [ "$output" = "Invalid input parameter" ]
}

@test "error-codes: get_error_message returns sampling message" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && get_error_message E5001"
  [ "$status" -eq 0 ]
  [ "$output" = "Invalid sample rate" ]
}

@test "error-codes: get_error_message returns unknown for invalid code" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && get_error_message E9999"
  [ "$status" -eq 0 ]
  [ "$output" = "Unknown error" ]
}

# =============================================================================
# カテゴリ取得
# =============================================================================

@test "error-codes: get_error_category returns correct category" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && get_error_category E1001"
  [ "$status" -eq 0 ]
  [ "$output" = "Timeout" ]
}

# =============================================================================
# エラー出力
# =============================================================================

@test "error-codes: emit_error outputs to stderr" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && emit_error E1001 'test detail' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ERROR [E1001]: Session timeout - test detail" ]]
}

@test "error-codes: emit_error outputs without detail" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && emit_error E1001 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ERROR [E1001]: Session timeout" ]]
  [[ ! "$output" =~ " - " ]]
}

# =============================================================================
# JSON出力
# =============================================================================

@test "error-codes: error_json outputs valid JSON" {
  run bash -c "source '$PROJECT_ROOT/lib/error-codes.sh' && error_json E1001 'test detail'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "\"error\":" ]]
  [[ "$output" =~ "\"code\": \"E1001\"" ]]
  [[ "$output" =~ "\"category\": \"Timeout\"" ]]
  [[ "$output" =~ "\"message\": \"Session timeout\"" ]]
}
