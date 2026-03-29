#!/usr/bin/env bash
# TeammateIdle Hook - エスカレーション階層付きアイドル検知
# Level 1: ログ記録 + ナッジ提案（初回）
# Level 2: 警告 + 再送提案（2回目）
# Level 3: 強制停止 + 再起動提案（3回以上）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icons
ICON_IDLE=$'\u263e'      # moon (idle/sleep)
ICON_WARNING=$'\u25b2'   # exclamation-triangle
ICON_CRITICAL=$'\u25c9'  # critical

# jq前提条件チェック
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# チームメイト情報を抽出
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# イベントログに記録
LOG_FILE="${LOG_DIR}/agent-team-events.log"
echo "[${TIMESTAMP}] IDLE | teammate=${TEAMMATE_NAME} | team=${TEAM_NAME}" >> "$LOG_FILE"

# idle回数カウント（同一teammate_nameの直近のIDLEイベント数）
# STARTイベント以降のIDLE回数をカウント（最後の起動からの連続idle）
LAST_START_LINE=$(grep -n "START.*teammate=${TEAMMATE_NAME}" "$LOG_FILE" 2>/dev/null | tail -1 | cut -d: -f1 || true)
if [[ -n "${LAST_START_LINE}" ]]; then
  IDLE_COUNT=$(tail -n +"${LAST_START_LINE}" "$LOG_FILE" | grep -c "IDLE.*teammate=${TEAMMATE_NAME}" 2>/dev/null || echo "0")
else
  IDLE_COUNT=$(grep -c "IDLE.*teammate=${TEAMMATE_NAME}" "$LOG_FILE" 2>/dev/null || echo "0")
fi

# エスカレーションレベル判定
if [[ "${IDLE_COUNT}" -ge 3 ]]; then
  # Level 3: 強制停止 + 再起動提案
  LEVEL=3
  SM="${ICON_CRITICAL} Agent無応答（${IDLE_COUNT}回）: ${TEAMMATE_NAME}"
  AC="**エスカレーション Level 3**: ${TEAMMATE_NAME}が${IDLE_COUNT}回連続idle。\n\n**推奨アクション**:\n1. TaskStop で停止\n2. 別エージェントでタスクを再割り当て\n3. タスク内容が曖昧でないか確認"
  echo "[${TIMESTAMP}] ESCALATION_L3 | teammate=${TEAMMATE_NAME} | idle_count=${IDLE_COUNT}" >> "$LOG_FILE"
elif [[ "${IDLE_COUNT}" -ge 2 ]]; then
  # Level 2: 警告 + 再送提案
  LEVEL=2
  SM="${ICON_WARNING} Agent idle（${IDLE_COUNT}回）: ${TEAMMATE_NAME}"
  AC="**エスカレーション Level 2**: ${TEAMMATE_NAME}が${IDLE_COUNT}回idle。\n\n**推奨アクション**:\n1. SendMessage で状況確認（進捗を尋ねる）\n2. 応答なければ次回 Level 3 でタスク再割り当て"
  echo "[${TIMESTAMP}] ESCALATION_L2 | teammate=${TEAMMATE_NAME} | idle_count=${IDLE_COUNT}" >> "$LOG_FILE"
else
  # Level 1: ログ記録 + ナッジ提案
  LEVEL=1
  SM="${ICON_IDLE} Teammate idle: ${TEAMMATE_NAME} (team: ${TEAM_NAME})"
  AC="**エスカレーション Level 1**: 初回idle検知。通常は一時的。\n\n**推奨アクション**: SendMessage で軽くナッジ（「進捗どうですか？」）"
  echo "[${TIMESTAMP}] ESCALATION_L1 | teammate=${TEAMMATE_NAME} | idle_count=${IDLE_COUNT}" >> "$LOG_FILE"
fi

# 結果を返す
jq -n \
  --arg sm "$SM" \
  --arg ac "$AC" \
  --argjson level "$LEVEL" \
  '{systemMessage: $sm, additionalContext: $ac, escalationLevel: $level}'
