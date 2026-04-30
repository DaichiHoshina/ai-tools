#!/usr/bin/env bash
# =============================================================================
# Audit Skills Writing Self-Check Dogfood
#
# skills/*/skill.md 群に対して writing-self-check NG 辞書を一括適用する
# スクリプト。frontmatter は除外し、本文のみをチェック。
#
# Usage:
#   bash audit-skills-writing.sh [--dir <path>]
#
# Output:
#   <skill_path>:L<num>: <line> （ヒット行）
#   Total: <hits> hits across <skills_with_hits> skills
#
# 終了コード: 常に 0（block しない、警告のみ）
# =============================================================================
set -euo pipefail

# スクリプト自身の位置を起点に lib/ パスを解決
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# writing-self-check.sh をソース（read-only として利用）
if [[ ! -f "${LIB_DIR}/writing-self-check.sh" ]]; then
  echo "Error: ${LIB_DIR}/writing-self-check.sh not found" >&2
  exit 1
fi
source "${LIB_DIR}/writing-self-check.sh"

# デフォルト走査ディレクトリ
SKILLS_DIR="${SCRIPT_DIR}/skills"

# 引数解析（--dir オプション）
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      if [[ $# -lt 2 ]] || [[ "${2:-}" == --* ]]; then
        echo "Error: --dir requires a path argument" >&2
        exit 1
      fi
      SKILLS_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# skill.md 走査ループ
total_hits=0
skills_with_hits=0
tmp_files=()

# cleanup trap（ループ外で定義）
trap 'rm -f "${tmp_files[@]}"' EXIT

# find で skill.md を列挙（ソート済み）
while IFS= read -r skill_file; do
  if [[ ! -f "$skill_file" ]]; then
    continue
  fi

  # tmpfile 作成（frontmatter 除外の前処理用）
  tmp_file=$(mktemp)
  tmp_files+=("$tmp_file")

  # frontmatter を空行に置換（行番号維持）
  awk '
    /^---$/ { fm = !fm; print ""; next }
    fm { print ""; next }
    { print }
    END {
      if (fm == 1) {
        print "Warning: unclosed frontmatter in " FILENAME > "/dev/stderr"
      }
    }
  ' "$skill_file" > "$tmp_file"

  # run_writing_check 実行（NG 辞書チェック）
  check_output=$(run_writing_check "$tmp_file" || true)

  # ヒット行がある場合、<skill_path>: プレフィックス付与
  if [[ -n "$check_output" ]]; then
    while IFS= read -r line; do
      # skill ディレクトリ名 + /skill.md で出力
      skill_dir=$(basename "$(dirname "$skill_file")")
      echo "${skill_dir}/skill.md:${line}"
    done <<< "$check_output"

    # ヒット件数をカウント
    hit_count=$(echo "$check_output" | wc -l)
    ((total_hits += hit_count))
    ((skills_with_hits += 1))
  fi
done < <(find "$SKILLS_DIR" -name "skill.md" -type f | sort)

# サマリ出力
echo ""
echo "Total: $total_hits hits across $skills_with_hits skills"

exit 0
