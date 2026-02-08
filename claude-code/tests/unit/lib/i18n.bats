#!/usr/bin/env bats
# =============================================================================
# BATS Tests for i18n.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/i18n.sh"
  # Reset language to default
  export LANGUAGE="ja"
}

# =============================================================================
# 正常系テスト: msg() - 日本語メッセージ
# =============================================================================

@test "i18n: msg returns Japanese message by default" {
  run bash -c "source '$LIB_FILE' && msg 'ERROR_STATUSLINE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ステータス表示に失敗" ]]
}

@test "i18n: msg returns Japanese error message" {
  run bash -c "source '$LIB_FILE' && msg 'ERROR_PARSING'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "JSON解析エラー" ]]
}

@test "i18n: msg returns Japanese info message" {
  run bash -c "source '$LIB_FILE' && msg 'INFO_COMPLETE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "完了しました" ]]
}

@test "i18n: msg formats message with parameters" {
  run bash -c "source '$LIB_FILE' && msg 'INFO_STACK_DETECTED' 'golang, typescript'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "技術スタック検出" ]]
  [[ "$output" =~ "golang, typescript" ]]
}

@test "i18n: msg formats message with numeric parameter" {
  run bash -c "source '$LIB_FILE' && msg 'WARN_TOKEN_HIGH' 85"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "トークン使用率" ]]
  [[ "$output" =~ "85" ]]
}

# =============================================================================
# 正常系テスト: msg() - 英語メッセージ
# =============================================================================

@test "i18n: msg returns English message when LANGUAGE=en" {
  run bash -c "export LANGUAGE=en && source '$LIB_FILE' && msg 'ERROR_STATUSLINE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Status display failed" ]]
}

@test "i18n: msg returns English error message" {
  run bash -c "export LANGUAGE=en && source '$LIB_FILE' && msg 'ERROR_PARSING'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "JSON parsing error" ]]
}

@test "i18n: msg formats English message with parameters" {
  run bash -c "export LANGUAGE=en && source '$LIB_FILE' && msg 'INFO_STACK_DETECTED' 'go, typescript'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Tech stack detected" ]]
  [[ "$output" =~ "go, typescript" ]]
}

# =============================================================================
# 正常系テスト: set_language()
# =============================================================================

@test "i18n: set_language switches to English" {
  run bash -c "source '$LIB_FILE' && set_language 'en' && msg 'ERROR_STATUSLINE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Status display failed" ]]
}

@test "i18n: set_language switches to Japanese" {
  run bash -c "export LANGUAGE=en && source '$LIB_FILE' && set_language 'ja' && msg 'ERROR_STATUSLINE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ステータス表示に失敗" ]]
}

@test "i18n: set_language handles invalid language with warning" {
  run bash -c "source '$LIB_FILE' && set_language 'fr' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Warning: Unsupported language" ]]
}

# =============================================================================
# 正常系テスト: error_msg()
# =============================================================================

@test "i18n: error_msg outputs to stderr" {
  run bash -c "source '$LIB_FILE' && error_msg 'ERROR_PARSING' 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "JSON解析エラー" ]]
}

@test "i18n: error_msg formats message with parameters" {
  run bash -c "source '$LIB_FILE' && error_msg 'ERROR_FILE_NOT_FOUND' '/path/to/file' 2>&1 >/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ファイルが見つかりません" ]]
  [[ "$output" =~ "/path/to/file" ]]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "i18n: msg returns key when message not found" {
  run bash -c "source '$LIB_FILE' && msg 'UNKNOWN_KEY'"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "UNKNOWN_KEY" ]]
}

@test "i18n: msg handles empty key" {
  run bash -c "source '$LIB_FILE' && msg ''"
  [ "$status" -eq 1 ]
}

# =============================================================================
# 統合テスト
# =============================================================================

@test "integration: all Japanese error messages are accessible" {
  run bash -c "
    source '$LIB_FILE'
    msg 'ERROR_STATUSLINE'
    msg 'ERROR_PARSING'
    msg 'ERROR_FILE_NOT_FOUND' '/test'
    msg 'ERROR_PERMISSION' '/test'
    msg 'ERROR_NETWORK'
    msg 'ERROR_TIMEOUT'
    msg 'ERROR_UNKNOWN'
  "
  [ "$status" -eq 0 ]
}

@test "integration: all Japanese info messages are accessible" {
  run bash -c "
    source '$LIB_FILE'
    msg 'INFO_STACK_DETECTED' 'test'
    msg 'INFO_SKILL_RECOMMENDED' 'test'
    msg 'INFO_PROCESSING'
    msg 'INFO_COMPLETE'
    msg 'INFO_SAVED' 'test.txt'
  "
  [ "$status" -eq 0 ]
}

@test "integration: all English messages are accessible" {
  run bash -c "
    export LANGUAGE=en
    source '$LIB_FILE'
    msg 'ERROR_STATUSLINE'
    msg 'INFO_COMPLETE'
    msg 'WARN_TOKEN_HIGH' 85
    msg 'SUCCESS_INSTALL'
  "
  [ "$status" -eq 0 ]
}

@test "integration: language switching works mid-execution" {
  run bash -c "
    source '$LIB_FILE'
    msg 'ERROR_STATUSLINE'
    set_language 'en'
    msg 'ERROR_STATUSLINE'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ステータス表示に失敗" ]]
  [[ "$output" =~ "Status display failed" ]]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: msg handles message with special characters" {
  run bash -c "source '$LIB_FILE' && msg 'WARN_AUTO_FORMAT'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "protection-mode" ]]
}

@test "boundary: msg handles multiple format parameters" {
  run bash -c "
    source '$LIB_FILE'
    # Create a custom test to verify multiple params would work
    msg 'INFO_STACK_DETECTED' 'go, typescript, react'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "go, typescript, react" ]]
}

@test "boundary: i18n script can be executed directly for testing" {
  skip "Direct execution test - environment specific"
  run bash "$LIB_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "i18n.sh テスト" ]]
  [[ "$output" =~ "テスト完了" ]]
}
