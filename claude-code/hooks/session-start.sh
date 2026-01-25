#!/usr/bin/env bash
# SessionStart Hook - kenron + guidelines 自動読み込み
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
  "systemMessage": "✅ Session initialized: kenron + guidelines loaded",
  "additionalContext": "**Auto-loaded**: kenron (Guard関手), load-guidelines will be suggested based on project detection.

Run: mcp__serena__list_memories, mcp__serena__check_onboarding_performed. **MANDATORY**: Always check and reload compact-restore-* memory immediately to restore previous context.

**Development Principles**:
1. Boundary射確認: git/file operations require confirmation
2. Type safety: Avoid 'any', minimize 'as'
3. Confirm first: Ask before executing unclear operations

See CLAUDE.md for details."
}
EOF
else
  cat <<EOF
{
  "systemMessage": "⚠️ Serena not configured - basic mode",
  "additionalContext": "**Auto-loaded**: kenron (Guard関手)

**Development Principles**:
1. Boundary射確認: git/file operations require confirmation
2. Type safety: Avoid 'any', minimize 'as'
3. Confirm first: Ask before executing unclear operations"
}
EOF
fi
