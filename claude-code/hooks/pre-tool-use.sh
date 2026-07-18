#!/usr/bin/env bash
# PreToolUse Hook - protection-mode 必須チェック
# 3層分類: Safe/Boundary/Forbidden
# v2.2.0対応: jq安全出力、パターン検出強化

set -euo pipefail

# lib/hook-utils.sh を source する (ai-tools path helper 等)
_HOOK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" 2>/dev/null && pwd)"
# shellcheck source=../lib/hook-utils.sh
if [[ -f "${_HOOK_LIB_DIR}/hook-utils.sh" ]]; then
  # shellcheck disable=SC1091
  source "${_HOOK_LIB_DIR}/hook-utils.sh"
else
  # fallback: ~/.claude/lib/ 経由 (sync.sh to-local 済み環境)
  _FALLBACK_LIB="$HOME/.claude/lib/hook-utils.sh"
  # shellcheck disable=SC1090
  [[ -f "$_FALLBACK_LIB" ]] && source "$_FALLBACK_LIB" || true
fi

# jq 必須（require_jq は hook-utils.sh 定義。lib 不在の broken install では skip し従来挙動）
declare -f require_jq >/dev/null && require_jq

# lib/jp-quality-check.sh を source する (AI定型語 / NG語 block 系)
# shellcheck source=../lib/jp-quality-check.sh
if [[ -f "${_HOOK_LIB_DIR}/jp-quality-check.sh" ]]; then
  # shellcheck disable=SC1091
  source "${_HOOK_LIB_DIR}/jp-quality-check.sh"
else
  # fallback: ~/.claude/lib/ 経由 (sync.sh to-local 済み環境)
  _FALLBACK_JPLIB="$HOME/.claude/lib/jp-quality-check.sh"
  # shellcheck disable=SC1090
  [[ -f "$_FALLBACK_JPLIB" ]] && source "$_FALLBACK_JPLIB" || true
fi

# shellcheck source=lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/lib/thresholds.sh"
# hook-utils.sh 経由でも import 済みだが、broken install (lib/ 欠損) 時の fallback として直 source
# shellcheck source=lib/portable-stat.sh
source "${BASH_SOURCE[0]%/*}/lib/portable-stat.sh"
source "${BASH_SOURCE[0]%/*}/lib/touchable-files-state.sh"
# shellcheck source=lib/log-rotation.sh
source "${BASH_SOURCE[0]%/*}/lib/log-rotation.sh"

# Nerd Fonts icons
ICON_CRITICAL=$'\u25c9'   # exclamation-circle (critical/forbidden)
ICON_WARNING=$'\u25b2'    # exclamation-triangle (boundary)

# checker modules (\u95a2\u6570\u5b9a\u7fa9\u3092 hooks/lib/ \u306b\u5207\u308a\u51fa\u3057)
# shellcheck source=lib/rename-propagation.sh
source "${BASH_SOURCE[0]%/*}/lib/rename-propagation.sh"
# shellcheck source=lib/public-repo-guard.sh
source "${BASH_SOURCE[0]%/*}/lib/public-repo-guard.sh"
# shellcheck source=lib/memory-path-guard.sh
source "${BASH_SOURCE[0]%/*}/lib/memory-path-guard.sh"
# shellcheck source=lib/write-checkers.sh
source "${BASH_SOURCE[0]%/*}/lib/write-checkers.sh"
# shellcheck source=lib/agent-guard.sh
source "${BASH_SOURCE[0]%/*}/lib/agent-guard.sh"
# shellcheck source=lib/context-injectors.sh
source "${BASH_SOURCE[0]%/*}/lib/context-injectors.sh"
# shellcheck source=lib/bash-checkers.sh
source "${BASH_SOURCE[0]%/*}/lib/bash-checkers.sh"
# shellcheck source=lib/task-agent-checkers.sh
source "${BASH_SOURCE[0]%/*}/lib/task-agent-checkers.sh"
# shellcheck source=lib/notion-checkers.sh
source "${BASH_SOURCE[0]%/*}/lib/notion-checkers.sh"

# JSON入力を読み込む
INPUT=$(cat)

# 不正 JSON fail-close: 後続 read の exit 1 は Claude Code に hook error 扱いされ
# tool 実行が素通りする (fail-open) ため、検証時点で exit 2 block に倒す。
if ! jq -e . >/dev/null 2>&1 <<< "$INPUT"; then
  echo "[pre-tool-use] 不正な JSON stdin を検出、fail-close で block" >&2
  exit 2
