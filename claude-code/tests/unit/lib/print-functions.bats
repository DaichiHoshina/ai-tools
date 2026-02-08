#!/usr/bin/env bats
# =============================================================================
# BATS Tests for print-functions.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/print-functions.sh"
}

# =============================================================================
# 正常系テスト: print_header
# =============================================================================

@test "print-functions: print_header outputs header with blue color" {
  run bash -c "source '$LIB_FILE' && print_header 'Test Header'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test Header" ]]
  [[ "$output" =~ "===" ]]
}

# =============================================================================
# 正常系テスト: print_success
# =============================================================================

@test "print-functions: print_success outputs with green checkmark" {
  run bash -c "source '$LIB_FILE' && print_success 'Task completed'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
  [[ "$output" =~ "Task completed" ]]
}

# =============================================================================
# 正常系テスト: print_warning
# =============================================================================

@test "print-functions: print_warning outputs with yellow warning sign" {
  run bash -c "source '$LIB_FILE' && print_warning 'Be careful'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "⚠" ]]
  [[ "$output" =~ "Be careful" ]]
}

# =============================================================================
# 正常系テスト: print_error
# =============================================================================

@test "print-functions: print_error outputs to stderr with red X" {
  run bash -c "source '$LIB_FILE' && print_error 'Something failed' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✗" ]]
  [[ "$output" =~ "Something failed" ]]
}

# =============================================================================
# 正常系テスト: print_info
# =============================================================================

@test "print-functions: print_info outputs with blue info icon" {
  run bash -c "source '$LIB_FILE' && print_info 'Information message'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ℹ" ]]
  [[ "$output" =~ "Information message" ]]
}

# =============================================================================
# 正常系テスト: confirm
# =============================================================================

@test "print-functions: confirm returns 0 for 'y' input (default N)" {
  run bash -c "source '$LIB_FILE' && echo 'y' | confirm 'Proceed?'"
  [ "$status" -eq 0 ]
}

@test "print-functions: confirm returns 1 for 'n' input (default N)" {
  run bash -c "source '$LIB_FILE' && echo 'n' | confirm 'Proceed?'"
  [ "$status" -eq 1 ]
}

@test "print-functions: confirm returns 1 for empty input (default N)" {
  run bash -c "source '$LIB_FILE' && echo '' | confirm 'Proceed?'"
  [ "$status" -eq 1 ]
}

@test "print-functions: confirm returns 0 for empty input (default Y)" {
  run bash -c "source '$LIB_FILE' && echo '' | confirm 'Proceed?' 'y'"
  [ "$status" -eq 0 ]
}

@test "print-functions: confirm returns 0 for 'Y' uppercase (default N)" {
  run bash -c "source '$LIB_FILE' && echo 'Y' | confirm 'Proceed?'"
  [ "$status" -eq 0 ]
}

# =============================================================================
# 統合テスト
# =============================================================================

@test "integration: all print functions can be sourced without errors" {
  run bash -c "source '$LIB_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "integration: print functions handle multi-line messages" {
  run bash -c "source '$LIB_FILE' && print_success 'Line 1\nLine 2'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Line 1" ]]
  [[ "$output" =~ "Line 2" ]]
}

@test "integration: print functions handle special characters" {
  run bash -c "source '$LIB_FILE' && print_info 'Test: \$VAR & <value>'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test:" ]]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: print functions handle empty string" {
  run bash -c "source '$LIB_FILE' && print_success ''"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
}

@test "boundary: print functions handle very long message" {
  long_msg=$(printf 'a%.0s' {1..1000})
  run bash -c "source '$LIB_FILE' && print_info '$long_msg'"
  [ "$status" -eq 0 ]
  [[ "${#output}" -gt 1000 ]]
}
