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
  NL=$'\n'
  ADDITIONAL_CONTEXT="**必須**: \`mcp__serena__write_memory\` で \`compact-restore-${TIMESTAMP}\` に保存${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}保存内容（以下を全て含めること）:${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. 現在のタスク（何を依頼されたか）${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 完了済みステップと残ステップ${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 編集中のファイルパスと変更内容の要約${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. 次に実行すべきアクション${NL}${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**復元**: compact後に \`/reload\` で自動復元"
else
  SYSTEM_MESSAGE="${ICON_WARNING} COMPACT検出 - Serena無効"
  ADDITIONAL_CONTEXT="Serena MCPを有効にしてください"
fi

# JSON出力（jqで安全にエスケープ）
jq -n \
  --arg sm "$SYSTEM_MESSAGE" \
  --arg ac "$ADDITIONAL_CONTEXT" \
  '{systemMessage: $sm, additionalContext: $ac}'
