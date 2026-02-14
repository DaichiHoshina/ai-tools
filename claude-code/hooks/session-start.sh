#!/usr/bin/env bash
# SessionStart Hook - protection-mode + guidelines 自動読み込み
# セッション開始時にSerena memoryリストを確認 + compact-restore読み込み

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

# JSON入力を読み込む
INPUT=$(cat)

# Serena MCPが有効かチェック
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  jq -n \
    --arg sm "${ICON_SUCCESS} Session initialized: protection-mode + guidelines loaded" \
    --arg ac "**Auto-loaded**: protection-mode (操作チェッカー), load-guidelines will be suggested based on project detection.

**Serena Auto-Init** (read-only operations are Safe, execute without confirmation):
1. \`mcp__serena__check_onboarding_performed\` → check status (Safe operation)
2. If NOT onboarded: notify user and suggest running \`/serena オンボーディング\` (Boundary - requires confirmation)
3. \`mcp__serena__list_memories\` → list and read relevant memories including compact-restore-* (Safe operation)

This reduces manual \`/serena オンボーディング\` and \`/serena-refresh\` by automating Safe read operations.

**Development Principles**:
- ${ICON_SUCCESS} 安全操作: 即実行
- ${ICON_WARNING} 要確認操作: git/file operations require confirmation
- ${ICON_FORBIDDEN} 禁止操作: dangerous operations blocked
- Type safety: Avoid 'any', minimize 'as'

See CLAUDE.md for details." \
    '{systemMessage: $sm, additionalContext: $ac}'
else
  jq -n \
    --arg sm "${ICON_WARNING} Serena not configured - basic mode" \
    --arg ac "**Auto-loaded**: protection-mode (操作チェッカー)

**Development Principles**:
- ${ICON_SUCCESS} 安全操作: 即実行
- ${ICON_WARNING} 要確認操作: git/file operations require confirmation
- ${ICON_FORBIDDEN} 禁止操作: dangerous operations blocked
- Type safety: Avoid 'any', minimize 'as'" \
    '{systemMessage: $sm, additionalContext: $ac}'
fi
