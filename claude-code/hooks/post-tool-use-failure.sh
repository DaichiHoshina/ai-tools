#!/usr/bin/env bash
# PostToolUseFailure Hook - ツール実行失敗時のログ記録
# 失敗したツール呼び出しをログに記録し、デバッグを支援

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${LOG_DIR}/tool-failures.log"
mkdir -p "${LOG_DIR}"

# JSON入力を読み取り（1回のみ）
INPUT=$(cat)

printf -v TIMESTAMP '%(%Y-%m-%d %H:%M:%S)T' -1

# フィールド一括抽出（jq 1回）
IFS=$'\t' read -r TOOL_NAME _SESSION_ID_JSON CWD DURATION_MS < <(
  jq -r '[
    .tool_name // "unknown",
    .session_id // "unknown",
    .cwd // ".",
    (.duration_ms // .tool_response.duration_ms // "")
  ] | @tsv' <<< "$INPUT" 2>/dev/null || printf '%s\t%s\t%s\t%s\n' "unknown" "unknown" "." ""
)
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${_SESSION_ID_JSON}}"

# ERROR は改行→スペース変換 + 500文字切り詰めが必要なため個別 jq
ERROR=$(jq -r '.error // (.tool_input | tojson) // "no details"' <<< "$INPUT" 2>/dev/null | tr '\n' ' ' || echo "no details")
ERROR="${ERROR:0:500}"

# ログ記録（500文字で切り詰め）
echo "[${TIMESTAMP}] FAIL: ${TOOL_NAME} | ${ERROR}" >> "${LOG_FILE}"

# ログファイルが1000行超えたら古い行を削除
if [ "$(wc -l < "${LOG_FILE}")" -gt 1000 ]; then
  tail -500 "${LOG_FILE}" > "${LOG_FILE}.tmp"
  mv "${LOG_FILE}.tmp" "${LOG_FILE}"
fi

# Serena MCP 失敗のセッション内カウンタ
# user-prompt-submit.sh が次プロンプト時に検知し /serena-refresh を提案
if [[ "${TOOL_NAME}" == mcp__serena__* ]]; then
  _SERENA_COUNTER="${CLAUDE_SERENA_FAIL_COUNT:-/tmp/claude-serena-fail-count-${SESSION_ID}}"
  _CURRENT=0
  [[ -f "${_SERENA_COUNTER}" ]] && _CURRENT=$(cat "${_SERENA_COUNTER}" 2>/dev/null || echo 0)
  echo $((_CURRENT + 1)) > "${_SERENA_COUNTER}"
fi

# --- Analytics失敗イベント記録（exit_code=1）をバックグラウンドへ ---
(
  _LIB_DIR="${SCRIPT_DIR}/../lib"
  if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    # shellcheck disable=SC1091
    source "${_LIB_DIR}/analytics-writer.sh"
    _PROJECT=$(basename "${CWD}")
    analytics_insert_tool_event "${SESSION_ID}" "${_PROJECT}" "${TOOL_NAME}" "" "${DURATION_MS}" "1" 2>/dev/null || true
  fi
) 2>/dev/null &
