#!/usr/bin/env bash
# Analyze subagent-events.log to report peak_concurrency distribution and efficiency metrics.
set -euo pipefail

EVENTS_LOG="${HOME}/.claude/logs/subagent-events.log"
TSV_GLOB="${HOME}/.claude/logs/flow-baseline-*.tsv"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --summary      Show peak_concurrency distribution across all sessions
  --log          Analyze subagent-events.log for concurrent firing patterns
  --tsv          Summarize historical flow-baseline TSV data
  --since DATE   Filter to events on or after DATE (YYYY-MM-DD, log/TSV only)
  --help         Show this help
EOF
  exit 0
}

# ---- helpers ----------------------------------------------------------------

epoch() {
  # macOS-compatible ISO8601 → epoch
  local ts="${1%Z}"
  ts="${ts/T/ }"
  date -j -f "%Y-%m-%d %H:%M:%S" "$ts" "+%s" 2>/dev/null || echo 0
}

# ---- subagent-events.log analysis ------------------------------------------

analyze_log() {
  local since="${1:-}"
  if [[ ! -f "$EVENTS_LOG" ]]; then
    echo "ERROR: $EVENTS_LOG not found" >&2
    return 1
  fi

  echo "=== subagent-events.log: concurrent firing analysis ==="
  echo ""

  # Extract START events, build timeline of (timestamp, agent_id, type)
  # Then compute max simultaneous running agents per "burst" (agents started within 2s window)
  local tmpfile
  tmpfile=$(mktemp)

  grep "START" "$EVENTS_LOG" | while IFS= read -r line; do
    ts=$(echo "$line" | sed 's/^\[\(.*\)\] START.*/\1/')
    agent=$(echo "$line" | grep -o 'agent_id=[^ |]*' | cut -d= -f2)
    type=$(echo "$line" | grep -o 'type=[^ |]*' | cut -d= -f2)
    ep=$(epoch "$ts")
    [[ -n "$since" ]] && {
      since_ep=$(epoch "${since}T00:00:00Z")
      [[ $ep -lt $since_ep ]] && continue
    }
    echo "$ep $ts $agent $type"
  done > "$tmpfile"

  local total_starts
  total_starts=$(wc -l < "$tmpfile" | tr -d ' ')
  echo "Total agent START events: $total_starts"
  echo ""

  # Group starts within 2-second windows → count burst sizes
  echo "=== Burst size distribution (agents fired within 2s of each other) ==="
  echo "(burst_size : count : pct)"
  echo ""

  local prev_ep=0
  local burst=1
  declare -A dist=()

  while IFS=" " read -r ep rest; do
    diff=$(( ep - prev_ep ))
    if [[ $prev_ep -eq 0 ]]; then
      burst=1
    elif [[ $diff -le 2 ]]; then
      burst=$(( burst + 1 ))
    else
      dist[$burst]=$(( ${dist[$burst]:-0} + 1 ))
      burst=1
    fi
    prev_ep=$ep
  done < "$tmpfile"
  # flush last burst
  [[ $burst -gt 0 ]] && dist[$burst]=$(( ${dist[$burst]:-0} + 1 ))

  local total_bursts=0
  for k in "${!dist[@]}"; do
    total_bursts=$(( total_bursts + dist[$k] ))
  done

  local solo_count="${dist[1]:-0}"
  local parallel_count=$(( total_bursts - solo_count ))

  # Print sorted by burst size
  for k in $(echo "${!dist[@]}" | tr ' ' '\n' | sort -n); do
    local cnt="${dist[$k]}"
    local pct=$(( cnt * 100 / total_bursts ))
    printf "  burst=%-3s : %3d bursts  (%3d%%)\n" "$k" "$cnt" "$pct"
  done

  # burst_max: 観測最大 burst (実 fan-out 上限の指標)
  local burst_max=0
  for k in "${!dist[@]}"; do
    [[ "$k" -gt "$burst_max" ]] && burst_max="$k"
  done

  echo ""
  echo "--- Summary ---"
  printf "Total bursts : %d\n" "$total_bursts"
  printf "Solo (burst=1, sequential): %d (%d%%)\n" "$solo_count" "$(( solo_count * 100 / total_bursts ))"
  printf "Parallel (burst≥2)        : %d (%d%%)\n" "$parallel_count" "$(( parallel_count * 100 / total_bursts ))"
  printf "burst_max observed        : %d (実 fan-out 上限、TSV peak_concurrency=session snapshot と別 metric)\n" "$burst_max"
  echo ""

  # Type breakdown
  echo "=== Agent type breakdown ==="
  awk '{print $4}' "$tmpfile" | sort | uniq -c | sort -rn | while read -r cnt type; do
    local warn=""
    [[ "$type" == "general-purpose" ]] && warn="  *** BANNED: replace with explore-agent/claude-code-guide/developer-agent ***"
    printf "  %-40s %4d%s\n" "$type" "$cnt" "$warn"
  done

  # general-purpose usage alert
  local gp_count
  gp_count=$(awk '$4 == "general-purpose"' "$tmpfile" | wc -l | tr -d ' ')
  if [[ $gp_count -gt 0 ]]; then
    echo ""
    echo "⚠  WARNING: general-purpose agent fired ${gp_count} times (banned, max cost source)"
    echo "   → Replace with: explore-agent (search) / claude-code-guide (API spec) / developer-agent (impl)"
  fi

  rm -f "$tmpfile"
}

