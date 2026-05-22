#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知（macOSバナー + ntfy.sh）

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
require_jq

INPUT=$(cat)
send_stop_notification "$INPUT" "" "Glass" "robot" "default"

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "${CWD:-unknown}")
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "Done"')
NOTIFY_BODY="${LAST_MSG:0:80}"
TERM_SEQ=$(build_terminal_sequence "Claude Code [${PROJECT_NAME}] ${ICON_SUCCESS} Done" "${NOTIFY_BODY}" "true")

# === SQL auto-pbcopy: 最終応答中の最後の ```sql ブロックを clipboard へ ===
# 末尾改行は bash $() の auto-strip で 1 個消費、pbcopy 不在環境 (Linux/CI) は silent skip
_SQL_NOTICE=""
if command -v pbcopy >/dev/null 2>&1; then
  LAST_SQL=$(printf '%s' "$LAST_MSG" | awk '
    BEGIN { in_block = 0; buf = ""; last = "" }
    /^```([sS][qQ][lL])$/ && !in_block { in_block = 1; buf = ""; next }
    /^```$/ && in_block { in_block = 0; last = buf; next }
    in_block { buf = buf $0 "\n" }
    END { if (last != "") printf "%s", last }
  ')
  if [[ -n "${LAST_SQL}" ]]; then
    if printf '%s' "${LAST_SQL}" | pbcopy 2>/dev/null; then
      _SQL_NOTICE="📋 最後の SQL ブロック (${#LAST_SQL} chars) を clipboard へコピー"
    else
      echo "[stop.sh] pbcopy failed (sql ${#LAST_SQL} chars), clipboard 未更新" >&2
    fi
  fi
fi

if [[ -n "${_SQL_NOTICE}" ]]; then
  jq -n --arg ts "$TERM_SEQ" --arg msg "$_SQL_NOTICE" '{terminalSequence: $ts, systemMessage: $msg}'
else
  jq -n --arg ts "$TERM_SEQ" '{terminalSequence: $ts}'
fi
