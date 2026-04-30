#!/usr/bin/env bats
# =============================================================================
# BATS Tests for bats-self-check.sh (실行時検証）
# =============================================================================

setup() {
  export LIB_FILE="/Users/daichi/ghq/github.com/DaichiHoshina/ai-tools-bats-hook-v2/claude-code/lib/bats-self-check.sh"
  export TMP_FILE="$(mktemp -t bsc-XXXXXX.bats)"
}

teardown() {
  [ -n "${TMP_FILE:-}" ] && rm -f "$TMP_FILE"
}

# smoke test: 正常ケース（run + 実値 assert あり → 検出なし）
@test "bats-self-check: 正常系（run + 出力 assert） → 検出なし" {
  cat > "$TMP_FILE" <<'EOF'
@test "sample" {
  run bash -c "echo hello"
  [[ "$output" =~ "hello" ]]
}
EOF
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}

# smoke test: 異常ケース（[ -f ... ] のみ → 検出あり）
@test "bats-self-check: 異常系（[ -f ] のみ） → 検出あり" {
  cat > "$TMP_FILE" <<'EOF'
@test "sample" {
  [ -f "test_file" ]
}
EOF
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [[ "$result" =~ "L1:" ]]
}

# smoke test: 空ファイル（検出なし）
@test "bats-self-check: 空ファイル → 検出なし" {
  : > "$TMP_FILE"
  result=$(LIB_FILE="$LIB_FILE" TMP_FILE="$TMP_FILE" bash -c 'source "$LIB_FILE" && run_bats_check "$TMP_FILE"')
  [ -z "$result" ]
}
