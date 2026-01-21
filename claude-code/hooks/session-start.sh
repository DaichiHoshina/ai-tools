#!/usr/bin/env bash
# SessionStart Hook - ai-tools 10原則対応（kenron必須）
# セッション開始時にSerena memoryリストを確認

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# Serena MCPが有効かチェック
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  # additionalContextを最小化（詳細はCLAUDE.md参照）
  cat <<EOF
{
  "systemMessage": "📋 Serena active",
  "additionalContext": "Run: mcp__serena__list_memories, mcp__serena__check_onboarding_performed. See CLAUDE.md for 10 principles & kenron."
}
EOF
else
  cat <<EOF
{
  "systemMessage": "⚠️ Serena not configured"
}
EOF
fi
