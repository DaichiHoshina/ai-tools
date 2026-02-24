#!/usr/bin/env bash
# PostCompact Reload Hook - compact後の自動コンテキスト復元
# SessionStart の "compact" matcher で発火
# compact後に /reload 相当の処理を自動実行するよう指示

set -euo pipefail

# Nerd Fonts icons
ICON_SUCCESS=$'\u2713'    # check-circle
ICON_WARNING=$'\u25b2'    # exclamation-triangle

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# Serena MCP が利用可能かチェック
SERENA_AVAILABLE=false
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  SERENA_AVAILABLE=true
fi

if [ "$SERENA_AVAILABLE" = true ]; then
  NL=$'\n'
  SYSTEM_MESSAGE="${ICON_SUCCESS} COMPACT完了 - コンテキスト自動復元を開始"
  ADDITIONAL_CONTEXT="**自動実行（必須）**: compact後の復元手順${NL}${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. \`mcp__serena__list_memories\` でメモリ一覧を取得${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 最新の \`compact-restore-*\` メモリを読み込む${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 当日の \`work-context-*\` メモリがあれば読み込む${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. 読み込んだ \`compact-restore-*\` は削除（蓄積防止）${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}5. 復元した情報のサマリーをユーザーに報告${NL}${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}これは /reload と同等の処理です。ユーザーの操作なしで自動実行してください。"
else
  SYSTEM_MESSAGE="${ICON_WARNING} COMPACT完了 - Serena未設定のため手動復元が必要"
  ADDITIONAL_CONTEXT="Serena MCPを有効にするとcompact後の自動復元が利用できます"
fi

jq -n \
  --arg sm "$SYSTEM_MESSAGE" \
  --arg ac "$ADDITIONAL_CONTEXT" \
  '{systemMessage: $sm, additionalContext: $ac}'
