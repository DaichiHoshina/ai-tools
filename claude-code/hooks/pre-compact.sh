#!/usr/bin/env bash
# PreCompact Hook - コンテキスト圧縮前の自動Serena memory保存
# 【必須】compact前にSerena memoryへ保存、compact後に読み込み

set -euo pipefail

# Nerd Fonts icons
ICON_CRITICAL=$'\u25c9'  # exclamation-circle
ICON_WARNING=$'\u25b2'   # exclamation-triangle

# JSON入力を読み込む
INPUT=$(cat)

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Serena MCP が利用可能かチェック
SERENA_AVAILABLE=false
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  SERENA_AVAILABLE=true
fi

# メッセージ構築
if [ "$SERENA_AVAILABLE" = true ]; then
  SYSTEM_MESSAGE="${ICON_CRITICAL} COMPACT検出 - Serena memoryに保存してください"
  ADDITIONAL_CONTEXT="**必須**: \`mcp__serena__write_memory\` で \`compact-restore-${TIMESTAMP}\` に保存\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}保存内容: 現在のタスク、進捗、次のアクション\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**復元**: compact後に \`/reload\` または \`mcp__serena__list_memories\` → \`compact-restore-*\` 読み込み"
else
  SYSTEM_MESSAGE="${ICON_WARNING} COMPACT検出 - Serena無効"
  ADDITIONAL_CONTEXT="Serena MCPを有効にしてください"
fi

# JSON出力（jqで安全にエスケープ）
jq -n \
  --arg sm "$SYSTEM_MESSAGE" \
  --arg ac "$ADDITIONAL_CONTEXT" \
  '{systemMessage: $sm, additionalContext: $ac}'
