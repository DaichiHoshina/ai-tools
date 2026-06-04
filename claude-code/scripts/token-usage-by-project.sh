#!/usr/bin/env bash
# Usage:
#   ./scripts/token-usage-by-project.sh                         # 過去 30 日、全 project、top 20
#   ./scripts/token-usage-by-project.sh --days 7 --top 5
#   ./scripts/token-usage-by-project.sh --project <name>         # 部分一致 filter
#
# Diagnostic hint: cache_read% > 90% = long-session accumulation. Fix = session split (1 task = 1 session, /clear at boundary), not config size.
set -euo pipefail

DAYS=30
TOP=20
PROJECT_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)    DAYS="$2";           shift 2 ;;
    --top)     TOP="$2";            shift 2 ;;
    --project) PROJECT_FILTER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

PROJ_ROOT="$HOME/.claude/projects"
[[ -d "$PROJ_ROOT" ]] || { echo "ERROR: $PROJ_ROOT not found" >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

for dir in "$PROJ_ROOT"/*/; do
  name=$(basename "$dir")
  # --project filter (部分一致)
  if [[ -n "$PROJECT_FILTER" && "$name" != *"$PROJECT_FILTER"* ]]; then
    continue
  fi

  # find は絶対 path で回す（cd + glob でのzsh解釈バグ回避）
  mapfile -t files < <(find "$dir" -name "*.jsonl" -mtime "-${DAYS}" 2>/dev/null)
  sessions=${#files[@]}
  [[ "$sessions" -eq 0 ]] && continue

  # token 合算: input + output + cache_read + cache_creation
  read -r total cache_r < <(
    printf '%s\n' "${files[@]}" \
      | xargs -n 50 jq -r 'select(.message.usage) | [
          ((.message.usage.input_tokens // 0)
           + (.message.usage.output_tokens // 0)
           + (.message.usage.cache_read_input_tokens // 0)
           + (.message.usage.cache_creation_input_tokens // 0)),
          (.message.usage.cache_read_input_tokens // 0)
        ] | @tsv' 2>/dev/null \
      | awk '{t+=$1; cr+=$2} END {print t+0, cr+0}'
  )

  [[ "$total" -eq 0 ]] && continue

  avg=$(( total / sessions ))
  # cache_read 比率 (整数 %, ゼロ除算ガード)
  if [[ "$total" -gt 0 ]]; then
    cache_pct=$(awk "BEGIN {printf \"%.1f\", $cache_r * 100 / $total}")
  else
    cache_pct="0.0"
  fi

  printf '%s\t%d\t%d\t%d\t%s\n' "$name" "$total" "$sessions" "$avg" "$cache_pct" >> "$tmp"
done

if [[ ! -s "$tmp" ]]; then
  echo "No data found (days=${DAYS}, project='${PROJECT_FILTER:-*}')" >&2
  exit 0
fi

# header + total desc sort + top N
printf '%-55s %14s %8s %14s %14s\n' "project" "total_tokens" "sessions" "avg/session" "cache_read%"
printf '%-55s %14s %8s %14s %14s\n' "-------" "------------" "--------" "-----------" "-----------"
sort -t$'\t' -k2 -rn "$tmp" | head -n "$TOP" | while IFS=$'\t' read -r name total sessions avg cache_pct; do
  printf '%-55s %14d %8d %14d %13s%%\n' "$name" "$total" "$sessions" "$avg" "$cache_pct"
done

echo ""
echo "# days=${DAYS}  top=${TOP}  filter='${PROJECT_FILTER:-*}'"
