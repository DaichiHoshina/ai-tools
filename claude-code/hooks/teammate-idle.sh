#!/usr/bin/env bash
# TeammateIdle Hook - Agent Teamsでチームメイトがアイドル状態になったことを検知
# v2.1.33で追加されたフックイベント

set -euo pipefail

# Nerd Fonts icon
ICON_IDLE=$'\u263e'  # moon (idle/sleep)

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# チームメイト情報を抽出（公式スキーマ準拠）
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録
LOG_FILE="${LOG_DIR}/agent-team-events.log"
echo "[${TIMESTAMP}] IDLE | teammate=${TEAMMATE_NAME} | team=${TEAM_NAME}" >> "$LOG_FILE"

# 結果を返す
jq -n \
  --arg sm "${ICON_IDLE} Teammate idle: ${TEAMMATE_NAME} (team: ${TEAM_NAME})" \
  '{systemMessage: $sm}'
