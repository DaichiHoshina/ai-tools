#!/usr/bin/env bash
# SessionStart Hook - protection-mode + guidelines 自動読み込み
# セッション開始時にSerena memoryリストを確認 + compact-restore読み込み
# NOTE: Serena有無はチェックしない（compact直後はMCP未初期化の可能性あり）

set -euo pipefail

# Nerd Fonts icons
ICON_SUCCESS=$'\u2713'    # check-circle
ICON_WARNING=$'\u25b2'    # exclamation-triangle
ICON_FORBIDDEN=$'\u2297'  # ban

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を消費（未使用だが読み捨て必要）
cat > /dev/null

jq -n \
  --arg sm "${ICON_SUCCESS} Session初期化完了" \
  --arg ac "**自動**: protection-mode, Serena自動初期化（onboarding確認, memory読み込み）\n\n原則: ${ICON_SUCCESS}安全操作→即実行 ${ICON_WARNING}要確認→承認 ${ICON_FORBIDDEN}禁止→拒否" \
  '{systemMessage: $sm, additionalContext: $ac}'
