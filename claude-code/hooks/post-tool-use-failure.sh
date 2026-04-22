#!/usr/bin/env bash
# PostToolUseFailure Hook - ツール実行失敗時のログ記録
# 失敗したツール呼び出しをログに記録し、デバッグを支援

set -euo pipefail

LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${LOG_DIR}/tool-failures.log"
mkdir -p "${LOG_DIR}"

# JSON入力を読み取り
INPUT=$(cat)

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TOOL_NAME=$(echo "${INPUT}" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
ERROR=$(echo "${INPUT}" | jq -r '.error // .tool_input // "no details"' 2>/dev/null | head -c 500)

# ログ記録（500文字で切り詰め）
echo "[${TIMESTAMP}] FAIL: ${TOOL_NAME} | ${ERROR}" >> "${LOG_FILE}"

# ログファイルが1000行超えたら古い行を削除
if [ "$(wc -l < "${LOG_FILE}" | tr -d ' ')" -gt 1000 ]; then
  tail -500 "${LOG_FILE}" > "${LOG_FILE}.tmp"
  mv "${LOG_FILE}.tmp" "${LOG_FILE}"
fi

# Serena MCP 失敗のセッション内カウンタ
# user-prompt-submit.sh が次プロンプト時に検知し /serena-refresh を提案
if [[ "${TOOL_NAME}" == mcp__serena__* ]]; then
  _SERENA_COUNTER="/tmp/claude-serena-fail-count"
  _CURRENT=0
  [[ -f "${_SERENA_COUNTER}" ]] && _CURRENT=$(cat "${_SERENA_COUNTER}" 2>/dev/null || echo 0)
  echo $((_CURRENT + 1)) > "${_SERENA_COUNTER}"
fi
