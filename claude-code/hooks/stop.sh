#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知音再生
# 8原則: 完了通知 - プラットフォーム別に再生コマンドを選択

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# 通知音ファイルの存在確認
NOTIFICATION_FILE="$HOME/notification.mp3"

if [ -f "$NOTIFICATION_FILE" ]; then
  # プラットフォーム別に再生（バックグラウンドで実行）
  PLAYED=false
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    afplay "$NOTIFICATION_FILE" &
    PLAYED=true
  elif command -v paplay &>/dev/null; then
    paplay "$NOTIFICATION_FILE" &
    PLAYED=true
  elif command -v aplay &>/dev/null; then
    aplay "$NOTIFICATION_FILE" &
    PLAYED=true
  fi

  if [ "$PLAYED" = true ]; then
    echo '{"systemMessage":"Task completed. Notification sound played."}'
  else
    echo '{"systemMessage":"Task completed. No audio player found."}'
  fi
else
  echo '{"systemMessage":"Notification file not found at ~/notification.mp3"}'
fi
