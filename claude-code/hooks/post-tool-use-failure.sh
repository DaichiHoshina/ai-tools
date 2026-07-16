#!/usr/bin/env bash
# PostToolUseFailure Hook - ツール実行失敗時のログ記録 + 親への additionalContext inject
# 失敗したツール呼び出しをログに記録し、デバッグを支援

set -euo pipefail

_ptuf_src="${BASH_SOURCE[0]}"
[[ "${_ptuf_src}" == /* ]] || _ptuf_src="${PWD}/${_ptuf_src}"
SCRIPT_DIR="${_ptuf_src%/*}"

LOG_DIR="${HOME}/.claude/logs"
LOG_FILE="${TOOL_FAILURE_LOG_FILE:-${LOG_DIR}/tool-failures.log}"
mkdir -p "$(dirname "${LOG_FILE}")"

# jq 必須（hook-utils.sh 非依存のため inline check）
if ! command -v jq &>/dev/null; then
  echo '{"error": "jq not installed. Please run: brew install jq (macOS) / apt install jq (Ubuntu)"}' >&2
  exit 1
fi

# JSON入力を読み取り（1回のみ）
INPUT=$(cat)

printf -v TIMESTAMP '%(%Y-%m-%d %H:%M:%S)T' -1

# フィールド一括抽出（jq 1回）: tool_name / session_id / cwd / duration_ms / error を同時取得
# @tsv は空フィールド前後で IFS=$'\t' read が正しく分割できないため改行区切り + mapfile を使用
mapfile -t _FIELDS < <(
  jq -r '
    .tool_name // "unknown",
    (.session_id // ""),
    (.cwd // "."),
    (.duration_ms // .tool_response.duration_ms // "" | tostring),
    (.error // "" | gsub("\n"; " "))
  ' <<< "$INPUT" 2>/dev/null || printf '%s\n%s\n%s\n%s\n%s\n' "unknown" "" "." "" ""
)
TOOL_NAME="${_FIELDS[0]:-unknown}"
_SESSION_ID_JSON="${_FIELDS[1]:-}"
CWD="${_FIELDS[2]:-.}"
DURATION_MS="${_FIELDS[3]:-}"
RAW_ERROR="${_FIELDS[4]:-}"
# stdin JSON が canonical source。env CLAUDE_CODE_SESSION_ID は session 切替時に
# 前 session 値が leak することがあり fallback 専用にする (incident 2026-06-25)
SESSION_ID="${_SESSION_ID_JSON:-${CLAUDE_CODE_SESSION_ID:-unknown}}"

# ERROR: raw が空なら fallback（jq 追加呼び出し不要）
if [[ -z "${RAW_ERROR}" ]]; then
  ERROR="no details"
else
  ERROR="${RAW_ERROR}"
fi

# ログ用は 500 文字切り詰め
LOG_ERROR="${ERROR:0:500}"

# ログ記録（500文字で切り詰め）
echo "[${TIMESTAMP}] FAIL: ${TOOL_NAME} | ${LOG_ERROR}" >> "${LOG_FILE}"

# ログファイルが _TH_LOG_ROTATION_LINES 超えたら古い行を削除
# shellcheck source=lib/log-rotation.sh
source "${SCRIPT_DIR}/lib/log-rotation.sh"
_rotate_log_by_lines_if_needed "${LOG_FILE}"

# --- additionalContext inject: error 200 chars 切り捨て + tool name 付与 ---
# format: "tool <tool_name> failed: <error[:200]>" (200超は末尾に " ..." 付与)
_INJECT_CTX=""
if [[ -n "${ERROR}" && "${ERROR}" != "no details" ]] || [[ -n "${TOOL_NAME}" && "${TOOL_NAME}" != "unknown" ]]; then
  _ERR_TRUNCATED="${ERROR:0:200}"
  if [[ "${#ERROR}" -gt 200 ]]; then
    _ERR_TRUNCATED="${_ERR_TRUNCATED} ..."
  fi
  _INJECT_CTX="tool ${TOOL_NAME} failed: ${_ERR_TRUNCATED}"
fi

# Serena MCP 失敗のセッション内カウンタ
# user-prompt-submit.sh が次プロンプト時に検知し Serena 再 activate を提案
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

# --- 親への additionalContext 出力 ---
if [[ -n "${_INJECT_CTX}" ]]; then
  jq -n --arg ctx "${_INJECT_CTX}" '{"additionalContext": $ctx}'
else
  echo "{}"
fi
