#!/usr/bin/env bash
# SessionStart Hook - protection-mode + guidelines 自動読み込み
# セッション開始時にSerena memoryリストを確認 + compact-restore読み込み

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
  cat <<EOF
{
  "systemMessage": "✅ Session initialized: protection-mode + guidelines loaded",
  "additionalContext": "**Auto-loaded**: protection-mode (操作チェッカー), load-guidelines will be suggested based on project detection.

Run: mcp__serena__list_memories, mcp__serena__check_onboarding_performed. **MANDATORY**: Always check and reload compact-restore-* memory immediately to restore previous context.

**Development Principles**:
- ✅ 安全操作: 即実行
- ⚠️ 要確認操作: git/file operations require confirmation
- 🚫 禁止操作: dangerous operations blocked
- Type safety: Avoid 'any', minimize 'as'

See CLAUDE.md for details."
}
EOF
else
  cat <<EOF
{
  "systemMessage": "⚠️ Serena not configured - basic mode",
  "additionalContext": "**Auto-loaded**: protection-mode (操作チェッカー)

**Development Principles**:
- ✅ 安全操作: 即実行
- ⚠️ 要確認操作: git/file operations require confirmation
- 🚫 禁止操作: dangerous operations blocked
- Type safety: Avoid 'any', minimize 'as'"
}
EOF
fi
