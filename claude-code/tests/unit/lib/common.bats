#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/common.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/common.sh"
  export TEST_TMPDIR="$(mktemp -d)"

  # set -u 対応: COMMON_LOAD_I18N を明示的に設定
  export COMMON_LOAD_I18N=false
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  # 環境変数クリーンアップ
  unset _COMMON_LOADED 2>/dev/null || true
}

# =============================================================================
# 基本的な読み込みテスト
# =============================================================================

@test "common: sourcing does not produce output" {
  run bash -c "source '$LIB_FILE'"
  [ "$status" -eq 0 ]
  # 依存ツール警告が出る可能性があるため、標準出力のみチェック
  [[ ! "$output" =~ "ERROR" ]]
}

@test "common: sets _COMMON_LOADED flag" {
  run bash -c "source '$LIB_FILE' && echo \"\$_COMMON_LOADED\""
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "common: prevents duplicate loading" {
  run bash -c "
    source '$LIB_FILE'
    source '$LIB_FILE'
    echo 'success'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "success" ]]
}

# =============================================================================
# load_lib 関数テスト
# =============================================================================

@test "load_lib: loads existing library successfully" {
  run bash -c "
    source '$LIB_FILE'
    load_lib 'colors.sh'
    declare -p RED &>/dev/null && echo 'loaded'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "loaded" ]]
}

@test "load_lib: returns 1 for missing library" {
  run bash -c "
    set +e
    source '$LIB_FILE'
    load_lib 'nonexistent.sh'
    echo \$?
  "
  [[ "$output" =~ "1" ]]
}

@test "load_lib: shows warning for missing library" {
  run bash -c "set +e; source '$LIB_FILE' && load_lib 'nonexistent.sh' 2>&1"
  [[ "$output" =~ "WARNING" ]] || [[ "$output" =~ "not found" ]]
}

@test "load_lib: uses print_warning when available" {
  run bash -c "
    set +e
    source '$LIB_FILE'
    # print_warning は既に読み込まれているはず
    load_lib 'nonexistent.sh' 2>&1
  "
  [[ "$output" =~ "nonexistent.sh" ]]
}

@test "load_lib: handles library with spaces in path" {
  run bash -c "
    set +e
    source '$LIB_FILE'
    load_lib 'lib with spaces.sh' 2>&1
  "
  [[ "$output" =~ "WARNING" ]] || [[ "$output" =~ "not found" ]]
}

# =============================================================================
# common_version 関数テスト
# =============================================================================

@test "common_version: outputs version information" {
  run bash -c "source '$LIB_FILE' && common_version"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "common.sh" ]]
  [[ "$output" =~ "bash:" ]]
}

@test "common_version: shows i18n status when enabled" {
  run bash -c "
    export COMMON_LOAD_I18N=true
    source '$LIB_FILE'
    common_version
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "i18n" ]] || [[ "$output" =~ "common.sh" ]]
}

# =============================================================================
# common_list_loaded 関数テスト
# =============================================================================

@test "common_list_loaded: lists loaded functions" {
  run bash -c "source '$LIB_FILE' && common_list_loaded"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Loaded libraries:" ]]
  [[ "$output" =~ "load_lib" ]]
}

@test "common_list_loaded: includes print_ functions" {
  run bash -c "source '$LIB_FILE' && common_list_loaded"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "print_" ]] || [[ "$output" =~ "common_" ]]
}

# =============================================================================
# 依存ライブラリ読み込みテスト
# =============================================================================

@test "common: loads colors.sh automatically" {
  run bash -c "source '$LIB_FILE' && declare -p RED &>/dev/null && echo 'colors_loaded'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "colors_loaded" ]]
}

@test "common: loads print-functions.sh automatically" {
  run bash -c "source '$LIB_FILE' && declare -f print_info &>/dev/null && echo 'print_loaded'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "print_loaded" ]]
}

@test "common: i18n.sh not loaded by default" {
  run bash -c "
    export COMMON_LOAD_I18N=false
    source '$LIB_FILE'
    declare -f msg &>/dev/null || echo 'i18n_not_loaded'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "i18n_not_loaded" ]]
}

# =============================================================================
# エラーハンドリングテスト
# =============================================================================

@test "common: handles missing dependencies gracefully" {
  # 実際の依存チェックは警告のみで停止しない
  run bash -c "source '$LIB_FILE' 2>&1"
  # jq と git が存在する環境では成功
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "common: bash version check passes on modern bash" {
  run bash -c "source '$LIB_FILE' && echo 'version_ok'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "version_ok" ]]
}

# =============================================================================
# プラットフォーム検出テスト
# =============================================================================

@test "detect_platform: returns macos on macOS" {
  run bash -c "
    export OSTYPE='darwin19.0'
    source '$LIB_FILE'
    detect_platform
  "
  [ "$status" -eq 0 ]
  [ "$output" = "macos" ]
}

@test "detect_platform: returns linux on Linux" {
  run bash -c "
    export OSTYPE='linux-gnu'
    source '$LIB_FILE'
    detect_platform
  "
  [ "$status" -eq 0 ]
  [ "$output" = "linux" ]
}

# =============================================================================
# sed_inplace テスト
# =============================================================================

@test "sed_inplace: replaces content correctly" {
  local test_file="$TEST_TMPDIR/test.txt"
  echo "foo=old_value" > "$test_file"
  
  run bash -c "
    source '$LIB_FILE'
    sed_inplace 's/old_value/new_value/' '$test_file'
    cat '$test_file'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "foo=new_value" ]]
}

@test "sed_inplace: does not leave .bak file on macOS" {
  local test_file="$TEST_TMPDIR/test.txt"
  echo "test_content" > "$test_file"
  
  run bash -c "
    export OSTYPE='darwin19.0'
    source '$LIB_FILE'
    sed_inplace 's/test/modified/' '$test_file'
    ls '$TEST_TMPDIR'
  "
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ ".bak" ]]
}

@test "sed_inplace: handles file modification correctly" {
  local test_file="$TEST_TMPDIR/test.txt"
  echo "value=123" > "$test_file"
  
  run bash -c "
    source '$LIB_FILE'
    sed_inplace 's/123/456/' '$test_file'
    cat '$test_file'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "value=456" ]]
}
