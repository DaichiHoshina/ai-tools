#!/usr/bin/env bash
# SubagentStart Hook - サブエージェント起動を検知
# エージェント情報をログ記録し、統計情報を表示

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# jq前提条件チェック
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# エージェント情報を抽出（jq 1回で複数フィールド取得）
IFS=$'\t' read -r AGENT_ID AGENT_TYPE CWD < <(
  extract_json_fields "$INPUT" \
    '.agent_id // "unknown"' \
    '.agent_type // "unknown"' \
    '.cwd // "."'
)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録（1000行超でローテーション）
LOG_FILE="${LOG_DIR}/subagent-events.log"
if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE" | tr -d ' ') -gt 1000 ]]; then
  tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
# 重複起動検知: 直近60秒以内に同一 agent_type が起動済みなら警告
_DUP_WARN=""
if [[ -f "$LOG_FILE" ]]; then
  # awk 1 fork で「最終マッチ行のタイムスタンプ」抽出（grep|tail|awk の3 fork → 1 fork）
  _LAST_SAME=$(awk -F'[][]' -v t="type=${AGENT_TYPE} " '$0 ~ t {ts=$2} END{print ts}' "$LOG_FILE" || true)
  if [[ -n "$_LAST_SAME" ]]; then
    _NOW_EPOCH=$(date +%s)
    _LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$_LAST_SAME" +%s 2>/dev/null || echo 0)
    if [[ "$_LAST_EPOCH" -gt 0 ]]; then
      _DIFF=$((_NOW_EPOCH - _LAST_EPOCH))
      if [[ "$_DIFF" -lt 60 ]]; then
        _DUP_WARN="⚠️ ${AGENT_TYPE} を${_DIFF}秒前に起動済み。重複起動の可能性あり（同一作業を二重実行していないか確認）。"
      fi
    fi
  fi
fi

echo "[${TIMESTAMP}] START | agent_id=${AGENT_ID} | type=${AGENT_TYPE} | cwd=${CWD}" >> "$LOG_FILE"

# --- Analytics記録 ---
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${_HOOK_DIR}/../lib"
if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    _PROJECT=$(basename "$CWD")
    analytics_insert_agent_start "$AGENT_ID" "$AGENT_TYPE" "$_PROJECT" 2>/dev/null || true
fi

# 統計情報計算（過去24時間のサブエージェント起動数）
if [ -f "$LOG_FILE" ]; then
  CUTOFF=$(date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  if [ -n "$CUTOFF" ]; then
    RECENT_COUNT=$(grep "START" "$LOG_FILE" | awk -v cutoff="$CUTOFF" -F'[][]' '{if ($2 >= cutoff) count++} END {print count+0}')
  else
    RECENT_COUNT=$(grep -c "START" "$LOG_FILE" || echo "0")
  fi
else
  RECENT_COUNT=0
fi

# 結果を返す（jqで安全にJSON生成）
AC_MSG="**Agent ID**: ${AGENT_ID}
**Type**: ${AGENT_TYPE}
**Working Directory**: ${CWD}
**Recent Activity**: ${RECENT_COUNT} subagents started in last 24h"
if [[ -n "$_DUP_WARN" ]]; then
  AC_MSG="${AC_MSG}

${_DUP_WARN}"
fi
AC_MSG="${AC_MSG}

Subagent logs: ~/.claude/logs/subagent-events.log"

_SM="🚀 Subagent started: ${AGENT_TYPE}"
if [[ -n "$_DUP_WARN" ]]; then
  _SM="⚠️ Subagent重複疑い: ${AGENT_TYPE}"
fi

jq -n \
  --arg sm "$_SM" \
  --arg ac "$AC_MSG" \
  '{systemMessage: $sm, additionalContext: $ac}'
