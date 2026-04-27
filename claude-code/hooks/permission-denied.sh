#!/usr/bin/env bash
# PermissionDenied Hook - autoモード分類器拒否のロギング
# v2.1.88で追加されたPermissionDeniedイベントを記録

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${HOOK_DIR}/../lib"
source "${LIB_DIR}/hook-utils.sh"

INPUT=$(cat)

# jq 1回で複数フィールド抽出（fork削減）
IFS=$'\t' read -r TOOL_NAME SESSION_ID CWD < <(
  extract_json_fields "$INPUT" \
    '.tool_name // "unknown"' \
    '.session_id // "unknown"' \
    '.cwd // "."'
)
PROJECT=$(basename "$CWD")

# --- Analytics記録 ---
if [[ -f "${LIB_DIR}/analytics-writer.sh" ]]; then
    source "${LIB_DIR}/analytics-writer.sh"
    analytics_insert_tool_event "${SESSION_ID}" "${PROJECT}" "${TOOL_NAME}" "permission_denied" 2>/dev/null || true
fi

# 通知メッセージ
jq -n --arg tool "$TOOL_NAME" \
  '{systemMessage: ("Permission denied: " + $tool + " (auto mode)")}'
