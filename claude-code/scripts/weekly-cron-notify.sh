#!/usr/bin/env bash
# 月曜朝の週次 cron 4 本 (07:00-07:45) の結果を 08:50 に集約通知する。
# 各 log の最終 mtime と最終行を拾って macOS notification + 集約 log を吐く。
set -euo pipefail

LOG_DIR="${HOME}/.claude/logs"
OUT="${LOG_DIR}/weekly-cron-notify-$(date +%Y%m%d).log"

declare -a JOBS=(
  "hook-bench|${LOG_DIR}/hook-bench-cron.stdout.log|${LOG_DIR}/hook-bench-*.log"
  "maintenance|${LOG_DIR}/maintenance-cron.stdout.log|${LOG_DIR}/maintenance-cron-*.log"
  "baseline-summary|${LOG_DIR}/flow-baseline-summary-cron.stdout.log|${LOG_DIR}/flow-baseline-*.tsv"
  "warn-log|${LOG_DIR}/warn-log-weekly-cron.stdout.log|${LOG_DIR}/warn-log-weekly-*.txt"
)

today_epoch=$(date -v0H -v0M -v0S +%s)
summary_lines=()
notify_lines=()

for spec in "${JOBS[@]}"; do
  name="${spec%%|*}"
  rest="${spec#*|}"
  fallback_log="${rest%%|*}"
  daily_glob="${rest#*|}"

  # 日次 log があれば優先する
  latest_log=$(ls -t $daily_glob 2>/dev/null | head -1 || true)
  target="${latest_log:-$fallback_log}"

  if [[ ! -f "$target" ]]; then
    summary_lines+=("[$name] MISSING (log not found)")
    notify_lines+=("$name: MISSING")
    continue
  fi

  mtime=$(stat -f '%m' "$target")
  mtime_h=$(date -r "$mtime" '+%H:%M')
  if (( mtime < today_epoch )); then
    status="STALE"
  else
    status="OK"
  fi

  last_line=$(tail -1 "$target" 2>/dev/null | cut -c1-120)
  summary_lines+=("[$name] $status ($mtime_h) $(basename "$target"): ${last_line}")
  notify_lines+=("$name: $status $mtime_h")
done

{
  echo "=== weekly cron notify ($(date '+%F %T')) ==="
  printf '%s\n' "${summary_lines[@]}"
} > "$OUT"

body=$(printf '%s\\n' "${notify_lines[@]}")
title="Weekly cron $(date '+%m/%d')"
/usr/bin/osascript -e "display notification \"${body}\" with title \"${title}\"" 2>>"$OUT" || true

echo "done: $OUT"
