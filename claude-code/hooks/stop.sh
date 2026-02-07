#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知音再生
# 8原則: 完了通知 - afplay ~/notification.mp3 実行

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# 通知音ファイルの存在確認
NOTIFICATION_FILE="$HOME/notification.mp3"

if [ -f "$NOTIFICATION_FILE" ]; then
  # 通知音を再生（バックグラウンドで実行）
  afplay "$NOTIFICATION_FILE" &

  cat <<EOF
{
  "systemMessage": "🔔 Task completed. Notification sound played."
}
EOF
else
  # 通知音ファイルが存在しない場合
  cat <<EOF
{
  "systemMessage": "  Notification file not found at ~/notification.mp3"
}
EOF
fi
