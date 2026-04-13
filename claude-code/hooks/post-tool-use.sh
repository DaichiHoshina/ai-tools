#!/usr/bin/env bash
# PostToolUse Hook - ツール実行後の自動フォーマット
# Boris: "最後の10%を仕上げる" - CIでフォーマットエラー防止

set -euo pipefail

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
  
  "Bash")
    # cdでgitリポジトリに移動した場合、作業ディレクトリをマーカーに記録
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
    if [ -n "$COMMAND" ] && [ -n "$SESSION_ID" ]; then
      CD_TARGET=$(echo "$COMMAND" | grep -oE 'cd [^ &|;]+' | head -1 | sed 's/^cd //' || true)
      if [ -n "$CD_TARGET" ] && [ -d "$CD_TARGET" ]; then
        if git -C "$CD_TARGET" rev-parse --git-dir >/dev/null 2>&1; then
          ABS_PATH=$(cd "$CD_TARGET" && pwd)
          echo "$ABS_PATH" > "/tmp/claude-wt-${SESSION_ID}"
        fi
      fi
    fi
    ;;

  *)
    # その他のツールは何もしない
    ;;
esac

# --- Analytics記録 ---
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${_HOOK_DIR}/../lib"
if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    _SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
    _PROJECT=$(basename "$(echo "$INPUT" | jq -r '.cwd // "."')")
    _INPUT_SUMMARY=""
    case "$TOOL_NAME" in
        "Skill") _INPUT_SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.skill // ""') ;;
        "Agent") _INPUT_SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""') ;;
    esac
    analytics_insert_tool_event "$_SESSION_ID" "$_PROJECT" "$TOOL_NAME" "$_INPUT_SUMMARY" 2>/dev/null || true
fi

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
