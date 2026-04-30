#!/usr/bin/env bats
# =============================================================================
# BATS Tests for bats-self-check.sh (pass-by-coincidence 検知)
#
# NOTE: heredoc で `@test` 文字列を書くと bats parser が preprocess してしまう
# ため、printf で直接書き出す形式を使う（@test を bats 関数定義に変換させない）
# =============================================================================

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/claude-code/lib/bats-self-check.sh"
  export TMP_FILE="$(mktemp -t bsc-XXXXXX.bats)"
}

teardown() {
  [ -n "${TMP_FILE:-}" ] && rm -f "$TMP_FILE"
}

# -----------------------------------------------------------------------------
# 正常系（検出 0 件、6 ケース）
# -----------------------------------------------------------------------------

@test "bats-self-check: 正常系1: run + 出力 assert → 検出なし" {
  printf '%s\n' \
    '@test "sample" {' \
    '  run bash -c "echo hello"' \
    '  [[ "$output" =~ "hello" ]]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

@test "bats-self-check: 正常系2: run + status + 出力 assert → 検出なし" {
  printf '%s\n' \
    '@test "sample" {' \
    '  run bash -c "true"' \
    '  [ "$status" -eq 0 ]' \
    '  [[ "$output" =~ "" ]]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

@test "bats-self-check: 正常系3: result=\$(bash -c source) + 実値 assert → 検出なし" {
  printf '%s\n' \
    '@test "sample" {' \
    '  result=$(bash -c "source /tmp/lib && some_func")' \
    '  [[ "$result" =~ "expected" ]]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

@test "bats-self-check: 正常系4: run -1 (exit code 付き) → 検出なし" {
  printf '%s\n' \
    '@test "sample" {' \
    '  run -1 bash -c "false"' \
    '  [[ "$output" =~ "" ]]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

@test "bats-self-check: 正常系5: 複数 @test 全部正常 → 検出なし" {
  printf '%s\n' \
    '@test "first" {' \
    '  run bash -c "echo a"' \
    '  [[ "$output" =~ "a" ]]' \
    '}' \
    '@test "second" {' \
    '  run bash -c "echo b"' \
    '  [[ "$output" =~ "b" ]]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

@test "bats-self-check: 正常系6: bash -c source + status + output → 検出なし" {
  printf '%s\n' \
    '@test "sample" {' \
    '  run bash -c "source /tmp/lib && my_func arg"' \
    '  [ "$status" -eq 0 ]' \
    '  [[ "$output" =~ "result" ]]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

# -----------------------------------------------------------------------------
# 異常系（検出あり、5 ケース）
# -----------------------------------------------------------------------------

@test "bats-self-check: 異常系1: [ -f ] のみ → 検出あり" {
  printf '%s\n' \
    '@test "sample" {' \
    '  [ -f "test_file" ]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [[ "$result" =~ L1: ]]
}

@test "bats-self-check: 異常系2: grep -q 関数定義のみ → 検出あり" {
  printf '%s\n' \
    '@test "sample" {' \
    '  grep -q "^funcname()" /tmp/lib' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [[ "$result" =~ L1: ]]
}

@test "bats-self-check: 異常系3: 二択 assert → 検出あり" {
  printf '%s\n' \
    '@test "sample" {' \
    '  run bash -c "false"' \
    '  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [[ "$result" =~ L1: ]]
}

@test "bats-self-check: 異常系4: grep -q || true 握りつぶし → 検出あり" {
  printf '%s\n' \
    '@test "sample" {' \
    '  run bash -c "true"' \
    '  grep -q "expected" /tmp/file || true' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [[ "$result" =~ L1: ]]
}

@test "bats-self-check: 異常系5: echo 'ok' 末尾 → 検出あり" {
  printf '%s\n' \
    '@test "sample" {' \
    '  run bash -c "true"' \
    "  echo 'ok'" \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [[ "$result" =~ L1: ]]
}

# -----------------------------------------------------------------------------
# 境界（3 ケース）
# -----------------------------------------------------------------------------

@test "bats-self-check: 境界1: 空ファイル → 検出なし、exit 0" {
  : > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

@test "bats-self-check: 境界2: @test 0 個（コメントのみ） → 検出なし" {
  printf '%s\n' \
    '# This is a comment-only file' \
    '# No @test blocks here' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

@test "bats-self-check: 境界3: 不存在ファイル → exit 0、検出なし" {
  result=$(LIB_FILE="$LIB_FILE" bash -c 'source "$LIB_FILE" && run_bats_check /tmp/nonexistent_bsc_file.bats')
  [ -z "$result" ]
}

# -----------------------------------------------------------------------------
# 統合（正常+異常混在、1 ケース）
# -----------------------------------------------------------------------------

@test "bats-self-check: 統合: 正常+異常混在 → 異常のみ検出" {
  printf '%s\n' \
    '@test "good" {' \
    '  run bash -c "echo a"' \
    '  [[ "$output" =~ "a" ]]' \
    '}' \
    '@test "bad" {' \
    '  [ -f "/tmp/x" ]' \
    '}' > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [[ "$result" =~ bad ]]
  ! [[ "$result" =~ good ]]
}
