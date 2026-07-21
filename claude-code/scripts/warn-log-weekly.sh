#!/usr/bin/env bash
# warn-log-weekly.sh — hook / review skill が吐く warn log を pattern 別に週次集計する。
# 詳細: ~/ai-tools/claude-code/scripts/README-warn-log-weekly.md (canonical)。

set -euo pipefail

LOG_DIR="${HOME}/.claude/logs"
OUT_DIR="${HOME}/.claude/logs"
TODAY="$(date +%Y%m%d)"
LAST_WEEK_START="$(date -v-14d +%Y-%m-%d)"
THIS_WEEK_START="$(date -v-7d +%Y-%m-%d)"
OUT_FILE="${OUT_DIR}/warn-log-weekly-${TODAY}.txt"

TARGET_LOGS=(
  "review-pattern-warn.log"
  "comment-style-warn.log"
  "comment-quantity-warn.log"
  "bundle-violation-warn.log"
)

count_by_pattern() {
  local log_path="$1" since="$2" until="$3"
  [[ -f "$log_path" ]] || { echo "  (log not found)"; return; }
  awk -F'|' -v since="$since" -v until="$until" '
    {
      ts = substr($0, 2, 10)
      if (ts >= since && ts < until) {
        gsub(/^ +| +$/, "", $2)
        pat = ($2 == "") ? "(no-pattern)" : $2
        count[pat]++
        total++
      }
    }
    END {
      if (total == 0) { print "  (no entries)"; exit }
      n = 0
      for (p in count) { arr[n++] = p }
      for (i = 0; i < n; i++) {
        for (j = i+1; j < n; j++) {
          if (count[arr[j]] > count[arr[i]]) { t = arr[i]; arr[i] = arr[j]; arr[j] = t }
        }
      }
      for (i = 0; i < n; i++) { printf "  %-30s %d\n", arr[i], count[arr[i]] }
      printf "  %-30s %d\n", "(total)", total
    }
  ' "$log_path"
}

total_delta() {
  local log_path="$1"
  [[ -f "$log_path" ]] || { echo "0 0"; return; }
  local last this
  last=$(awk -F'|' -v s="$LAST_WEEK_START" -v u="$THIS_WEEK_START" '
    { ts = substr($0, 2, 10); if (ts >= s && ts < u) c++ } END { print c+0 }
  ' "$log_path")
  this=$(awk -F'|' -v s="$THIS_WEEK_START" '
    { ts = substr($0, 2, 10); if (ts >= s) c++ } END { print c+0 }
  ' "$log_path")
  echo "$last $this"
}

{
  echo "=== warn-log weekly summary: $(date '+%Y-%m-%d %H:%M') ==="
  echo "period: this=${THIS_WEEK_START}〜today, last=${LAST_WEEK_START}〜${THIS_WEEK_START}"
  echo ""

  for log in "${TARGET_LOGS[@]}"; do
    log_path="${LOG_DIR}/${log}"
    read -r last this < <(total_delta "$log_path")
    delta=$((this - last))
    delta_sign=""
    [[ $delta -gt 0 ]] && delta_sign="+"
    echo "## ${log}  (this=${this} / last=${last} / Δ=${delta_sign}${delta})"
    echo "  [this week pattern breakdown]"
    count_by_pattern "$log_path" "$THIS_WEEK_START" "9999-99-99"
    echo ""
  done

  echo "=== Interpretation hints ==="
  echo "- Δ が急増した pattern: hook / rule が新たに hit している。誤爆か有効かを 1 件抽出して目視確認する"
  echo "- Δ が 0 のまま 4 週続いた log: 死に log の可能性がある。原因を切り分けて剪定判断する"
  echo "- 特定 pattern が total の 80% 超: 単独 rule 化 / block 昇格の候補になる"
} > "$OUT_FILE"

cat "$OUT_FILE"
