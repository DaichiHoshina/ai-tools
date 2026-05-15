#!/usr/bin/env bash
# PostToolUse Hook - ツール実行後の自動フォーマット
# Boris: "最後の10%を仕上げる" - CIでフォーマットエラー防止
# v2.2.1: jq集約・bash regex化・prettier実行条件化で毎操作高速化

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
# writing-self-check.sh / bats-self-check.sh は md/bats case 内で lazy source

# JSON入力を読み込む
INPUT=$(cat)

# 全フィールドを1回のjqで取得（fork削減）
# BASH_STDOUT は Bash 時のみ実値、それ以外は空文字（巨大 stdout のメモリ転送回避）
eval "$(jq -r '@sh "TOOL_NAME=\(.tool_name // "") FILE_PATH=\(.tool_input.file_path // "") COMMAND=\(.tool_input.command // "") SESSION_ID=\(.session_id // "") CWD=\(.cwd // ".") SKILL_NAME=\(.tool_input.skill // "") AGENT_TYPE=\(.tool_input.subagent_type // "") DURATION_MS=\(.duration_ms // .tool_response.duration_ms // "") BASH_STDOUT=\(if .tool_name == "Bash" then (.tool_response.stdout // "") else "" end)"' <<< "$INPUT")"
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${SESSION_ID}}"

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

# Edit/Write/MultiEditツールの場合のみフォーマット実行
case "$TOOL_NAME" in
  "Edit"|"Write"|"MultiEdit")
    if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
      EXT="${FILE_PATH##*.}"

      case "$EXT" in
        "go")
          if command -v gofmt &> /dev/null; then
            if gofmt -w "$FILE_PATH" 2>/dev/null; then
              MESSAGE=$(append_message "$MESSAGE" " Auto-formatted (Go): $FILE_PATH")
            else
              MESSAGE=$(append_message "$MESSAGE" "  gofmt warning: $FILE_PATH (non-blocking)")
            fi
          fi
          ;;

        "ts"|"tsx"|"js"|"jsx")
          # prettier設定があるプロジェクト配下のみ実行（node起動コスト削減）
          if has_prettier_config "$FILE_PATH" && command -v npx &> /dev/null; then
            if npx --no-install prettier --write "$FILE_PATH" 2>/dev/null; then
              MESSAGE=$(append_message "$MESSAGE" " Auto-formatted (Prettier): $FILE_PATH")
            fi
            # prettier未インストールならmessage無し（警告抑制）
          fi
          ;;

        "sh"|"bash")
          # bash -n で syntax error 検出（実行はしない）
          if command -v bash &> /dev/null; then
            _SYNTAX_ERR=$(bash -n "$FILE_PATH" 2>&1) || {
              MESSAGE=$(append_message "$MESSAGE" "⚠ Shell syntax error: ${FILE_PATH}"$'\n'"${_SYNTAX_ERR}")
            }
          fi
          ;;

        "md")
          # ai-tools リポジトリの CLAUDE.md / references/*.md だけ writing self-check
          # 別リポジトリの同名構造での誤発火を多段判定で防止
          REAL_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "")
          if [ -n "$REAL_PATH" ]; then
            GIT_ROOT=$(git -C "$(dirname "$REAL_PATH")" rev-parse --show-toplevel 2>/dev/null || echo "")
            if [ "$(basename "$GIT_ROOT")" = "ai-tools" ] \
               && [[ "$REAL_PATH" =~ /claude-code/(CLAUDE\.md|references/.+\.md)$ ]]; then
              # shellcheck disable=SC1091
              source "${SCRIPT_DIR}/../lib/writing-self-check.sh"
              _WRITING_HITS=$(run_writing_check "$REAL_PATH")
              if [ -n "$_WRITING_HITS" ]; then
                MESSAGE=$(append_message "$MESSAGE" "⚠ writing self-check: ${REAL_PATH}"$'\n'"${_WRITING_HITS}")
              fi
              _BULLET_HITS=$(run_bullet_density_check "$REAL_PATH")
              if [ -n "$_BULLET_HITS" ]; then
                MESSAGE=$(append_message "$MESSAGE" "⚠ bullet density (writing-principles 違反): ${REAL_PATH}"$'\n'"${_BULLET_HITS}")
              fi
            fi
          fi
          ;;

        "bats")
          # ai-tools リポジトリの .bats ファイルだけ bats-self-check を実行
          REAL_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "")
          if [ -n "$REAL_PATH" ]; then
            GIT_ROOT=$(git -C "$(dirname "$REAL_PATH")" rev-parse --show-toplevel 2>/dev/null || echo "")
            if [ "$(basename "$GIT_ROOT")" = "ai-tools" ] \
               && [[ "$REAL_PATH" =~ /claude-code/tests/.+\.bats$ ]]; then
              # shellcheck disable=SC1091
              source "${SCRIPT_DIR}/../lib/bats-self-check.sh"
              _BATS_HITS=$(run_bats_check "$REAL_PATH")
              if [ -n "$_BATS_HITS" ]; then
                MESSAGE=$(append_message "$MESSAGE" "⚠ bats-self-check: ${REAL_PATH}"$'\n'"${_BATS_HITS}")
              fi
            fi
          fi
          ;;
      esac
    fi
    ;;

  "Bash")
    # statusline マーカー更新ロジック
    # 1. cd 検出時: cd 先で書く（worktree/repo 移動の明示的追跡）
    # 2. cd 無し時: data.cwd で書く（session 認識する cwd へ巻き戻し）
    # ただし既存マーカーが worktree (/private/tmp/wt-*) を指す場合は保護
    # （/snkr-issue 等の長期worktree作業で cd 含まない Bash 続行ケース）
    if [ -n "$SESSION_ID" ]; then
      MARKER_PATH="/tmp/claude-wt-${SESSION_ID}"
      CD_TARGET=""
      if [ -n "$COMMAND" ] && [[ "$COMMAND" =~ cd[[:space:]]+([^[:space:]\&\|\;]+) ]]; then
        CD_TARGET="${BASH_REMATCH[1]}"
      fi
      if [ -n "$CD_TARGET" ] && [ -d "$CD_TARGET" ]; then
        # cd 検出 → cd 先で書く
        if git -C "$CD_TARGET" rev-parse --git-dir >/dev/null 2>&1; then
          ABS_PATH=$(cd "$CD_TARGET" && pwd)
          echo "$ABS_PATH" > "${MARKER_PATH}"
          ensure_worktree_memory_link "$ABS_PATH" 2>/dev/null || true
        fi
      elif [ -n "$CWD" ] && [ -d "$CWD" ]; then
        # cd 無し → CWD で更新（worktree マーカーは保護）
        EXISTING_MARKER=""
        [ -f "${MARKER_PATH}" ] && EXISTING_MARKER=$(cat "${MARKER_PATH}" 2>/dev/null)
        if [[ ! "${EXISTING_MARKER}" =~ ^/private/tmp/wt- ]] && [[ ! "${EXISTING_MARKER}" =~ /worktrees?/ ]]; then
          if git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
            ABS_CWD=$(cd "$CWD" && pwd)
            if [ "$ABS_CWD" != "${EXISTING_MARKER}" ]; then
              echo "$ABS_CWD" > "${MARKER_PATH}"
            fi
          fi
        fi
      fi
    fi
    ;;
