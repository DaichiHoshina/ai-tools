#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/jp-quality/structural-checks.sh 括弧詰め込み検出
# 読点 2 個以上 + 動詞なしの括弧 (名詞羅列) を warn する
# =============================================================================

setup() {
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/jp-quality-check.sh"
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"
  export HOME="$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

_run_struct() {
  local text="$1"
  run bash -c "
    export HOME='${TEST_TMPDIR}'
    # shellcheck disable=SC1090
    source '${LIB_FILE}'
    _check_sentence_structure \"\$1\"
  " _ "$text"
}

@test "名詞羅列の括弧 (読点 2 個 + 動詞なし) → 括弧詰め込み warn" {
  _run_struct "運用フラグは 1 つだけ使う (admin API、503 化用途、DD 6-2 節)。"
  [ "$status" -eq 0 ]
  [[ "$output" == *"括弧詰め込み: 1件"* ]]
}

@test "動詞を含む補足文の括弧 → 対象外" {
  _run_struct "運用フラグは 1 つだけ使う (admin API から立てると、処理を止めて、503 を返す)。"
  [ "$status" -eq 0 ]
  [[ "$output" != *"括弧詰め込み"* ]]
}

@test "読点 1 個の括弧 → 対象外" {
  _run_struct "設定を見直した (対象は 2 件、いずれも軽微)。"
  [ "$status" -eq 0 ]
  [[ "$output" != *"括弧詰め込み"* ]]
}

@test "全角括弧の名詞羅列も検出する" {
  _run_struct "前提を並べる（データ瞬時値、並走サービス不在、パターン差）。"
  [ "$status" -eq 0 ]
  [[ "$output" == *"括弧詰め込み: 1件"* ]]
}

@test "chat 経路: _chat_quality_check の warn message に載る" {
  mkdir -p "${TEST_TMPDIR}/.claude/guidelines/writing"
  printf '**AI定型語**: 効果的に\n' > "${TEST_TMPDIR}/.claude/guidelines/writing/NG-DICTIONARY.md"
  run bash -c "
    export HOME='${TEST_TMPDIR}'
    # shellcheck disable=SC1090
    source '${LIB_FILE}'
    _chat_quality_check '設定はこう置いた (admin API、503 化用途、DD 6-2 節)。'
    printf '%s' \"\${_CHAT_WARN_MSG}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"括弧詰め込み"* ]]
}
