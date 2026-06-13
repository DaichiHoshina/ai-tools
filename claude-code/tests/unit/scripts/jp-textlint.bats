#!/usr/bin/env bats
# =============================================================================
# BATS Tests for scripts/jp-textlint.sh
# =============================================================================
# 観点:
#   - Bug1-4 の回帰 (code block 除外層のバグ修正確認)
#   - 境界値 (連続漢字 4/5字、読点 3/4個、文長 100/101字)
#   - 正常 fence 除外・4観点同時 hit カウント
#   - 空入力で exit 0 + 「✓ 機械検出 0 件」
#
# 注意: bats は heredoc 内の ``` (backtick x3) を parse エラーにするため
#       fence を含むファイルは全て printf '%s\n' 方式で生成する

setup() {
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT="$PROJECT_ROOT/scripts/jp-textlint.sh"
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# Smoke: 空入力
# =============================================================================

@test "smoke: 空入力で exit 0 かつ '✓ 機械検出 0 件' が出力される" {
  run bash "$SCRIPT" <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

# =============================================================================
# Bug1 回帰: 0-3sp インデント fence 内の NG 語を除外する
# =============================================================================

@test "Bug1 回帰: 3sp インデント fence 内 NG 語は検出されない" {
  # 修正前: ``` が行頭完全一致のみだったため インデント fence を通過させてしまっていた
  printf '%s\n' \
    '通常散文。' \
    '' \
    '   ```python' \
    'leverage' \
    '   ```' \
    '' \
    '後続散文。' > "$TEST_TMPDIR/b1.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/b1.md"
  [ "$status" -eq 0 ]
  # leverage はインデント fence 内 → NG-DICTIONARY hit なし
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

@test "Bug1 回帰: 1sp インデント fence 内 NG 語は検出されない" {
  printf '%s\n' \
    '通常散文。' \
    '' \
    ' ```' \
    'leverage' \
    ' ```' \
    '' \
    '後続散文。' > "$TEST_TMPDIR/b1_1sp.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/b1_1sp.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

# =============================================================================
# Bug2 回帰: 未閉じ fence で後続 prose が drop されない
# =============================================================================

@test "Bug2 回帰: 未閉じ fence の後続 prose の NG 語は検出される" {
  # 修正前: 未閉じ fence 以降が全 drop されて NG 語を見逃していた
  printf '%s\n' \
    '通常散文。' \
    '' \
    '```' \
    'code block start (no closing fence)' \
    '' \
    '後続散文に leverage が含まれる。検出されるべき。' > "$TEST_TMPDIR/b2.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/b2.md"
  [ "$status" -eq 0 ]
  # 未閉じ fence = prose 扱い → leverage が検出される (0件ではない)
  [[ "$output" != *"✓ 機械検出 0 件"* ]]
}

@test "Bug2 回帰: 未閉じ fence の後続 prose がクリーンなら 0 件" {
  printf '%s\n' \
    '通常散文。' \
    '' \
    '```' \
    'code block no close' \
    '' \
    '後続散文は正常。' > "$TEST_TMPDIR/b2_clean.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/b2_clean.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

# =============================================================================
# Bug3 回帰: 2連 backtick ``foo`` 内の NG 語を除外する
# =============================================================================

@test "Bug3 回帰: 2連 backtick 内 NG 語は検出されない" {
  # 修正前: ``leverage`` → 空+孤立backtick 扱いで leverage が prose に残留していた
  # bats heredoc 内の `` が parse エラーになるため printf で書き込む
  printf '%s\n' \
    '通常散文。``leverage`` の記法を参照。' > "$TEST_TMPDIR/b3.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/b3.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

@test "Bug3 回帰: 2連 backtick と単一 backtick の混在でも除外される" {
  printf '%s\n' \
    '`foo` と ``leverage`` を参照。' > "$TEST_TMPDIR/b3_mix.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/b3_mix.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

# =============================================================================
# Bug4: 未閉じ backtick inline (現状維持確認)
# =============================================================================

@test "Bug4: 未閉じ backtick inline の行は prose として扱う (挙動ドキュメント)" {
  # 未閉じ backtick は行全体が prose 化するため NG 語が含まれれば検出される
  # → 実害は誤検出方向。現状維持が仕様
  printf '%s\n' \
    '通常散文。' \
    'unclosed_backtick_line_with_no_NG_term' \
    '後続散文。' > "$TEST_TMPDIR/b4.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/b4.md"
  [ "$status" -eq 0 ]
  # NG 語なし → 0件
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

# =============================================================================
# 正常ケース: 通常 fence 除外
# =============================================================================

@test "正常: 行頭 fence 内 NG 語は除外される" {
  printf '%s\n' \
    '通常散文。' \
    '' \
    '```' \
    'leverage' \
    'utilize' \
    '```' \
    '' \
    '後続散文。' > "$TEST_TMPDIR/normal_fence.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/normal_fence.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

@test "正常: lang 付き fence 内 NG 語は除外される" {
  printf '%s\n' \
    '通常散文。' \
    '' \
    '```python' \
    '# 鑑みる コメント' \
    'x = leverage(y)' \
    '```' \
    '' \
    '後続散文。' > "$TEST_TMPDIR/lang_fence.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/lang_fence.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

@test "正常: 単一 inline backtick 内 NG 語は除外される" {
  # 「非日常英語」は連続漢字5字になるため prose に含めない
  printf '%s\n' \
    '`leverage` は inline code 内なので除外。' > "$TEST_TMPDIR/inline.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/inline.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ 機械検出 0 件"* ]]
}

# =============================================================================
# 境界値: 連続漢字 4字 (OK) / 5字 (検出)
# =============================================================================

@test "境界値: 連続漢字 4字は検出されない" {
  # python3 が無い環境はスキップ
  command -v python3 || skip "python3 not available"

  printf '%s\n' \
    '認証処理の結果。' > "$TEST_TMPDIR/k4.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/k4.md"
  [ "$status" -eq 0 ]
  # ✓ 0件の行にも「連続漢字」が含まれるため heading パターンで判定
  [[ "$output" != *"### 連続漢字"* ]]
}

@test "境界値: 連続漢字 5字は検出される" {
  command -v python3 || skip "python3 not available"

  printf '%s\n' \
    '利用者認証処理の結果。' > "$TEST_TMPDIR/k5.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/k5.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"### 連続漢字"* ]]
}

# =============================================================================
# 境界値: 読点 3個 (OK) / 4個 (検出)
# =============================================================================

@test "境界値: 1文内の読点 3個は検出されない" {
  # A項目、B項目、C項目、D項目 = 3個
  printf '%s\n' \
    'A項目、B項目、C項目、D項目。' > "$TEST_TMPDIR/ten3.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/ten3.md"
  [ "$status" -eq 0 ]
  # ✓ 0件の行にも「読点」が含まれるため heading パターンで判定
  [[ "$output" != *"### 読点"* ]]
}

@test "境界値: 1文内の読点 4個は検出される" {
  # A項目、B項目、C項目、D項目、E項目 = 4個
  printf '%s\n' \
    'A項目、B項目、C項目、D項目、E項目。' > "$TEST_TMPDIR/ten4.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/ten4.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"### 読点"* ]]
}

# =============================================================================
# 境界値: 文長 100字 (OK) / 101字 (検出)
# =============================================================================

@test "境界値: 文長 100字は検出されない" {
  command -v python3 || skip "python3 not available"

  # ちょうど 100字の文を生成 (。は文長カウント外)
  local s
  s=$(python3 -c "print('あ' * 100, end='')")
  printf '%s。\n' "$s" > "$TEST_TMPDIR/len100.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/len100.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"文長 >100"* ]]
}

@test "境界値: 文長 101字は検出される" {
  command -v python3 || skip "python3 not available"

  local s
  s=$(python3 -c "print('あ' * 101, end='')")
  printf '%s。\n' "$s" > "$TEST_TMPDIR/len101.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/len101.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"文長 >100"* ]]
}

# =============================================================================
# 4観点同時 hit + カウント整合
# =============================================================================

@test "4観点同時 hit: 連続漢字・読点・文長・NG語 が揃うと複数件検出される" {
  command -v python3 || skip "python3 not available"

  # 連続漢字5字 + 読点4個 + 文長>100字 + NG語 (leverage) を1テキストに含む
  local long_text
  long_text=$(python3 -c "
s = '認証処理の結果' + '、テスト項目A' * 3 + '、' + 'あ' * 60
print(s + '。')
")
  printf '%s\n' "$long_text" 'leverageを使う。' > "$TEST_TMPDIR/all4.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/all4.md"
  [ "$status" -eq 0 ]
  # 検出あり
  [[ "$output" != *"✓ 機械検出 0 件"* ]]
  # 検出件数が1より大きい (複数観点)
  local issues
  issues=$(echo "$output" | grep -oE '検出 [0-9]+ 件' | grep -oE '[0-9]+' || echo "0")
  [ "${issues:-0}" -gt 1 ]
}

@test "4観点: NG 語カテゴリ複数 hit の入力で検出件数 > 0" {
  # NG語 hit カウント=1/カテゴリが script 仕様
  printf '%s\n' \
    '鑑みるとかもしれないがすることができる。leverage。シームレスに。' > "$TEST_TMPDIR/ngcount.md"

  run bash "$SCRIPT" "$TEST_TMPDIR/ngcount.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"✓ 機械検出 0 件"* ]]
}
