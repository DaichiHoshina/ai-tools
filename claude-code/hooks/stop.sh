#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知（macOSバナー + ntfy.sh）

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
require_jq

INPUT=$(cat)
send_stop_notification "$INPUT" "" "Glass" "robot" "default"

echo '{"systemMessage":"Task completed."}'
