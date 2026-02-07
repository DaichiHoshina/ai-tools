#!/usr/bin/env bash
# TeammateIdle Hook - Agent Teamsでチームメイトがアイドル状態になったことを検知
# v2.1.33で追加されたフックイベント

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# チームメイト情報を抽出
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // "unknown"')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録
LOG_FILE="${LOG_DIR}/agent-team-events.log"
echo "[${TIMESTAMP}] IDLE | agent_id=${AGENT_ID} | type=${AGENT_TYPE}" >> "$LOG_FILE"

# 結果を返す
jq -n \
  --arg sm "💤 Teammate idle: ${AGENT_TYPE} (${AGENT_ID})" \
  '{systemMessage: $sm}'
