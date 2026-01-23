#!/usr/bin/env bash
# PreCompact Hook - コンテキスト圧縮前の自動Serena memory保存
# 【必須】compact前にSerena memoryへ保存、compact後に読み込み

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# セッション情報を取得
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // "."')
PROJECT_NAME=$(basename "$PROJECT_DIR")
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Serena MCP が利用可能かチェック
SERENA_AVAILABLE=false
if echo "$INPUT" | jq -e '.mcp_servers | has("serena")' > /dev/null 2>&1; then
  SERENA_AVAILABLE=true
fi

# メッセージ構築
if [ "$SERENA_AVAILABLE" = true ]; then
  SYSTEM_MESSAGE="🔴 COMPACT DETECTED - Serena memory保存を実行してください"
  # 強制指示: Claude Codeが必ずSerena memoryを保存するよう指示
  ADDITIONAL_CONTEXT="# ⚠️ MANDATORY: Pre-Compact Serena Memory Save\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**MUST DO NOW** (compact前に必ず実行):\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. \`mcp__serena__write_memory\` で現在の作業状態を保存:\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}   - memory_file_name: \`compact-restore-${TIMESTAMP}\`\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}   - content: 現在のタスク、進捗、次のアクション、重要なコンテキスト\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 保存内容テンプレート:\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}\`\`\`markdown\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}# Compact Restore Point - ${TIMESTAMP}\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## 現在のタスク\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}<タスクの説明>\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## 進捗状況\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}<完了した作業、残りの作業>\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## 重要なコンテキスト\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}<ファイルパス、設計決定、注意点>\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## 次のアクション\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}<compact後に最初にやること>\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}\`\`\`\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}---\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}## Post-Compact Recovery (compact後に自動実行)\n\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}compact後、最初の応答で以下を実行:\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. \`mcp__serena__list_memories\` でmemory一覧確認\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. \`compact-restore-*\` memoryを読み込み\n"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 読み込んだコンテキストを基に作業再開\n"
else
  SYSTEM_MESSAGE="⚠️ COMPACT DETECTED - Serena MCPが無効です"
  ADDITIONAL_CONTEXT="Serena MCPを有効にしてcontext preservation機能を使用してください。"
fi

# JSON出力
cat <<EOF
{
  "systemMessage": "$SYSTEM_MESSAGE",
  "additionalContext": "$ADDITIONAL_CONTEXT"
}
EOF
