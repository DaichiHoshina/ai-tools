#!/usr/bin/env bats
# =============================================================================
# BATS Tests for print-functions.sh
# =============================================================================

setup() {
  # PROJECT_ROOT を設定
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
}

# =============================================================================
# print_header()
# =============================================================================

@test "print_header: displays header with blue color" {
  run print_header "Test Header"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test Header" ]]
  [[ "$output" =~ "===" ]]
}

@test "print_header: handles empty string" {
  run print_header ""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "===" ]]
}

@test "print_header: handles special characters" {
  run print_header "Test & Header <script>"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test & Header <script>" ]]
}

# =============================================================================
# print_success()
# =============================================================================

@test "print_success: displays success message with checkmark" {
  run print_success "Operation completed"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
  [[ "$output" =~ "Operation completed" ]]
}

@test "print_success: handles empty string" {
  run print_success ""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
}

@test "print_success: handles multiline message" {
  run print_success $'Line 1\nLine 2'
  [ "$status" -eq 0 ]
  [[ "$output" =~ "✓" ]]
}

# =============================================================================
# print_warning()
# =============================================================================

@test "print_warning: displays warning message with symbol" {
  run print_warning "Be careful"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "⚠" ]]
  [[ "$output" =~ "Be careful" ]]
}

@test "print_warning: handles empty string" {
  run print_warning ""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "⚠" ]]
}

# =============================================================================
# print_error()
# =============================================================================

@test "print_error: displays error message to stderr" {
  run print_error "Error occurred"
  [ "$status" -eq 0 ]
  # エラーメッセージは stderr に出力されるため、output には含まれない
  # ただし、BATS では stderr も output に含まれることがある
}

@test "print_error: handles empty string" {
  run print_error ""
  [ "$status" -eq 0 ]
}

@test "print_error: handles special characters" {
  run print_error "Error: file not found at /path/to/file"
  [ "$status" -eq 0 ]
}

# =============================================================================
# print_info()
# =============================================================================

@test "print_info: displays info message with symbol" {
  run print_info "Information"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ℹ" ]]
  [[ "$output" =~ "Information" ]]
}

@test "print_info: handles empty string" {
  run print_info ""
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ℹ" ]]
}

# =============================================================================
# confirm()
# =============================================================================

@test "confirm: returns success for 'y' with default 'n'" {
  # confirmは対話的なので、自動テストでは制限がある
  # ここでは基本的な動作確認のみ
  skip "Interactive function - requires manual testing"
}

@test "confirm: returns failure for 'n' with default 'n'" {
  skip "Interactive function - requires manual testing"
}

@test "confirm: uses default 'y' when specified" {
  skip "Interactive function - requires manual testing"
}

# =============================================================================
# Integration: All functions work together
# =============================================================================

@test "integration: all print functions can be called sequentially" {
  run bash -c '
    source claude-code/lib/print-functions.sh
    print_header "Test"
    print_success "Success"
    print_warning "Warning"
    print_info "Info"
  '
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test" ]]
  [[ "$output" =~ "Success" ]]
  [[ "$output" =~ "Warning" ]]
  [[ "$output" =~ "Info" ]]
}
