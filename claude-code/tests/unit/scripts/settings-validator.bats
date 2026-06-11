#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/settings-validator.sh
#
# 方針: source 可能性 + 主要関数定義の確認
#   本格 case (malformed JSON / hooks desync 等) は future task
# =============================================================================

setup() {
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/settings-validator.sh"
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"

  # caller (sync.sh) が定義する前提の外部依存を stub
  # bash -c サブシェルへ export -f で渡すため setup 内では直接呼び出しなし
  # shellcheck disable=SC2329
  check_jq()      { return 0; }
  # shellcheck disable=SC2329
  print_warning() { :; }
  # shellcheck disable=SC2329
  print_error()   { :; }
  # shellcheck disable=SC2329
  print_info()    { :; }
  # shellcheck disable=SC2329
  print_success() { :; }
  export -f check_jq print_warning print_error print_info print_success

  # 多重 source 防止フラグをリセット
  unset _SETTINGS_VALIDATOR_LOADED 2>/dev/null || true

  # sync.sh が設定する想定の環境変数（関数内参照のみ・今回は実呼び出しなし）
  export SCRIPT_DIR="${PROJECT_ROOT}"
  export CLAUDE_DIR="${TEST_TMPDIR}/.claude"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  unset _SETTINGS_VALIDATOR_LOADED 2>/dev/null || true
}

# =============================================================================
# Smoke: source 可能 + 主要関数定義確認
# =============================================================================

@test "smoke: script が source 可能で主要関数 sync_settings_hooks が defined になる" {
  # 実際に source し、関数定義を確認する（pass-by-coincidence 回避のため declare で検証）
  run bash -c "
    check_jq()      { return 0; }
    print_warning() { :; }
    print_error()   { :; }
    print_info()    { :; }
    print_success() { :; }
    export -f check_jq print_warning print_error print_info print_success

    unset _SETTINGS_VALIDATOR_LOADED
    # shellcheck disable=SC1090
    source "${SCRIPT_FILE}"

    # declare -f は関数が定義されていれば 0、未定義なら 1 を返す
    declare -f sync_settings_hooks > /dev/null
  "

  [[ $status -eq 0 ]]
}
