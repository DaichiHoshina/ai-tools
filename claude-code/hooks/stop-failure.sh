#!/usr/bin/env bash
# StopFailure Hook - APIエラー（レート制限・認証失敗）時の通知

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
require_jq

INPUT=$(cat)
# API error 通知も default OFF。CLAUDE_STOP_NOTIFY=1 で全 stop 通知を戻す。
# error 通知だけ残したい場合は CLAUDE_STOP_FAILURE_NOTIFY=1 を単独指定する。
if [[ "${CLAUDE_STOP_NOTIFY:-0}" == "1" ]] || [[ "${CLAUDE_STOP_FAILURE_NOTIFY:-0}" == "1" ]]; then
  send_stop_notification "$INPUT" "APIエラー" "" "warning,robot" "high"
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "${CWD:-unknown}")
TERM_SEQ=$(build_terminal_sequence "Claude Code [${PROJECT_NAME}] ${ICON_WARNING} API Error" "" "false")

jq -n --arg ts "$TERM_SEQ" '{systemMessage: "API error detected.", terminalSequence: $ts}'
