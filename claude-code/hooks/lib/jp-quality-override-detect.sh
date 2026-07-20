#!/usr/bin/env bash
if [[ "${_JP_QUALITY_OVERRIDE_DETECT_LOADED:-}" == "1" ]]; then
  return 0
fi
_JP_QUALITY_OVERRIDE_DETECT_LOADED=1

_JP_OVERRIDE_WINDOW_S="${JP_OVERRIDE_WINDOW_S:-300}"
_JP_BLOCK_LOG="${_JP_BLOCK_LOG:-${HOME}/.claude/logs/jp-quality-block.log}"
_JP_OVERRIDE_LOG="${_JP_OVERRIDE_LOG:-${HOME}/.claude/logs/jp-quality-override.log}"

jp_quality_override_detect() {
  local last_msg="${1:-}"
  [[ -z "$last_msg" ]] && return 0
  [[ ! -f "$_JP_BLOCK_LOG" ]] && return 0

  local now cutoff cutoff_iso
  now=$(date +%s)
  cutoff=$((now - _JP_OVERRIDE_WINDOW_S))
  cutoff_iso=$(date -r "$cutoff" +%Y-%m-%dT%H:%M:%S%z)

  awk -F' \\| ' -v cutoff="$cutoff_iso" '
    $1 >= cutoff && $4 == "block" {
      if ($3 ~ /^unknown-en:/ || $3 ~ /^structural:/) next
      print $1 "\t" $2 "\t" $3
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
