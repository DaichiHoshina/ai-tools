#!/usr/bin/env bash
# SessionEnd Hook - セッション終了時の自動処理
# 8原則: 完了通知（より確実な実装）+ 統計ログ保存

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# セッション情報を取得
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // "."')
PROJECT_NAME=$(basename "$PROJECT_DIR")

# 統計情報を取得（可能な場合）
TOTAL_TOKENS=$(echo "$INPUT" | jq -r '.total_tokens // 0')
TOTAL_MESSAGES=$(echo "$INPUT" | jq -r '.total_messages // 0')
DURATION=$(echo "$INPUT" | jq -r '.duration // 0')

# ログディレクトリ
LOG_DIR="$HOME/.claude/session-logs"
mkdir -p "$LOG_DIR"

# セッションログファイル
LOG_FILE="$LOG_DIR/$(date +%Y%m%d).log"

# ログエントリ作成
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_ENTRY="[$TIMESTAMP] Session: $SESSION_ID | Project: $PROJECT_NAME | Messages: $TOTAL_MESSAGES | Tokens: $TOTAL_TOKENS | Duration: ${DURATION}s"

# ログに追記
echo "$LOG_ENTRY" >> "$LOG_FILE"

# 通知音再生（8原則: 完了通知）
NOTIFICATION_FILE="$HOME/notification.mp3"
NOTIFICATION_STATUS=""

if [ -f "$NOTIFICATION_FILE" ]; then
  # 通知音を再生（バックグラウンド）
  afplay "$NOTIFICATION_FILE" &
  NOTIFICATION_STATUS="🔔 Notification sound played"
else
  NOTIFICATION_STATUS="⚠️  Notification file not found at ~/notification.mp3"
fi

# Serena memory更新推奨（重要な情報がある場合）
SERENA_REMINDER=""
if [ "$TOTAL_MESSAGES" -gt 20 ] || [ "$TOTAL_TOKENS" -gt 50000 ]; then
  SERENA_REMINDER="\n\n💡 **Tip**: This was a long session. Consider saving important insights to Serena memory:\n\`\`\`\n/serena write-memory <name> <content>\n\`\`\`"
fi

# 統計サマリー
SUMMARY="# Session Summary\n\n"
SUMMARY="${SUMMARY}- **Session ID**: $SESSION_ID\n"
SUMMARY="${SUMMARY}- **Project**: $PROJECT_NAME\n"
SUMMARY="${SUMMARY}- **Messages**: $TOTAL_MESSAGES\n"
SUMMARY="${SUMMARY}- **Tokens**: $TOTAL_TOKENS\n"
SUMMARY="${SUMMARY}- **Duration**: ${DURATION}s\n"
SUMMARY="${SUMMARY}- **Log**: $LOG_FILE\n"

if [ -n "$SERENA_REMINDER" ]; then
  SUMMARY="${SUMMARY}${SERENA_REMINDER}"
fi

# JSON出力
cat <<EOF
{
  "systemMessage": "$NOTIFICATION_STATUS | Session logged to $LOG_FILE",
  "additionalContext": "$SUMMARY"
}
EOF
