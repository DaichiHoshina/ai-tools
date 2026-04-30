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

  # awk で 1 パス：
  # 1) 全行を配列に読み込み、コードフェンス内行に is_code フラグをセット
  # 2) END ブロックで context-aware 判定を実施（コード内行は除外）
  # grep -nE のヒット 0 件は exit 1 → || true で吸収
  # 行頭 `|` 表 / `#` 見出し / `>` 引用 / `- **xx**:` ラベルを除外
  awk -v pattern="${pattern}" '
    {
      lines[NR] = $0
      is_code[NR] = in_code
      line_count = NR

      if (/^[[:space:]]*```/) {
        in_code = !in_code
      }
    }

    END {
      for (i = 1; i <= line_count; i++) {
        curr = lines[i]

        # コードフェンス内の行は除外
        if (is_code[i]) {
          continue
        }

        # curr 行がパターンに完全マッチするかチェック
        if (match(curr, pattern)) {
          should_output = 1

          # a) curr 行内に 丸括弧で根拠を示す （具体例:|例:|詳細: ... または複数 , を含む）
          #    または 鉤括弧 「[^」]+」 を含む（文脈が明示的）
          if (match(curr, /（（具体例:|例:|詳細:|参考:)[^）]*(, |，)|「[^」]+」/)) {
            should_output = 0
          }

          if (should_output) {
            prev1 = (i > 1 && !is_code[i - 1]) ? lines[i - 1] : ""
            next1 = (i < line_count && !is_code[i + 1]) ? lines[i + 1] : ""

            # b) prev1 が引用ブロック
            if (match(prev1, /^[[:space:]]*>/)) {
              should_output = 0
            }

            # d) prev1 が表行
            if (should_output && match(prev1, /^[[:space:]]*\|/)) {
              should_output = 0
            }

            # c) next1 が表/引用、かつ curr が「ラベル行」（末尾が : または） で示す区切り）
            #    つまり curr が説明行のような役割 → 除外
            if (should_output && (match(next1, /^[[:space:]]*>/) || match(next1, /^[[:space:]]*\|/))) {
              # curr が行末 : や・・・）などで終わる → ラベル行の可能性あり
              if (match(curr, /:$/) || match(curr, /）$|）[[:space:]]*$/)) {
                should_output = 0
              }
            }
          }

          if (should_output) {
            print i ":" curr
          }
        }
      }
    }
  ' "${file_path}" | \
    grep -vE "^[0-9]+:[[:space:]]*\|" \
    | grep -vE "^[0-9]+:[[:space:]]*#" \
    | grep -vE "^[0-9]+:[[:space:]]*>" \
    | grep -vE "^[0-9]+:[[:space:]]*-?[[:space:]]*\*\*[^*]+\*\*:" \
    | head -n 20 \
    | sed -e 's/^/L/' \
    || true
}
