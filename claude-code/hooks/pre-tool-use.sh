#!/usr/bin/env bash
# PreToolUse Hook - protection-mode 必須チェック
# 3層分類: Safe/Boundary/Forbidden
# v2.2.0対応: jq安全出力、パターン検出強化

set -euo pipefail

# Nerd Fonts icons
ICON_CRITICAL=$'\u25c9'   # exclamation-circle (critical/forbidden)
ICON_WARNING=$'\u25b2'    # exclamation-triangle (boundary)

# JSON入力を読み込む
INPUT=$(cat)

# ツール名とパラメータを取得
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
TOOL_INPUT=$(jq -r '.tool_input // {}' <<< "$INPUT")

# protection-mode判定変数
GUARD_CLASS=""  # Safe, Boundary, Forbidden
MESSAGE=""
ADDITIONAL_CONTEXT=""

# ====================================
# Bash コマンド分類ヘルパー関数
# ====================================
classify_bash_command() {
  local cmd="$1"

  # 禁止操作チェック（危険なコマンド）
  # スペースの揺れ（\s+）とエスケープ（\\rm等）を考慮
  if echo "$cmd" | grep -qE '(rm\s+-rf\s+/|rm\s+-rf\s+\*|>\s*/dev/|:\(\)\{|sudo\s+rm|git\s+push\s+--force|git\s+push\s+-f)'; then
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} protection-mode:禁止操作 - 危険なコマンド検出！実行禁止"
    ADDITIONAL_CONTEXT="【protection-mode判定】禁止操作（実行禁止）\\n- 検出: 破壊的コマンド\\n- 対応: 実行を中止し、安全な代替手段を提案"
    return
  fi

  # 自動処理禁止チェック
  if echo "$cmd" | grep -qE '(npm run lint|prettier|eslint --fix|go fmt|autopep8|black )'; then
    GUARD_CLASS="Boundary"
    MESSAGE="${ICON_WARNING} 要確認: 自動整形"
    return
  fi

  # 変更系コマンド
  if echo "$cmd" | grep -qE '(git commit|git push|git merge|git rebase|npm install|pip install|go mod|docker build|docker push)'; then
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: 変更系コマンド"
    return
  fi

  # 読み取り系コマンド（チェーン・パイプを含まない単純コマンドのみ）
  if echo "$cmd" | grep -qE '^(git (status|log|diff|branch)|ls |pwd$|echo |cat |which |type )' && ! echo "$cmd" | grep -qE '[;&|]'; then
    GUARD_CLASS="Safe"
    return
  fi

  # その他のBashコマンドはBoundary扱い
  GUARD_CLASS="Boundary"
  MESSAGE="🔶 protection-mode:要確認操作 - Bashコマンド"
}

# ====================================
# protection-mode 3層分類判定
# ====================================

case "$TOOL_NAME" in
  # === 安全操作（即実行可能） ===
  "Read"|"Glob"|"Grep"|"WebFetch"|"WebSearch"|"ListMcpResourcesTool"|"ReadMcpResourceTool")
    GUARD_CLASS="Safe"
    # 安全操作はメッセージなし（トークン節約）
    ;;

  "mcp__serena__read_file"|"mcp__serena__list_dir"|"mcp__serena__find_file"|"mcp__serena__search_for_pattern"|"mcp__serena__get_symbols_overview"|"mcp__serena__find_symbol"|"mcp__serena__find_referencing_symbols"|"mcp__serena__list_memories"|"mcp__serena__read_memory"|"mcp__serena__check_onboarding_performed"|"mcp__serena__get_current_config"|"mcp__serena__think_about_collected_information"|"mcp__serena__think_about_task_adherence"|"mcp__serena__think_about_whether_you_are_done")
    GUARD_CLASS="Safe"
    ;;

  "mcp__jira__jira_get"|"mcp__confluence__conf_get"|"mcp__context7__resolve-library-id"|"mcp__context7__query-docs")
    GUARD_CLASS="Safe"
    ;;

  # === 要確認操作（要確認・警告） ===
  "Edit"|"Write"|"MultiEdit")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: ファイル編集"
    # additionalContext省略（トークン節約）
    ;;

  "Bash")
    COMMAND=$(jq -r '.command // empty' <<< "$TOOL_INPUT")
    classify_bash_command "$COMMAND"
    ;;

  "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_content"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol"|"mcp__serena__write_memory"|"mcp__serena__delete_memory"|"mcp__serena__execute_shell_command"|"mcp__serena__rename_symbol")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: Serena変更操作"
    ;;

  "mcp__jira__jira_post"|"mcp__jira__jira_put"|"mcp__jira__jira_patch"|"mcp__jira__jira_delete"|"mcp__confluence__conf_post"|"mcp__confluence__conf_put"|"mcp__confluence__conf_patch"|"mcp__confluence__conf_delete")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: Jira/Confluence変更"
    ;;

  "Task")
    GUARD_CLASS="Safe"
    # エージェント起動はSafe（実際の操作は各エージェント内で判定）
    ;;

  "Skill")
    GUARD_CLASS="Safe"

    # ガイドラインは各スキル内で自動読み込み（additionalContext省略でトークン節約）
    ;;

  "TaskCreate"|"TaskUpdate"|"TaskList"|"TaskGet"|"AskUserQuestion"|"EnterPlanMode"|"ExitPlanMode")
    GUARD_CLASS="Safe"
    ;;

  *)
    # 未知のツールはBoundary扱い
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:要確認操作 - 未分類ツール: $TOOL_NAME"
    ;;
esac

# ====================================
# JSON出力（jqで安全にエスケープ）
# ====================================

if [ -n "$ADDITIONAL_CONTEXT" ]; then
  jq -n --arg msg "$MESSAGE" --arg ctx "$ADDITIONAL_CONTEXT" \
    '{"systemMessage": $msg, "additionalContext": $ctx}'
elif [ -n "$MESSAGE" ]; then
  jq -n --arg msg "$MESSAGE" \
    '{"systemMessage": $msg}'
else
  # 安全操作はメッセージなし（トークン節約）
  echo "{}"
fi