# ---- TSV summary ------------------------------------------------------------

analyze_tsv() {
  local since="${1:-}"
  local files=()
  for f in $TSV_GLOB; do
    [[ -f "$f" ]] && files+=("$f")
  done

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No flow-baseline TSV files found in ~/.claude/logs/"
    return
  fi

  echo "=== Historical flow-baseline TSV summary ==="
  echo ""

  # Combine all TSV rows (skip headers), filter by since
  local tmpfile
  tmpfile=$(mktemp)
  for f in "${files[@]}"; do
    tail -n +2 "$f"
  done | grep -v "^date" >> "$tmpfile" || true

  local total
  total=$(wc -l < "$tmpfile" | tr -d ' ')

  if [[ -n "$since" ]]; then
    local filtered
    filtered=$(awk -v s="$since" '$1 >= s' "$tmpfile")
    echo "$filtered" > "$tmpfile"
    total=$(wc -l < "$tmpfile" | tr -d ' ')
    echo "Filtered to since $since : $total sessions"
  else
    echo "Total sessions: $total"
  fi
  echo ""

  # peak_concurrency distribution (col 5: peak_concurrency in TSV)
  # Note: TSV peak_concurrency は subagent-stop hook 時点の session 内最大同時実行数 (snapshot)。
  # 実 fan-out 上限は --log の burst_max を参照 (1 message 内 N tool_use 並列発火 = N burst)。
  echo "=== peak_concurrency distribution (session snapshot, NOT burst max) ==="
  awk -F'\t' '{print $5}' "$tmpfile" | grep -E '^[0-9]+$' | sort -n | uniq -c | while read cnt peak; do
    local pct=$(( cnt * 100 / total ))
    printf "  peak=%-3s : %3d sessions (%3d%%)\n" "$peak" "$cnt" "$pct"
  done

  echo ""

  # Sequential (peak=1) ratio
  local seq_count
  seq_count=$(awk -F'\t' '$5 == 1' "$tmpfile" | wc -l | tr -d ' ')
  echo "Sequential (peak=1) : $seq_count / $total ($(( seq_count * 100 / total ))%)"
  echo "Parallel   (peak≥2) : $(( total - seq_count )) / $total ($(( (total - seq_count) * 100 / total ))%)"
  echo ""

  # wall_sec stats (exclude -1 entries, col 6: total_wall_sec)
  echo "=== wall_sec stats (excluding failed sessions) ==="
  awk -F'\t' '$6 > 0' "$tmpfile" | awk -F'\t' '
    BEGIN { min=999999; max=0; sum=0; n=0 }
    { v=$6; if(v<min) min=v; if(v>max) max=v; sum+=v; n++ }
    END {
      if (n > 0) {
        printf "  sessions: %d\n", n
        printf "  min wall_sec : %ds (%.1fmin)\n", min, min/60
        printf "  max wall_sec : %ds (%.1fmin)\n", max, max/60
        printf "  avg wall_sec : %.0fs (%.1fmin)\n", sum/n, sum/n/60
      }
    }
  '

  echo ""

  # Top slowest sessions
  echo "=== Top 5 slowest sessions ==="
  printf "  %-12s %-8s %-4s  %s\n" "wall_sec" "peak" "devs" "topic"
  awk -F'\t' '$6 > 0' "$tmpfile" | sort -t$'\t' -k6 -rn | head -5 | while IFS=$'\t' read date sid topic devs peak wall avg note; do
    topic_short="${topic:0:50}"
    printf "  %-12s %-8s %-4s  %s\n" "${wall}s" "peak=$peak" "n=$devs" "$topic_short"
  done

  rm -f "$tmpfile"
}

# ---- main -------------------------------------------------------------------

MODE=""
SINCE=""

[[ $# -eq 0 ]] && { usage; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --summary)  MODE="summary" ;;
    --log)      MODE="log" ;;
    --tsv)      MODE="tsv" ;;
    --since)    SINCE="$2"; shift ;;
    --help|-h)  usage ;;
    *)          echo "Unknown option: $1" >&2; usage ;;
  esac
  shift
done

case "$MODE" in
  summary)
    analyze_log "$SINCE"
    echo ""
    analyze_tsv "$SINCE"
    ;;
  log)
    analyze_log "$SINCE"
    ;;
  tsv)
    analyze_tsv "$SINCE"
    ;;
  *)
    usage
    ;;
esac
