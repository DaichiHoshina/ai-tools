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

jq -n --arg ts "$TERM_SEQ" '{terminalSequence: $ts}'
