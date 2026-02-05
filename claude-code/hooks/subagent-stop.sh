#!/usr/bin/env bash
# SubagentStop Hook - サブエージェント終了を検知
# エージェント情報をログ記録し、実行時間を計算

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
echo "[${TIMESTAMP}] STOP  | agent_id=${AGENT_ID} | type=${AGENT_TYPE} | cwd=${CWD}" >> "$LOG_FILE"

# 実行時間計算（同じagent_idのSTARTとSTOPの差分）
DURATION="N/A"
if [ -f "$LOG_FILE" ] && [ "$AGENT_ID" != "unknown" ]; then
  START_TIME=$(grep "START.*agent_id=${AGENT_ID}" "$LOG_FILE" | tail -1 | awk -F'[][]' '{print $2}' || echo "")
  if [ -n "$START_TIME" ]; then
    # 簡易的な秒数計算（dateコマンドで変換）
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +"%s" 2>/dev/null || echo "0")
    STOP_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TIMESTAMP" +"%s" 2>/dev/null || date +"%s")
    if [ "$START_EPOCH" -gt 0 ]; then
      DURATION_SEC=$((STOP_EPOCH - START_EPOCH))
      if [ $DURATION_SEC -ge 60 ]; then
        DURATION="${DURATION_SEC}s ($((DURATION_SEC / 60))m $((DURATION_SEC % 60))s)"
      else
        DURATION="${DURATION_SEC}s"
      fi
    fi
  fi
fi

# 統計情報計算（過去24時間の完了したサブエージェント数）
if [ -f "$LOG_FILE" ]; then
  CUTOFF=$(date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  if [ -n "$CUTOFF" ]; then
    RECENT_COUNT=$(grep "STOP" "$LOG_FILE" | awk -v cutoff="$CUTOFF" -F'[][]' '{if ($2 >= cutoff) count++} END {print count+0}')
  else
    RECENT_COUNT=$(grep -c "STOP" "$LOG_FILE" || echo "0")
  fi
else
  RECENT_COUNT=0
fi

# 結果を返す
cat <<EOF
{
  "systemMessage": "✅ Subagent completed: ${AGENT_TYPE}",
  "additionalContext": "**Agent ID**: ${AGENT_ID}
**Type**: ${AGENT_TYPE}
**Duration**: ${DURATION}
**Recent Activity**: ${RECENT_COUNT} subagents completed in last 24h

Subagent logs: ~/.claude/logs/subagent-events.log"
}
EOF
