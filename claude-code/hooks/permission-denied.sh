#!/usr/bin/env bash
# PermissionDenied Hook - autoモード分類器拒否のロギング
# v2.1.88で追加されたPermissionDeniedイベントを記録

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(jq -r '.tool_name // "unknown"' <<< "$INPUT")
SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$INPUT")
PROJECT=$(basename "$(jq -r '.cwd // "."' <<< "$INPUT")")

# --- Analytics記録 ---
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${HOOK_DIR}/../lib"
if [[ -f "${LIB_DIR}/analytics-writer.sh" ]]; then
    source "${LIB_DIR}/analytics-writer.sh"
    analytics_insert_tool_event "${SESSION_ID}" "${PROJECT}" "${TOOL_NAME}" "permission_denied" 2>/dev/null || true
fi

# 通知メッセージ
jq -n --arg tool "$TOOL_NAME" \
  '{systemMessage: ("Permission denied: " + $tool + " (auto mode)")}'
