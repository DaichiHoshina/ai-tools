#!/usr/bin/env bash
# TeammateIdle Hook - エスカレーション階層付きアイドル検知
# Level 1: ログ記録 + ナッジ提案（初回）
# Level 2: 警告 + 再送提案（2回目）
# Level 3: 強制停止 + 再起動提案（3回以上）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# ICON_* \u306f hook-utils.sh \u3067\u5b9a\u7fa9\u6e08\u307f

# jq前提条件チェック
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# チームメイト情報を抽出（jq 1回で複数フィールド取得）
IFS=$'\t' read -r TEAMMATE_NAME TEAM_NAME < <(
  extract_json_fields "$INPUT" \
    '.teammate_name // "unknown"' \
    '.team_name // "unknown"'
)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# イベントログに記録（1000行超でローテーション）
LOG_FILE="${LOG_DIR}/agent-team-events.log"
if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE" | tr -d ' ') -gt 1000 ]]; then
  tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
echo "[${TIMESTAMP}] IDLE | teammate=${TEAMMATE_NAME} | team=${TEAM_NAME}" >> "$LOG_FILE"

# idle回数カウント（最後の START 以降の IDLE 数）
# awk 1 fork で「最終 START 行番号」と「以降の IDLE 数」を同時に取得（grep|tail|cut + tail|grep -c の5 fork → 1 fork）
IDLE_COUNT=$(awk -v t="teammate=${TEAMMATE_NAME}" '
  /START/ && $0 ~ t { last_start=NR; idle=0; next }
  /IDLE/  && $0 ~ t && NR > last_start { idle++ }
  END { print idle+0 }
' "$LOG_FILE" 2>/dev/null || echo "0")

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
