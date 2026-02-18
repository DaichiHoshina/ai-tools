#!/usr/bin/env bash
# TaskCompleted Hook - Agent Teamsでタスクが完了したことを検知
# v2.1.33で追加されたフックイベント

set -euo pipefail

# Nerd Fonts icon
ICON_SUCCESS=$'\u2713'  # check-circle

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# タスク情報を抽出（公式スキーマ準拠）
TASK_ID=$(echo "$INPUT" | jq -r '.task_id // "unknown"')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "unknown"')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録
LOG_FILE="${LOG_DIR}/agent-team-events.log"
echo "[${TIMESTAMP}] COMPLETED | task_id=${TASK_ID} | subject=${TASK_SUBJECT} | teammate=${TEAMMATE_NAME} | team=${TEAM_NAME}" >> "$LOG_FILE"

# 統計情報計算（今日の完了タスク数）
TODAY=$(date -u +"%Y-%m-%d")
COMPLETED_TODAY=$(grep -c "${TODAY}.*COMPLETED" "$LOG_FILE" 2>/dev/null || echo "0")

# 結果を返す
jq -n \
  --arg sm "${ICON_SUCCESS} Task completed: ${TASK_SUBJECT} (${TASK_ID}) by ${TEAMMATE_NAME} | Today: ${COMPLETED_TODAY} tasks done" \
  '{systemMessage: $sm}'
