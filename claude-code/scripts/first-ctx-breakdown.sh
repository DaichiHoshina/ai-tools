#!/usr/bin/env bash
# first-ctx-breakdown: session 初回 assistant turn までの attachment を type 別に分解する
#
# first-ctx-check.sh が閾値超えを検出した session を渡すと、
# attachment type ごとの bytes 占有量と、
# 同 type が session-start で reissue されている重複回数を出力する。
#
# usage: first-ctx-breakdown.sh <session-jsonl-path>
#        first-ctx-breakdown.sh --top N       # first-ctx-check log の top N session から自動選択する
#
# 出力の各行が attachment type 別に count と total bytes を示し、重複時は note を付ける。
set -euo pipefail

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-${HOME}/.claude/projects}"
LOG_DIR="${HOME}/.claude/logs"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq が見つかりません" >&2
  exit 2
fi

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <session-jsonl-path>" >&2
  echo "       $0 --top N" >&2
  exit 2
fi

TARGET=""
if [[ "$1" == "--top" ]]; then
  N="${2:?--top requires N}"
  latest_log=$(ls -t "${LOG_DIR}"/first-ctx-*.log 2>/dev/null | head -1)
  if [[ -z "$latest_log" ]]; then
    echo "ERROR: first-ctx log がない。先に first-ctx-check.sh --log を実行してください" >&2
    exit 2
  fi
  slug_sid=$(awk '/^--- top/ {flag=1; next} flag && /^[0-9]/ {print $2}' "$latest_log" | awk -v n="$N" 'NR==n')
  if [[ -z "$slug_sid" ]]; then
    echo "ERROR: top ${N} が log にない" >&2
    exit 2
  fi
  slug="${slug_sid%/*}"
  sid_prefix="${slug_sid##*/}"
  TARGET=$(ls "${PROJECTS_DIR}/${slug}/${sid_prefix}"*.jsonl 2>/dev/null | head -1)
  if [[ -z "$TARGET" ]]; then
    echo "ERROR: jsonl 見つからず: ${slug}/${sid_prefix}*" >&2
    exit 2
  fi
else
  TARGET="$1"
fi

if [[ ! -f "$TARGET" ]]; then
  echo "ERROR: file なし: $TARGET" >&2
  exit 2
fi

# 最初の assistant turn の 1 行前までを分解対象にする
end_line=$(awk '/"role":"assistant"/ {print NR; exit}' "$TARGET")
if [[ -z "$end_line" ]]; then
  end_line=$(wc -l < "$TARGET")
fi
end_line=$((end_line - 1))

echo "target: $TARGET"
echo "range:  line 1..${end_line} (最初の assistant turn 直前まで解析する)"
echo

# 各行を type 別に集計し、count が 2 以上なら重複として note する
awk "NR<=${end_line}" "$TARGET" | jq -r '
  select(.type=="attachment") |
  [.attachment.type, (.attachment | tostring | length)] | @tsv
' 2>/dev/null | awk '
  { c[$1]++; s[$1]+=$2 }
  END {
    for (k in c) {
      note = (c[k] >= 2) ? "DUPLICATE (session-start reissue)" : ""
      printf "%-30s %5d %10d  %s\n", k, c[k], s[k], note
    }
  }
' | sort -k3 -rn | awk 'BEGIN{printf "%-30s %5s %10s  %s\n%-30s %5s %10s  %s\n", "type","count","total(B)","note","----","-----","--------","----"} {print}'

echo
echo "=== initial cache usage ==="
head -c 2097152 "$TARGET" | jq -c '
  select(.message.usage) | .message.usage |
  {input: .input_tokens, cache_creation: .cache_creation_input_tokens, cache_read: .cache_read_input_tokens}
' 2>/dev/null | head -1
