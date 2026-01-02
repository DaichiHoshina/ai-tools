#!/usr/bin/env bash
# PreCompact Hook - コンテキスト圧縮前の自動保存
# 重要な情報をSerena memoryに保存してコンテキスト消失を防ぐ

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# セッション情報を取得
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // "."')
PROJECT_NAME=$(basename "$PROJECT_DIR")
CURRENT_TOKENS=$(echo "$INPUT" | jq -r '.current_tokens // 0')

# コンパクション前のバックアップディレクトリ
BACKUP_DIR="$HOME/.claude/pre-compact-backups"
mkdir -p "$BACKUP_DIR"

# バックアップファイル
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="$BACKUP_DIR/${PROJECT_NAME}_${SESSION_ID}_${TIMESTAMP}.json"

# セッション情報をバックアップ
echo "$INPUT" > "$BACKUP_FILE"

# Serena MCP が利用可能かチェック
SERENA_AVAILABLE=false
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  SERENA_AVAILABLE=true
fi

# メッセージ構築
SYSTEM_MESSAGE="📦 Pre-compact backup saved: $BACKUP_FILE"
ADDITIONAL_CONTEXT="# Pre-Compact Checklist\n\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## Current State\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **Session ID**: $SESSION_ID\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **Project**: $PROJECT_NAME\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **Current Tokens**: $CURRENT_TOKENS\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **Backup File**: \`$BACKUP_FILE\`\n\n"

# Serena memory推奨
if [ "$SERENA_AVAILABLE" = true ]; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## 🧠 Serena Memory Recommendation\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**Action Required**: Save important information to Serena memory before compaction:\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}\`\`\`bash\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}# Example: Save current implementation details\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}/serena write-memory \"session-$(date +%Y%m%d)\" \"<important-context>\"\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}\`\`\`\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**Why?**: After compaction, detailed context will be lost. Serena memory preserves critical information.\n\n"
else
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## ⚠️  Serena MCP Not Available\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}Consider enabling Serena MCP for automatic context preservation.\n\n"
fi

# コンパクション後のリマインダー
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## Post-Compact Recovery\n\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}After compaction completes:\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. Run \`/reload\` to restore CLAUDE.md settings\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. Check Serena memory for preserved context\n"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. Review backup file if needed: \`cat $BACKUP_FILE | jq\`\n"

# JSON出力
cat <<EOF
{
  "systemMessage": "$SYSTEM_MESSAGE",
  "additionalContext": "$ADDITIONAL_CONTEXT"
}
EOF
