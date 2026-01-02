#!/usr/bin/env bash
# SessionStart Hook - ai-tools 8原則対応
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
  "additionalContext": "# Available Tools\n- Serena MCP: Project-specific memory and code analysis\n- Context7: Latest tech documentation\n- Playwright: Browser automation\n\n# 8 Principles Reminder\n1. **mem**: Read/update serena memory\n2. **serena**: Use /serena commands\n3. **guidelines**: Auto-load language guidelines\n4. **自動処理禁止**: Ask before auto-formatting\n5. **完了通知**: afplay on completion\n6. **型安全**: Avoid any/as\n7. **コマンド提案**: Suggest /dev, /review, /plan\n8. **確認済**: Confirm before executing"
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
