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
run_writing_check() {
  local file_path="${1:-}"

  if [[ -z "${file_path}" ]] || [[ ! -f "${file_path}" ]]; then
    return 0
  fi

  local pattern
  pattern=$(_writing_build_pattern)

  # grep -nE のヒット 0 件は exit 1 → || true で吸収
  # -m 20 で過多警告抑制（dogfood 後に調整）
  grep -nE -m 20 "${pattern}" "${file_path}" 2>/dev/null \
    | sed -e 's/^/L/' \
    || true
}
