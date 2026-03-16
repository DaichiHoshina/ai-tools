#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知（音 + macOS通知センター）

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# macOS通知バナー
if command -v terminal-notifier &>/dev/null; then
  terminal-notifier -title "Claude Code" -message "作業が完了しました" -contentImage "$HOME/.claude/claude-icon.png" -sound Glass &
fi

# 通知音ファイル（任意）
NOTIFICATION_FILE="$HOME/notification.mp3"

if [ -f "$NOTIFICATION_FILE" ]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    afplay "$NOTIFICATION_FILE" &
  elif command -v paplay &>/dev/null; then
    paplay "$NOTIFICATION_FILE" &
  elif command -v aplay &>/dev/null; then
    aplay "$NOTIFICATION_FILE" &
  fi
fi

echo '{"systemMessage":"Task completed."}'
