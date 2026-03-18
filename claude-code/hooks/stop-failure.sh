#!/usr/bin/env bash
# StopFailure Hook - APIエラー（レート制限・認証失敗）時の通知

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
require_jq

INPUT=$(cat)
send_stop_notification "$INPUT" "APIエラー" "Basso" "warning,robot" "high"

echo '{"systemMessage":"API error detected."}'