esac

# --- Output Sanitization (Bash 出力のシークレット検出/REDACT) ---
# rules/enterprise-security.md §2 のコード強制実装 (Phase 1: Bash のみ)
SANITIZE_COUNT=0
SANITIZED_STDOUT=""
if [[ "${TOOL_NAME}" == "Bash" ]]; then
  # BASH_STDOUT は冒頭の jq で取得済（重複 jq 排除）
  if [[ -n "${BASH_STDOUT:-}" ]] && [[ -f "${SCRIPT_DIR}/../lib/output-sanitizer.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../lib/output-sanitizer.sh"
    _SANITIZE_RESULT=$(sanitize_text "${BASH_STDOUT}")
    SANITIZE_COUNT="${_SANITIZE_RESULT%%$'\x1f'*}"
    SANITIZED_STDOUT="${_SANITIZE_RESULT#*$'\x1f'}"
  fi
fi

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
    analytics_insert_tool_event "${SESSION_ID:-unknown}" "$_PROJECT" "$TOOL_NAME" "$_INPUT_SUMMARY" "${DURATION_MS:-}" "0" 2>/dev/null || true
fi

# JSON出力
if [[ "${SANITIZE_COUNT}" -gt 0 ]]; then
  # シークレット検出 → tool 出力を書換 + Claude に通知
  _CTX="Secrets redacted: ${SANITIZE_COUNT} occurrence(s) in Bash stdout (rules/enterprise-security.md §2)"
  if [ -n "${MESSAGE}" ]; then
    jq -n --arg msg "${MESSAGE}" --arg out "${SANITIZED_STDOUT}" --arg ctx "${_CTX}" \
      '{systemMessage: $msg, hookSpecificOutput: {hookEventName: "PostToolUse", updatedToolOutput: $out, additionalContext: $ctx}}'
  else
    jq -n --arg out "${SANITIZED_STDOUT}" --arg ctx "${_CTX}" \
      '{hookSpecificOutput: {hookEventName: "PostToolUse", updatedToolOutput: $out, additionalContext: $ctx}}'
  fi
elif [ -n "${MESSAGE}" ]; then
  jq -n --arg msg "${MESSAGE}" '{systemMessage: $msg}'
else
  echo "{}"
fi