fi

# ツール名 + セッションID を jq 1 回で取得 (fork 削減、@tsv + read。他 hook と同方式)
# stdin JSON が canonical source。env CLAUDE_CODE_SESSION_ID は前 session 値が leak することがあり
# (Claude Code が session 切替時に reset しない silent bug)、stdin が空のときのみ fallback として使う。
# canonical memory: feedback-hook-session-id-via-stdin (2026-06-22)、再発 incident: 2026-06-25
IFS=$'\t' read -r TOOL_NAME SESSION_ID < <(jq -r '[.tool_name // "", .session_id // ""] | @tsv' <<< "$INPUT")
SESSION_ID="${SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"

# protection-mode判定変数
GUARD_CLASS=""  # Safe, Boundary, Forbidden
MESSAGE=""
ADDITIONAL_CONTEXT=""



# ====================================
# protection-mode 3層分類判定
# ====================================

# session split warn: 任意 tool 呼出し前に 1 session 1 回だけ注入 (warn-only)
_CWD_FOR_SPLIT=$(jq -r '.cwd // empty' <<< "$INPUT")
_check_session_split "$SESSION_ID" "$_CWD_FOR_SPLIT"

case "$TOOL_NAME" in
  # === 安全操作（即実行可能） ===
  "Read")
    GUARD_CLASS="Safe"
    # ディレクトリ判定: EISDIR を事前ブロックして Glob/ls へ誘導
    READ_PATH=$(jq -r '.tool_input.file_path // empty' <<< "$INPUT")
    if [ -n "$READ_PATH" ] && [ -d "$READ_PATH" ]; then
      _DENY_REASON="Read対象がディレクトリ: ${READ_PATH} → Glob (pattern=\"${READ_PATH}/**/*\") または Bash (ls -la \"${READ_PATH}\") を使うこと"
      jq -n --arg reason "$_DENY_REASON" \
        '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
      exit 0
    fi
    ;;

  "Glob"|"Grep"|"WebFetch"|"WebSearch"|"ListMcpResourcesTool"|"ReadMcpResourceTool")
    GUARD_CLASS="Safe"
    # 安全操作はメッセージなし（トークン節約）
    ;;

  "mcp__serena__read_file"|"mcp__serena__list_dir"|"mcp__serena__find_file"|"mcp__serena__search_for_pattern"|"mcp__serena__get_symbols_overview"|"mcp__serena__find_symbol"|"mcp__serena__find_referencing_symbols"|"mcp__serena__list_memories"|"mcp__serena__read_memory"|"mcp__serena__get_current_config"|"mcp__serena__think_about_collected_information"|"mcp__serena__think_about_task_adherence"|"mcp__serena__think_about_whether_you_are_done")
    GUARD_CLASS="Safe"
    ;;

  "mcp__jira__jira_get"|"mcp__confluence__conf_get"|"mcp__context7__resolve-library-id"|"mcp__context7__query-docs")
    GUARD_CLASS="Safe"
    ;;

  # === 要確認操作（要確認・警告） ===
  "Edit"|"Write"|"MultiEdit"|"NotebookEdit")
    _handle_edit_write_tool "$INPUT" "$TOOL_NAME" "$SESSION_ID"
    ;;

  "Bash")
    _handle_bash_tool "$INPUT"
    ;;

  "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_content"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol"|"mcp__serena__write_memory"|"mcp__serena__delete_memory"|"mcp__serena__execute_shell_command"|"mcp__serena__rename_symbol")
    # MESSAGE なし: Serena write 系の毎回通知は noise。memory path block は Forbidden 側で独立動作
    GUARD_CLASS="Boundary"

    # .serena/memories/ block: create_text_file / write_memory 経由の書き込みも block
    # create_text_file は relative_path、write_memory は memory_name パラメータを使う
    _SERENA_PATH=$(jq -r '.tool_input.relative_path // .tool_input.memory_name // empty' <<< "$INPUT")
    if [[ -n "$_SERENA_PATH" ]]; then
      _check_serena_memory_path "$_SERENA_PATH"
    fi

    # code comment 規範 inject + AI定型語 block: serena 編集系 (content / body / repl param) も Write/Edit と同様に検査する
    case "$TOOL_NAME" in
      "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_content"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol")
        _SERENA_NEW_CONTENT=$(jq -r '[.tool_input.content // empty, .tool_input.body // empty, .tool_input.repl // empty] | join("\n")' <<< "$INPUT")
        _inject_code_comment_rules "$_SERENA_PATH" "$_SERENA_NEW_CONTENT"
        # relative_path は project root (cwd) 起点。絶対 path 除外判定 (_is_aitools_path 等) のため cwd と結合する
        _SERENA_ABS_PATH="$_SERENA_PATH"
        if [[ -n "$_SERENA_PATH" && "$_SERENA_PATH" != /* && -n "$_CWD_FOR_SPLIT" ]]; then
          _SERENA_ABS_PATH="${_CWD_FOR_SPLIT%/}/${_SERENA_PATH}"
        fi
        _run_ai_jargon_check "$_SERENA_ABS_PATH" "$_SERENA_NEW_CONTENT"
        # comment 体言止め block: Serena の repl/body/content は元々「新規追加分」相当のため diff を取らない
        run_comment_style_block_check "$_SERENA_ABS_PATH" "$_SERENA_NEW_CONTENT"
        ;;
    esac
    ;;

  "mcp__jira__jira_post"|"mcp__jira__jira_put"|"mcp__jira__jira_patch"|"mcp__jira__jira_delete"|"mcp__confluence__conf_post"|"mcp__confluence__conf_put"|"mcp__confluence__conf_patch"|"mcp__confluence__conf_delete")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: Jira/Confluence変更"
    ;;

  "mcp__claude_ai_Notion__notion-create-pages"|"mcp__claude_ai_Notion__notion-update-page"|"mcp__claude_ai_Notion__notion-create-comment"|"mcp__claude_ai_Notion__notion-create-database" \
  |"mcp__claude_ai_Slack__slack_send_message"|"mcp__claude_ai_Slack__slack_schedule_message"|"mcp__claude_ai_Slack__slack_create_canvas"|"mcp__claude_ai_Slack__slack_update_canvas")
    _handle_notion_slack_tool "$INPUT" "$TOOL_NAME"
    ;;

  "Task"|"Agent")
    _handle_task_agent_tool "$INPUT" "$TOOL_NAME" "$SESSION_ID"
    ;;

  "Skill")
    GUARD_CLASS="Safe"

    # ガイドラインは各スキル内で自動読み込み（additionalContext省略でトークン節約）
    ;;

  "TaskCreate"|"TaskUpdate"|"TaskList"|"TaskGet"|"AskUserQuestion"|"EnterPlanMode"|"ExitPlanMode")
    GUARD_CLASS="Safe"
    ;;

  *)
    # 未知のツールはBoundary扱い。MESSAGE は出さず (新 harness tool ごとに毎回出て noise)、
    # case 追加漏れの drift 検出用に tool 名だけ log へ残す
    GUARD_CLASS="Boundary"
    _UNCLASSIFIED_LOG="$HOME/.claude/logs/hook-info.log"
    _rotate_log_if_needed "$_UNCLASSIFIED_LOG"
    printf '[%s] unclassified-tool | %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$TOOL_NAME" >> "$_UNCLASSIFIED_LOG" 2>/dev/null || true
    ;;
esac

# ====================================
# JSON出力（jqで安全にエスケープ）
# ====================================

if [ -n "$ADDITIONAL_CONTEXT" ]; then
  if [ -n "$MESSAGE" ]; then
    jq -n --arg msg "$MESSAGE" --arg ctx "$ADDITIONAL_CONTEXT" \
      '{"systemMessage": $msg, "additionalContext": $ctx}'
  else
    jq -n --arg ctx "$ADDITIONAL_CONTEXT" \
      '{"additionalContext": $ctx}'
  fi
elif [ -n "$MESSAGE" ]; then
  jq -n --arg msg "$MESSAGE" \
    '{"systemMessage": $msg}'
else
  # 安全操作はメッセージなし（トークン節約）
  echo "{}"
fi

# Forbiddenの場合はexit 2でツール実行をブロック（v2.1.90で正常動作）
# exit 2 の block 理由は stderr 経由で Claude に渡る仕様のため、stdout JSON とは別に stderr へも出す。
# stderr なしだと harness には「hook error: No stderr output」としか表示されず原因特定ができない。
if [ "$GUARD_CLASS" = "Forbidden" ]; then
  {
    [ -n "$MESSAGE" ] && printf '%s\n' "$MESSAGE"
    [ -n "$ADDITIONAL_CONTEXT" ] && printf '%s\n' "$ADDITIONAL_CONTEXT"
  } >&2
  exit 2
fi
