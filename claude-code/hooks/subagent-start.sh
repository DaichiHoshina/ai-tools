#!/usr/bin/env bash
# SubagentStart Hook - サブエージェント起動を検知
# エージェント情報をログ記録し、統計情報を表示

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# エージェント情報を抽出
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録
LOG_FILE="${LOG_DIR}/subagent-events.log"
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
**Recent Activity**: ${RECENT_COUNT} subagents started in last 24h

Subagent logs: ~/.claude/logs/subagent-events.log"

jq -n \
  --arg sm "🚀 Subagent started: ${AGENT_TYPE}" \
  --arg ac "$AC_MSG" \
  '{systemMessage: $sm, additionalContext: $ac}'
