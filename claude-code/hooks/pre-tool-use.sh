#!/usr/bin/env bash
# PreToolUse Hook - ツール実行前のチェック
# 9原則: 自動処理禁止、確認済
# v2.1.9対応: additionalContext でモデルに追加コンテキストを提供可能

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# ツール名を取得
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# デフォルト: ツール実行を許可
ALLOW=true
MESSAGE=""
ADDITIONAL_CONTEXT=""

case "$TOOL_NAME" in
  "Bash")
    # Bashコマンドの内容をチェック
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

    # 危険なコマンドパターンをチェック
    if echo "$COMMAND" | grep -qE '(npm run lint|prettier|eslint --fix|go fmt)'; then
      MESSAGE="⚠️  Auto-formatting detected. 8原則: 自動処理禁止 - User confirmation recommended."
    fi
    ;;

  "Edit"|"Write")
    # ファイル編集時のリマインダー
    MESSAGE="📝 File modification: Ensure type safety (avoid any/as) and follow guidelines."
    ;;

  "mcp__serena__"*)
    # Serena MCP使用時のリマインダー
    MESSAGE="🧠 Using Serena MCP: Remember to update memory after significant changes."
    ADDITIONAL_CONTEXT="Serena MCPを使用中。重要な変更後はmemoryを更新すること。"
    ;;
esac

# JSON出力 (v2.1.9対応: additionalContext)
if [ -n "$ADDITIONAL_CONTEXT" ]; then
  cat <<EOF
{
  "systemMessage": "$MESSAGE",
  "additionalContext": "$ADDITIONAL_CONTEXT"
}
EOF
elif [ -n "$MESSAGE" ]; then
  cat <<EOF
{
  "systemMessage": "$MESSAGE"
}
EOF
else
  # メッセージがない場合は空のJSONを返す
  echo "{}"
fi
