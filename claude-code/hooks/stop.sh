#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知（macOSバナー + ntfy.sh）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# セッション情報を抽出
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "作業が完了しました"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "${CWD:-unknown}")

# メッセージを80文字に切り詰め
NOTIFY_MSG="${LAST_MSG:0:80}"
if [ ${#LAST_MSG} -gt 80 ]; then
  NOTIFY_MSG="${NOTIFY_MSG}..."
fi

# macOS通知バナー（クリックでセッション再開）
if command -v terminal-notifier &>/dev/null; then
  terminal-notifier \
    -title "Claude Code [${PROJECT_NAME}]" \
    -message "${NOTIFY_MSG}" \
    -contentImage "$HOME/.claude/claude-icon.png" \
    -sound Glass \
    -execute "open -a Terminal.app && claude --resume '${SESSION_ID}'" &
fi

# ntfy.sh（CLAUDE_NTFY_TOPIC が設定されている場合のみ）
NTFY_TOPIC="${CLAUDE_NTFY_TOPIC:-}"
if [ -n "$NTFY_TOPIC" ]; then
  curl -sf \
    -H "Title: Claude Code [${PROJECT_NAME}]" \
    -H "Tags: robot" \
    -d "${NOTIFY_MSG}" \
    "https://ntfy.sh/${NTFY_TOPIC}" &>/dev/null &
fi

echo '{"systemMessage":"Task completed."}'
