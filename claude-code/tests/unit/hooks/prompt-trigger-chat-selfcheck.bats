#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/lib/prompt-trigger-detectors.sh
# _inject_chat_selfcheck_if_signal: 100字超文 反復 signal → [chat-selfcheck] inject
# (2026-07-17 retrospective A案)
# =============================================================================

setup() {
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/hooks/lib/prompt-trigger-detectors.sh"
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"

  # 本番 ~/.claude/logs/ を汚染しないよう HOME を差し替え
  export HOME="$TEST_TMPDIR"
  mkdir -p "${HOME}/.claude/logs"

  # shellcheck source=../../../hooks/lib/prompt-trigger-detectors.sh
  source "$LIB_FILE"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  rm -f /tmp/claude-chat-selfcheck-selfcheck-bats-*
}

# 直近 24h の log に「100字超文」を N 件書く (context_label=chat / block or warn)
_write_recent_hits() {
  local n="$1"
  local log="${HOME}/.claude/logs/jp-quality-block.log"
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  local i
  for (( i=0; i<n; i++ )); do
    printf '%s | %s | structural: 100字超文 1文 | warn\n' "$ts" "chat" >> "$log"
  done
}

_write_warn_state_file() {
  local session_id="$1"
  local date_today="$2"
  local contains_100="$3"  # 1=含む / 0=含まない
  local f="/tmp/claude-stop-jpq-warn-${session_id}-${date_today}"
  if [[ "$contains_100" == "1" ]]; then
    printf '%s' "▲ chat 文体 warn: structural: 100字超文: 1文 → 文分割" > "$f"
  else
    printf '%s' "▲ chat 文体 warn: 体言止めbullet: 2行" > "$f"
  fi
  printf '%s\n' "$f"
}

# =============================================================================
# Case 1: 両 signal (直前 turn warn file + 直近 24h 反復 2 件以上) が揃うと inject する
# =============================================================================
@test "chat-selfcheck: 両 signal 揃いで [chat-selfcheck] を inject する" {
  local sid="selfcheck-bats-hit-$$"
  local today
  printf -v today '%(%Y%m%d)T' -1
  local warn_file
  warn_file=$(_write_warn_state_file "$sid" "$today" 1)
  _write_recent_hits 2

  run _inject_chat_selfcheck_if_signal "$sid" "$today"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[chat-selfcheck]" ]]
  [[ "$output" =~ "100 字以内で句点" ]]
}

# =============================================================================
# Case 2: 直近 24h の反復が 1 件のみ (単発) → inject しない
# =============================================================================
@test "chat-selfcheck: 直近反復が 1 件のみ (単発) では inject しない" {
  local sid="selfcheck-bats-single-$$"
  local today
  printf -v today '%(%Y%m%d)T' -1
  _write_warn_state_file "$sid" "$today" 1
  _write_recent_hits 1

  run _inject_chat_selfcheck_if_signal "$sid" "$today"
  [ "$status" -eq 1 ]
  [[ -z "$output" ]]
}

# =============================================================================
# Case 3: warn state file に 100字超文 signal がない → inject しない
# =============================================================================
@test "chat-selfcheck: warn state file が別種 signal (体言止め等) では inject しない" {
  local sid="selfcheck-bats-other-$$"
  local today
  printf -v today '%(%Y%m%d)T' -1
  _write_warn_state_file "$sid" "$today" 0
  _write_recent_hits 3

  run _inject_chat_selfcheck_if_signal "$sid" "$today"
  [ "$status" -eq 1 ]
}

# =============================================================================
# Case 4 (throttle): 300 秒以内の 2 回目呼出しは抑制される
# =============================================================================
@test "chat-selfcheck: throttle - 300 秒以内の 2 回目呼出しは抑制される" {
  local sid="selfcheck-bats-throttle-$$"
  local today
  printf -v today '%(%Y%m%d)T' -1
  _write_warn_state_file "$sid" "$today" 1
  _write_recent_hits 2

  run _inject_chat_selfcheck_if_signal "$sid" "$today"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[chat-selfcheck]" ]]

  # 2 回目呼出し (warn state file を再作成、throttle flag は残ったまま)
  _write_warn_state_file "$sid" "$today" 1
  run _inject_chat_selfcheck_if_signal "$sid" "$today"
  [ "$status" -eq 1 ]
  [[ -z "$output" ]]
}

# =============================================================================
# Case 5 (throttle): 300 秒超過後は再度 inject される
# =============================================================================
@test "chat-selfcheck: throttle - 300 秒超過後は再度 inject される" {
  local sid="selfcheck-bats-expired-$$"
  local today
  printf -v today '%(%Y%m%d)T' -1
  _write_warn_state_file "$sid" "$today" 1
  _write_recent_hits 2

  # throttle flag を 300 秒より前の timestamp で事前に作る
  local flag="/tmp/claude-chat-selfcheck-${sid}-${today}"
  local past
  printf -v past '%(%s)T' "$(( $(date +%s) - 301 ))"
  printf '%s\n' "$past" > "$flag"

  run _inject_chat_selfcheck_if_signal "$sid" "$today"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[chat-selfcheck]" ]]
  rm -f "$flag"
}
