#!/usr/bin/env bash
# TaskCompleted Hook - Agent Teamsでタスクが完了したことを検知
# v2.1.33で追加されたフックイベント

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# タスク情報を抽出
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録
LOG_FILE="${LOG_DIR}/agent-team-events.log"
echo "[${TIMESTAMP}] COMPLETED | agent_id=${AGENT_ID} | type=${AGENT_TYPE}" >> "$LOG_FILE"

# 統計情報計算（今日の完了タスク数）
TODAY=$(date -u +"%Y-%m-%d")
COMPLETED_TODAY=$(grep -c "${TODAY}.*COMPLETED" "$LOG_FILE" 2>/dev/null || echo "0")

# 結果を返す
jq -n \
  --arg sm "✅ Task completed: ${AGENT_TYPE} (${AGENT_ID}) | Today: ${COMPLETED_TODAY} tasks done" \
  '{systemMessage: $sm}'
