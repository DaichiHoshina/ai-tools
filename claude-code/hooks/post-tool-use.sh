#!/usr/bin/env bash
# PostToolUse Hook - ツール実行後の自動フォーマット
# Boris: "最後の10%を仕上げる" - CIでフォーマットエラー防止
# v2.2.1: jq集約・bash regex化・prettier実行条件化で毎操作高速化

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# JSON入力を読み込む
INPUT=$(cat)

# 全フィールドを1回のjqで取得（fork削減）
eval "$(jq -r '@sh "TOOL_NAME=\(.tool_name // "") FILE_PATH=\(.tool_input.file_path // "") COMMAND=\(.tool_input.command // "") SESSION_ID=\(.session_id // "") CWD=\(.cwd // ".") SKILL_NAME=\(.tool_input.skill // "") AGENT_TYPE=\(.tool_input.subagent_type // "")"' <<< "$INPUT")"

# デフォルトメッセージ
MESSAGE=""

# prettier 実行判定: package.json/.prettierrc* が FILE_PATH の祖先に存在する時のみ
has_prettier_config() {
  local dir
  dir=$(dirname "$1")
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "${dir}/.prettierrc" ] || [ -f "${dir}/.prettierrc.json" ] || [ -f "${dir}/.prettierrc.js" ] || [ -f "${dir}/.prettierrc.yaml" ] || [ -f "${dir}/.prettierrc.yml" ] || [ -f "${dir}/prettier.config.js" ]; then
      return 0
    fi
    if [ -f "${dir}/package.json" ] && grep -q '"prettier"' "${dir}/package.json" 2>/dev/null; then
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

# Edit/Writeツールの場合のみフォーマット実行
case "$TOOL_NAME" in
  "Edit"|"Write")
    if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
      EXT="${FILE_PATH##*.}"

      case "$EXT" in
        "go")
          if command -v gofmt &> /dev/null; then
            if gofmt -w "$FILE_PATH" 2>/dev/null; then
              MESSAGE=" Auto-formatted (Go): $FILE_PATH"
            else
              MESSAGE="  gofmt warning: $FILE_PATH (non-blocking)"
            fi
          fi
          ;;

        "ts"|"tsx"|"js"|"jsx")
          # prettier設定があるプロジェクト配下のみ実行（node起動コスト削減）
          if has_prettier_config "$FILE_PATH" && command -v npx &> /dev/null; then
            if npx --no-install prettier --write "$FILE_PATH" 2>/dev/null; then
              MESSAGE=" Auto-formatted (Prettier): $FILE_PATH"
            fi
            # prettier未インストールならmessage無し（警告抑制）
          fi
          ;;

        "sh"|"bash")
          # bash -n で syntax error 検出（実行はしない）
          if command -v bash &> /dev/null; then
            _SYNTAX_ERR=$(bash -n "$FILE_PATH" 2>&1) || {
              MESSAGE="⚠ Shell syntax error: ${FILE_PATH}\n${_SYNTAX_ERR}"
            }
          fi
          ;;
      esac
    fi
    ;;

  "Bash")
    # cdでgitリポジトリに移動した場合、作業ディレクトリをマーカーに記録
    if [ -n "$COMMAND" ] && [ -n "$SESSION_ID" ]; then
      # bash 正規表現でcd検出（grep外部プロセス削減）
      CD_TARGET=""
      if [[ "$COMMAND" =~ cd[[:space:]]+([^[:space:]\&\|\;]+) ]]; then
        CD_TARGET="${BASH_REMATCH[1]}"
      fi
      if [ -n "$CD_TARGET" ] && [ -d "$CD_TARGET" ]; then
        if git -C "$CD_TARGET" rev-parse --git-dir >/dev/null 2>&1; then
          ABS_PATH=$(cd "$CD_TARGET" && pwd)
          echo "$ABS_PATH" > "/tmp/claude-wt-${SESSION_ID}"
          ensure_worktree_memory_link "$ABS_PATH" 2>/dev/null || true
        fi
      fi
    fi
    ;;
esac

# --- Analytics記録 ---
_LIB_DIR="${SCRIPT_DIR}/../lib"
if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    _PROJECT=$(basename "$CWD")
    _INPUT_SUMMARY=""
    case "$TOOL_NAME" in
        "Skill") _INPUT_SUMMARY="$SKILL_NAME" ;;
        "Agent") _INPUT_SUMMARY="$AGENT_TYPE" ;;
    esac
    analytics_insert_tool_event "${SESSION_ID:-unknown}" "$_PROJECT" "$TOOL_NAME" "$_INPUT_SUMMARY" 2>/dev/null || true
fi

# JSON出力
if [ -n "$MESSAGE" ]; then
  jq -n --arg msg "$MESSAGE" '{systemMessage: $msg}'
else
  echo "{}"
fi
