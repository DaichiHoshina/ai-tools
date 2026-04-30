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

# =============================================================================
# False positive 抑制: 表行除外
# =============================================================================

@test "writing-self-check: 表行（行頭 |）の NG 語は除外される" {
  cat > "$TMP_FILE" <<'EOF'
| 操作 | ルール |
|------|--------|
| git merge | ユーザー確認必須 |
| ブランチ削除 | ユーザー確認必須 |
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 表行除外しつつ地の文 NG は検出" {
  cat > "$TMP_FILE" <<'EOF'
これは必須の項目
| 操作 | 必須かどうか |
|------|-------------|
| backup | 推奨 |
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  # 1行目（地の文）は検出、2-4行目（表）は除外
  [[ "$output" =~ "L1" ]]
  ! [[ "$output" =~ "L2" ]]
  ! [[ "$output" =~ "L4" ]]
}

@test "writing-self-check: 見出し行（# 始まり）の NG 語は除外" {
  cat > "$TMP_FILE" <<'EOF'
## 推奨パターン
### 必須要件
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: bullet ラベル（- **xx**:）の NG 語は除外" {
  cat > "$TMP_FILE" <<'EOF'
- **推奨**: 後続の説明文がある
- **必須**: こちらも説明あり
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 通常の bullet（**でなく単純）は除外しない" {
  cat > "$TMP_FILE" <<'EOF'
- 必須項目を確認する
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "L1" ]]
}

@test "writing-self-check: 引用ブロック（>）の NG 語は除外" {
  cat > "$TMP_FILE" <<'EOF'
> 必須要件を満たすこと
> 推奨パターンに従う
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# コードフェンス除外: 新規テスト 4 件（RED フェーズ）
# =============================================================================

@test "writing-self-check: コードブロック内の NG 語は除外" {
  cat > "$TMP_FILE" <<'EOF'
以下はコード例です。
```
function setup() {
  # 必須の初期化処理
  pushd /path/to/dir
}
```
処理は完了。
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: コードブロック外の NG 語は検出" {
  cat > "$TMP_FILE" <<'EOF'
これは必須項目です。
```
echo "推奨パターン"
```
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  # 1行目（地の文）は検出、フェンス内は除外
  [[ "$output" =~ "L1" ]]
  ! [[ "$output" =~ "L4" ]]
}

@test "writing-self-check: 複数のコードブロックがある場合も全て除外" {
  cat > "$TMP_FILE" <<'EOF'
最初のコードブロック:
```
必須の初期化
```
中間の地の文：普通の記述
```
echo "推奨パターン"
```
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: mermaid 図（\`\`\`mermaid）の内部の NG 語も除外" {
  cat > "$TMP_FILE" <<'EOF'
以下は図です。
```mermaid
graph TD
    A[必須: 初期化処理]
    B[推奨: キャッシュ有効化]
    A --> B
```
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# =============================================================================
# コードフェンス境界値: unbalanced / 空フェンス
# =============================================================================

@test "writing-self-check: unbalanced フェンス（閉じない）でも安全に動作" {
  # printf で ``` を含む内容を書き込む（heredoc 内では ``` がネスト不可なため）
  printf '%s\n' \
    '通常の必須項目（地の文）' \
    '```bash' \
    'echo "推奨パターン"' \
    '# 必須の処理' > "$TMP_FILE"
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  # L1（地の文）は検出される
  [[ "$output" =~ "L1" ]]
  # フェンス開始以降（L2-L4）は除外される
  ! [[ "$output" =~ "L3" ]]
  ! [[ "$output" =~ "L4" ]]
}

@test "writing-self-check: 空コードブロック（開閉直後）でも安全に動作" {
  # 空フェンス: ``` 直後すぐ ``` — 内部は空
  printf '%s\n' \
    '```' \
    '```' \
    'これは必須項目（フェンス外の地の文）' > "$TMP_FILE"
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  # フェンス外 L3 のみ検出
  [[ "$output" =~ "L3" ]]
  ! [[ "$output" =~ "L1" ]]
  ! [[ "$output" =~ "L2" ]]
}

# =============================================================================
# Context-aware 除外: 同行括弧 / 隣接行 引用・表
# =============================================================================

@test "writing-self-check: 同行内丸括弧（重要 X（具体例: foo, bar））は除外" {
  cat > "$TMP_FILE" <<'EOF'
重要な設定ポイント（具体例: config.json, .env）について説明します。
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 同行内鉤括弧（必須 X「具体例」）は除外" {
  cat > "$TMP_FILE" <<'EOF'
必須要件「詳細は設計ドキュメント参照」を確認してください。
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 前行に引用ブロック（最優先課題は\\n> Y のため）は除外" {
  cat > "$TMP_FILE" <<'EOF'
理由としては以下の通りです:
> パフォーマンス改善は最優先課題です
最優先課題への対応が必須です。
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: 後行に表（推奨実装\\n| col1 | col2 |）は除外" {
  cat > "$TMP_FILE" <<'EOF'
推奨実装パターン:
| 方法 | 説明 |
|------|------|
| A | 最適解 |
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "writing-self-check: NG 語単独（括弧なし、隣接行なし）は検出される（negative case）" {
  cat > "$TMP_FILE" <<'EOF'
重要だ。
EOF
  run bash -c "source '$LIB_FILE' && run_writing_check '$TMP_FILE'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "L1" ]]
}
