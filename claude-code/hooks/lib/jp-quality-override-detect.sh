#!/usr/bin/env bash
if [[ "${_JP_QUALITY_OVERRIDE_DETECT_LOADED:-}" == "1" ]]; then
  return 0
fi
_JP_QUALITY_OVERRIDE_DETECT_LOADED=1

# stop.sh は log-rotation.sh を source しないため、この lib 単独で自己完結させる
# shellcheck source=./log-rotation.sh
source "${BASH_SOURCE[0]%/*}/log-rotation.sh"

_JP_OVERRIDE_WINDOW_S="${JP_OVERRIDE_WINDOW_S:-300}"
_JP_BLOCK_LOG="${_JP_BLOCK_LOG:-${HOME}/.claude/logs/jp-quality-block.log}"
_JP_OVERRIDE_LOG="${_JP_OVERRIDE_LOG:-${HOME}/.claude/logs/jp-quality-override.log}"

jp_quality_override_detect() {
  local last_msg="${1:-}"
  [[ -z "$last_msg" ]] && return 0
  [[ ! -f "$_JP_BLOCK_LOG" ]] && return 0
  _rotate_log_if_needed "$_JP_BLOCK_LOG"

  local now cutoff cutoff_iso
  now=$(date +%s)
  cutoff=$((now - _JP_OVERRIDE_WINDOW_S))
  cutoff_iso=$(date -r "$cutoff" +%Y-%m-%dT%H:%M:%S%z)

  awk -v cutoff="$cutoff_iso" '
    {
      line = $0
      n = length(line)
      last = 0
      for (i = n; i > 2; i--) if (substr(line, i - 2, 3) == " | ") { last = i - 2; break }
      if (last == 0) next
      verdict = substr(line, last + 3)
      head = substr(line, 1, last - 1)
      first = index(head, " | ")
      if (first == 0) next
      ts = substr(head, 1, first - 1)
      rest = substr(head, first + 3)
      second = index(rest, " | ")
      if (second == 0) next
      context = substr(rest, 1, second - 1)
      term = substr(rest, second + 3)
      if (ts < cutoff) next
      if (verdict != "block") next
      if (term ~ /^unknown-en:/ || term ~ /^structural:/) next
      print ts "\t" context "\t" term
    }
  ' "$_JP_BLOCK_LOG" | \
  while IFS=$'\t' read -r ts context term; do
    [[ -z "$term" ]] && continue
    if [[ "$last_msg" == *"$term"* ]]; then
      printf '%s | %s | %s | overridden\n' "$ts" "$context" "$term"
    fi
  done | awk '!seen[$0]++' >> "$_JP_OVERRIDE_LOG"

  return 0
}
