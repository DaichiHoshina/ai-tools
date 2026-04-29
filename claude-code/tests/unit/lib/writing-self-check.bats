#!/usr/bin/env bats
# =============================================================================
# BATS Tests for writing-self-check.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/writing-self-check.sh"
  export TMP_FILE="$(mktemp -t wsc-XXXXXX.md)"
}

teardown() {
  [ -n "${TMP_FILE:-}" ] && rm -f "$TMP_FILE"
}

# =============================================================================
# 正常系: ヒットあり
# =============================================================================

@test "writing-self-check: 評価語ヒット時に行番号付き出力" {
  cat > "$TMP_FILE" <<'EOF'
適切な実装が必須です
通常の文章
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "L1" ]]
  [[ "$output" =~ "適切な" ]] || [[ "$output" =~ "必須" ]]
}

@test "writing-self-check: 定型語ヒット" {
  cat > "$TMP_FILE" <<'EOF'
効果的に処理を実現します
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "L1" ]]
}

@test "writing-self-check: 複数行で複数ヒット" {
  cat > "$TMP_FILE" <<'EOF'
適切な設計
通常の文
最優先の課題
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "L1" ]]
  [[ "$output" =~ "L3" ]]
}

# =============================================================================
# 正常系: ヒットなし
# =============================================================================

@test "writing-self-check: NG 語なし → 空出力 + exit 0" {
  cat > "$TMP_FILE" <<'EOF'
これは普通の文章です。
特に問題のない記述。
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 空ファイル → 空出力 + exit 0" {
  : > "$TMP_FILE"
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# 異常系: 入力エラー
# =============================================================================

@test "writing-self-check: 不存在ファイル → 空出力 + exit 0（block しない）" {
  run bash -c "source '$LIB_FILE' && run_writing_check '/tmp/__no_such_file_$$.md'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 引数なし → 空出力 + exit 0" {
  run bash -c "source '$LIB_FILE' && run_writing_check"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 空文字引数 → 空出力 + exit 0" {
  run bash -c "source '$LIB_FILE' && run_writing_check ''"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# 境界: 大量ヒット時の上限
# =============================================================================

@test "writing-self-check: ヒット 25 件 → -m 20 で打ち切り" {
  for _ in $(seq 1 25); do echo "必須の項目" >> "$TMP_FILE"; done
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  local line_count
  line_count=$(echo "$output" | wc -l | tr -d ' ')
  [ "$line_count" -le 20 ]
}
