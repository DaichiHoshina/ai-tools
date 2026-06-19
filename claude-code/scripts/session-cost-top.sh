#!/usr/bin/env bash
# session 別 cost top-N + msg 数 + agent 起動数を表示する
# ccusage session --json と ~/.claude/projects/*/<sid>.jsonl を join
#
# Usage:
#   ./scripts/session-cost-top.sh                     # 過去 7 日、top 10
#   ./scripts/session-cost-top.sh --since 2026-06-15  # 開始日
#   ./scripts/session-cost-top.sh --top 20            # top N
#   ./scripts/session-cost-top.sh --project ai-tools  # project 名 substring filter
set -euo pipefail

SINCE=""
TOP=10
PROJECT_FILTER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --top) TOP="$2"; shift 2 ;;
    --project) PROJECT_FILTER="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

command -v ccusage >/dev/null || { echo "ccusage not found in PATH" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 1; }

if [[ -z "$SINCE" ]]; then
  # default: 7 日前 (BSD date / GNU date 両対応)
  SINCE=$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)
fi

PROJECTS_ROOT="$HOME/.claude/projects"

# ccusage session JSON → session_id, cost を抽出
sessions_json=$(ccusage session --json --since "$SINCE" 2>/dev/null)

# session.period = session_id
# project / jsonl path を逆引きするため projects_root を走査
declare -A SID_PATH
while IFS= read -r jsonl; do
  bn=$(basename "$jsonl" .jsonl)
  SID_PATH[$bn]="$jsonl"
done < <(find "$PROJECTS_ROOT" -name '*.jsonl' -type f 2>/dev/null)

printf "%-10s  %-8s  %-6s  %-6s  %s\n" "COST($)" "TOKENS" "MSGS" "AGENTS" "PROJECT @ SESSION_ID"
printf "%-10s  %-8s  %-6s  %-6s  %s\n" "--------" "------" "----" "------" "--------------------"

echo "$sessions_json" | jq -r '
  .session[]
  | [(.totalCost|tostring), (.totalTokens|tostring), .period]
  | @tsv' \
  | sort -t$'\t' -k1 -rn \
  | head -n "$TOP" \
  | while IFS=$'\t' read -r cost tokens sid; do
      jsonl="${SID_PATH[$sid]:-}"
      msgs=0
      agents=0
      project="(unknown)"
      if [[ -n "$jsonl" && -f "$jsonl" ]]; then
        project=$(basename "$(dirname "$jsonl")")
        # project filter
        if [[ -n "$PROJECT_FILTER" && "$project" != *"$PROJECT_FILTER"* ]]; then
          continue
        fi
        msgs=$(jq -r 'select(.type=="user" or .type=="assistant") | .type' "$jsonl" 2>/dev/null | wc -l | tr -d ' ')
        agents=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Agent") | .name' "$jsonl" 2>/dev/null | wc -l | tr -d ' ')
      else
        if [[ -n "$PROJECT_FILTER" ]]; then continue; fi
      fi
      # cost を小数 2 桁に整形
      cost_fmt=$(printf '%.2f' "$cost")
      # tokens を K/M 表記に
      tokens_fmt=$(awk -v t="$tokens" 'BEGIN{ if (t>=1e6) printf "%.1fM", t/1e6; else if (t>=1e3) printf "%.0fK", t/1e3; else printf "%d", t }')
      printf "%-10s  %-8s  %-6s  %-6s  %s @ %s\n" "$cost_fmt" "$tokens_fmt" "$msgs" "$agents" "$project" "${sid:0:8}"
    done
