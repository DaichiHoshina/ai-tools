#!/usr/bin/env bash
# StopFailure Hook - APIエラー（レート制限・認証失敗）時の通知

set -euo pipefail

_sf_src="${BASH_SOURCE[0]}"
[[ "${_sf_src}" == /* ]] || _sf_src="${PWD}/${_sf_src}"
SCRIPT_DIR="${_sf_src%/*}"
# shellcheck source=../lib/stop-common.sh
source "${SCRIPT_DIR}/../lib/stop-common.sh"
stop_hook_init "${SCRIPT_DIR}"

INPUT=$(cat)
# StopFailure hook も user turn (API error で session が止まった時) にだけ発火する。
# 明示的に off にしたい時は CLAUDE_STOP_NOTIFY=0 または CLAUDE_STOP_FAILURE_NOTIFY=0 を export する。
if [[ "${CLAUDE_STOP_NOTIFY:-1}" != "0" ]] && [[ "${CLAUDE_STOP_FAILURE_NOTIFY:-1}" != "0" ]]; then
  send_stop_notification "$INPUT" "APIエラー" "" "warning,robot" "high"
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "${CWD:-unknown}")
TERM_SEQ=$(build_terminal_sequence "Claude Code [${PROJECT_NAME}] ${ICON_WARNING} API Error" "" "false")

jq -n --arg ts "$TERM_SEQ" '{systemMessage: "API error detected.", terminalSequence: $ts}'
