#!/bin/bash
# =============================================================================
# Writing Self-Check (Boris流 Compounding Engineering)
#
# md ファイル編集後に user-voice.md NG 辞書 grep を実行し、根拠なき評価語・
# 定型語のヒット行を行番号付きで出力する。
#
# Usage:
#   source writing-self-check.sh
#   run_writing_check "/path/to/file.md"
#
# Output:
#   ヒットあり: "L<行番号>: <マッチした行抜粋>" を1行ずつ stdout
#   ヒットなし: 空出力（exit 0）
#
# 設計方針:
# - block しない（exit 0 維持、警告のみ）
# - false positive 許容（文脈無視 grep のため、根拠併記済の正当な使用も hit する）
# - NG 辞書は配列で保持、変更容易
# - 本配列（_WRITING_NG_EVAL / _WRITING_NG_STOCK）は
#   skills/comprehensive-review/skill.md writing 観点表の SoT。
#   配列の追加削除時は skill.md の例示も同期更新する。
# =============================================================================
set -euo pipefail

# NG 辞書: 評価語（根拠併記必須）
_WRITING_NG_EVAL=(
  "必須"
  "推奨"
  "重要"
  "適切な"
  "最適な"
  "最優先"
  "強化する"
  "向上させる"
)

# NG 辞書: 定型語（削除推奨）
_WRITING_NG_STOCK=(
  "効果的に"
  "効率的に"
  "シームレスに"
  "革新的な"
  "を実現します"
  "を可能にします"
)

# NG 辞書を | 連結した正規表現に変換
_writing_build_pattern() {
  local pattern=""
  local sep=""
  local term
  for term in "${_WRITING_NG_EVAL[@]}" "${_WRITING_NG_STOCK[@]}"; do
    pattern+="${sep}${term}"
    sep="|"
  done
  printf '%s' "${pattern}"
}

# md ファイル 1つに対して NG 辞書 grep を実行
# Usage: run_writing_check <file_path>
# Output: stdout に "L<num>: <line>" 形式（ヒット時のみ）
#
# False positive 抑制:
# - コードフェンス（``` で囲まれた範囲）内も除外
# - 表行（行頭が `|`）は構造化データとして除外（地の文ではないため）
# - 見出し行（行頭が `#`）はラベル用途として除外
# - 引用ブロック（行頭が `>`）は引用なので除外
# - 「**ラベル**:」形式の bullet 先頭ラベルも除外（後続説明で根拠隣接が一般的）
# - -m 20 で警告過多を抑制
run_writing_check() {
  local file_path="${1:-}"

  if [[ -z "${file_path}" ]] || [[ ! -f "${file_path}" ]]; then
    return 0
  fi

  local pattern
  pattern=$(_writing_build_pattern)

  # awk でコードフェンス内行を空行に置換（行番号は元ファイルと一致）
  # grep -nE のヒット 0 件は exit 1 → || true で吸収
  # 行頭 `|` 表 / `#` 見出し / `>` 引用 / `- **xx**:` ラベルを除外
  awk '
    /^[[:space:]]*```/ { in_code = !in_code; print ""; next }
    in_code { print ""; next }
    { print }
  ' "${file_path}" \
    | grep -nE "${pattern}" 2>/dev/null \
    | grep -vE "^[0-9]+:[[:space:]]*\|" \
    | grep -vE "^[0-9]+:[[:space:]]*#" \
    | grep -vE "^[0-9]+:[[:space:]]*>" \
    | grep -vE "^[0-9]+:[[:space:]]*-?[[:space:]]*\*\*[^*]+\*\*:" \
    | head -n 20 \
    | sed -e 's/^/L/' \
    || true
}
