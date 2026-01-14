#!/usr/bin/env bash
# SessionStart Hook - ai-tools 9原則対応
# セッション開始時にSerena memoryリストを確認

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# Serena MCPが有効かチェック
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  # additionalContextとしてSerena memory情報を提供
  cat <<EOF
{
  "systemMessage": "📋 Serena MCP is active. Use /serena to access project memory.",
  "additionalContext": "# Session Start Actions (MUST DO)\n1. Call mcp__serena__list_memories to see available memories\n2. Call mcp__serena__check_onboarding_performed to verify project state\n3. Read relevant memories if needed for the task\n\n# Available Tools\n- Serena MCP: Project-specific memory and code analysis\n- Context7: Latest tech documentation\n- Playwright: Browser automation\n\n# 9 Principles Reminder\n1. **kenron**: Safe(即実行)/Boundary(要確認)/Forbidden(拒否)\n2. **mem**: Read/update serena memory\n3. **serena**: Use /serena commands\n4. **guidelines**: Auto-load language guidelines\n5. **自動処理禁止**: Ask before auto-formatting\n6. **完了通知**: afplay on completion\n7. **型安全**: Avoid any/as\n8. **コマンド提案**: Suggest /dev, /review, /plan\n9. **確認済**: Confirm before executing"
}
EOF
else
  # Serenaが無効の場合は警告
  cat <<EOF
{
  "systemMessage": "⚠️  Serena MCP is not configured for this project.",
  "additionalContext": "Consider configuring Serena MCP for better project memory management."
}
EOF
fi
