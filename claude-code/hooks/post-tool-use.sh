#!/usr/bin/env bash
# PostToolUse Hook - ツール実行後の自動フォーマット
# Boris: "最後の10%を仕上げる" - CIでフォーマットエラー防止

set -euo pipefail

# jq前提条件チェック
if ! command -v jq &> /dev/null; then
    echo '{"error": "jq not installed. Please run: brew install jq"}' >&2
    exit 1
fi

# JSON入力を読み込む
INPUT=$(cat)

# ツール名を取得
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# デフォルトメッセージ
MESSAGE=""

# Edit/Writeツールの場合のみフォーマット実行
case "$TOOL_NAME" in
  "Edit"|"Write")
    # ファイルパスを取得
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    
    if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
      # 拡張子を取得
      EXT="${FILE_PATH##*.}"
      
      case "$EXT" in
        "go")
          # Go: gofmt で自動フォーマット
          if command -v gofmt &> /dev/null; then
            if gofmt -w "$FILE_PATH" 2>/dev/null; then
              MESSAGE=" Auto-formatted (Go): $FILE_PATH"
            else
              MESSAGE="  gofmt warning: $FILE_PATH (non-blocking)"
            fi
          fi
          ;;
        
        "ts"|"tsx"|"js"|"jsx")
          # TypeScript/JavaScript: prettier で自動フォーマット
          if command -v npx &> /dev/null; then
            # prettier がプロジェクトにあるかチェック
            if npx prettier --write "$FILE_PATH" 2>/dev/null; then
              MESSAGE=" Auto-formatted (Prettier): $FILE_PATH"
            else
              MESSAGE="  prettier warning: $FILE_PATH (non-blocking)"
            fi
          fi
          ;;
        
        *)
          # その他のファイルタイプはスキップ
          ;;
      esac
    fi
    ;;
  
  *)
    # Edit/Write以外のツールは何もしない
    ;;
esac

# JSON出力
if [ -n "$MESSAGE" ]; then
  cat <<EOF
{
  "systemMessage": "$MESSAGE"
}
EOF
else
  # メッセージがない場合は空のJSONを返す
  echo "{}"
fi
