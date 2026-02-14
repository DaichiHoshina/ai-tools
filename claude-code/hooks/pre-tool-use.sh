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
    MESSAGE="${ICON_WARNING} protection-mode:要確認操作 - 自動整形（10原則:自動処理禁止）"
    ADDITIONAL_CONTEXT="【protection-mode判定】要確認操作（要確認）\\n- 操作: 自動整形\\n- 10原則: 自動処理禁止 - ユーザー確認必須"
    return
  fi

  # 変更系コマンド
  if echo "$cmd" | grep -qE '(git commit|git push|git merge|git rebase|npm install|pip install|go mod|docker build|docker push)'; then
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:要確認操作 - 変更系コマンド"
    # コマンドプレビューからJSON unsafe文字を除去
    local cmd_preview
    cmd_preview=$(echo "$cmd" | tr -d '"\\' | head -c 50)
    ADDITIONAL_CONTEXT="【protection-mode判定】要確認操作（要確認）\\n- 操作: ${cmd_preview}...\\n- 確認: 実行前にユーザー承認を推奨"
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
    MESSAGE="🔶 protection-mode:要確認操作 - ファイル編集"
    ADDITIONAL_CONTEXT="【protection-mode判定】要確認操作（要確認）\\n- 操作: ファイル編集\\n- 確認: 型安全性（any/as禁止）、ガイドライン準拠"
    ;;

  "Bash")
    COMMAND=$(jq -r '.command // empty' <<< "$TOOL_INPUT")
    classify_bash_command "$COMMAND"
    ;;

  "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_content"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol"|"mcp__serena__write_memory"|"mcp__serena__delete_memory"|"mcp__serena__execute_shell_command"|"mcp__serena__rename_symbol")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:要確認操作 - Serena MCP変更操作"
    ADDITIONAL_CONTEXT="【protection-mode判定】要確認操作（要確認）\\n- 操作: Serena MCP変更\\n- 確認: 重要な変更後はmemory更新を検討"
    ;;

  "mcp__jira__jira_post"|"mcp__jira__jira_put"|"mcp__jira__jira_patch"|"mcp__jira__jira_delete"|"mcp__confluence__conf_post"|"mcp__confluence__conf_put"|"mcp__confluence__conf_patch"|"mcp__confluence__conf_delete")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:要確認操作 - 外部サービス変更"
    ADDITIONAL_CONTEXT="【protection-mode判定】要確認操作（要確認）\\n- 操作: Jira/Confluence変更\\n- 確認: 外部サービスへの書き込み操作"
    ;;

  "Task")
    GUARD_CLASS="Safe"
    # エージェント起動はSafe（実際の操作は各エージェント内で判定）
    ;;

  "Skill")
    GUARD_CLASS="Safe"

    # スキル名を取得
    SKILL_NAME=$(echo "$TOOL_INPUT" | jq -r '.skill // empty')

    # セッション状態ファイルのパス
    SESSION_STATE_FILE="$HOME/.claude/session-state.json"

    # ガイドライン自動読み込み判定（pre-skill-use.sh機能統合）
    case "$SKILL_NAME" in
      "backend-dev")
        ADDITIONAL_CONTEXT="【スキル実行】$SKILL_NAME\\n- 推奨ガイドライン: Backend開発ベストプラクティス\\n- 未読み込みの場合は自動的に読み込みます"
        ;;
      "react-best-practices"|"ui-skills")
        ADDITIONAL_CONTEXT="【スキル実行】$SKILL_NAME\\n- 推奨ガイドライン: TypeScript/React ベストプラクティス\\n- 未読み込みの場合は自動的に読み込みます"
        ;;
      "container-ops"|"terraform")
        ADDITIONAL_CONTEXT="【スキル実行】$SKILL_NAME\\n- 推奨ガイドライン: インフラストラクチャ設計\\n- 未読み込みの場合は自動的に読み込みます"
        ;;
      "clean-architecture-ddd"|"api-design"|"microservices-monorepo")
        ADDITIONAL_CONTEXT="【スキル実行】$SKILL_NAME\\n- 推奨ガイドライン: アーキテクチャ設計\\n- 未読み込みの場合は自動的に読み込みます"
        ;;
      *)
        # その他のスキルは通常処理
        ;;
    esac
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
