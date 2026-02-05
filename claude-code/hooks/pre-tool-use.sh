#!/usr/bin/env bash
# PreToolUse Hook - protection-mode（圏論的思考法）必須チェック
# 10原則: protection-mode判定、自動処理禁止、確認済
# v2.1.9対応: additionalContext でモデルに追加コンテキストを提供

set -euo pipefail

# JSON入力を読み込む
INPUT=$(cat)

# ツール名とパラメータを取得
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')

# protection-mode判定変数
KENRON_CLASS=""  # Safe, Boundary, Forbidden
MESSAGE=""
ADDITIONAL_CONTEXT=""

# ====================================
# protection-mode 3層分類判定
# ====================================

case "$TOOL_NAME" in
  # === Safe射（即実行可能） ===
  "Read"|"Glob"|"Grep"|"WebFetch"|"WebSearch"|"ListMcpResourcesTool"|"ReadMcpResourceTool")
    KENRON_CLASS="Safe"
    # Safe射はメッセージなし（トークン節約）
    ;;

  "mcp__serena__read_file"|"mcp__serena__list_dir"|"mcp__serena__find_file"|"mcp__serena__search_for_pattern"|"mcp__serena__get_symbols_overview"|"mcp__serena__find_symbol"|"mcp__serena__find_referencing_symbols"|"mcp__serena__list_memories"|"mcp__serena__read_memory"|"mcp__serena__check_onboarding_performed"|"mcp__serena__get_current_config"|"mcp__serena__think_about_collected_information"|"mcp__serena__think_about_task_adherence"|"mcp__serena__think_about_whether_you_are_done")
    KENRON_CLASS="Safe"
    ;;

  "mcp__jira__jira_get"|"mcp__confluence__conf_get"|"mcp__context7__resolve-library-id"|"mcp__context7__query-docs")
    KENRON_CLASS="Safe"
    ;;

  # === Boundary射（要確認・警告） ===
  "Edit"|"Write"|"MultiEdit")
    KENRON_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:Boundary射 - ファイル編集"
    ADDITIONAL_CONTEXT="【protection-mode判定】Boundary射（要確認）\\n- 操作: ファイル編集\\n- 確認: 型安全性（any/as禁止）、ガイドライン準拠"
    ;;

  "Bash")
    COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
    
    # Forbidden射チェック（危険なコマンド）
    if echo "$COMMAND" | grep -qE '(rm -rf /|rm -rf \*|> /dev/|:(){:|sudo rm|git push --force|git push -f)'; then
      KENRON_CLASS="Forbidden"
      MESSAGE="🔴 protection-mode:Forbidden射 - 危険なコマンド検出！実行禁止"
      ADDITIONAL_CONTEXT="【protection-mode判定】Forbidden射（実行禁止）\\n- 検出: 破壊的コマンド\\n- 対応: 実行を中止し、安全な代替手段を提案"
    # 自動処理禁止チェック
    elif echo "$COMMAND" | grep -qE '(npm run lint|prettier|eslint --fix|go fmt|autopep8|black )'; then
      KENRON_CLASS="Boundary"
      MESSAGE="🔶 protection-mode:Boundary射 - 自動整形（10原則:自動処理禁止）"
      ADDITIONAL_CONTEXT="【protection-mode判定】Boundary射（要確認）\\n- 操作: 自動整形\\n- 10原則: 自動処理禁止 - ユーザー確認必須"
    # 変更系コマンド
    elif echo "$COMMAND" | grep -qE '(git commit|git push|git merge|git rebase|npm install|pip install|go mod|docker build|docker push)'; then
      KENRON_CLASS="Boundary"
      MESSAGE="🔶 protection-mode:Boundary射 - 変更系コマンド"
      ADDITIONAL_CONTEXT="【protection-mode判定】Boundary射（要確認）\\n- 操作: $(echo "$COMMAND" | head -c 50)...\\n- 確認: 実行前にユーザー承認を推奨"
    # 読み取り系コマンド
    elif echo "$COMMAND" | grep -qE '^(git status|git log|git diff|git branch|ls |pwd|echo |cat |which |type )'; then
      KENRON_CLASS="Safe"
    else
      # その他のBashコマンドはBoundary扱い
      KENRON_CLASS="Boundary"
      MESSAGE="🔶 protection-mode:Boundary射 - Bashコマンド"
    fi
    ;;

  "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol"|"mcp__serena__write_memory"|"mcp__serena__delete_memory"|"mcp__serena__execute_shell_command")
    KENRON_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:Boundary射 - Serena MCP変更操作"
    ADDITIONAL_CONTEXT="【protection-mode判定】Boundary射（要確認）\\n- 操作: Serena MCP変更\\n- 確認: 重要な変更後はmemory更新を検討"
    ;;

  "mcp__jira__jira_post"|"mcp__jira__jira_put"|"mcp__jira__jira_patch"|"mcp__jira__jira_delete"|"mcp__confluence__conf_post"|"mcp__confluence__conf_put"|"mcp__confluence__conf_patch"|"mcp__confluence__conf_delete")
    KENRON_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:Boundary射 - 外部サービス変更"
    ADDITIONAL_CONTEXT="【protection-mode判定】Boundary射（要確認）\\n- 操作: Jira/Confluence変更\\n- 確認: 外部サービスへの書き込み操作"
    ;;

  "Task")
    KENRON_CLASS="Safe"
    # エージェント起動はSafe（実際の操作は各エージェント内で判定）
    ;;

  "Skill")
    KENRON_CLASS="Safe"

    # スキル名を取得
    SKILL_NAME=$(echo "$TOOL_INPUT" | jq -r '.skill // empty')

    # セッション状態ファイルのパス
    SESSION_STATE_FILE="$HOME/.claude/session-state.json"

    # ガイドライン自動読み込み判定（pre-skill-use.sh機能統合）
    case "$SKILL_NAME" in
      "go-backend")
        ADDITIONAL_CONTEXT="【スキル実行】$SKILL_NAME\\n- 推奨ガイドライン: Go言語ベストプラクティス\\n- 未読み込みの場合は自動的に読み込みます"
        ;;
      "typescript-backend"|"react-best-practices"|"ui-skills")
        ADDITIONAL_CONTEXT="【スキル実行】$SKILL_NAME\\n- 推奨ガイドライン: TypeScript/React ベストプラクティス\\n- 未読み込みの場合は自動的に読み込みます"
        ;;
      "dockerfile-best-practices"|"kubernetes"|"terraform")
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
    KENRON_CLASS="Safe"
    ;;

  *)
    # 未知のツールはBoundary扱い
    KENRON_CLASS="Boundary"
    MESSAGE="🔶 protection-mode:Boundary射 - 未分類ツール: $TOOL_NAME"
    ;;
esac

# ====================================
# JSON出力
# ====================================

if [ -n "$MESSAGE" ] && [ -n "$ADDITIONAL_CONTEXT" ]; then
  jq -n \
    --arg sm "$MESSAGE" \
    --arg ac "$ADDITIONAL_CONTEXT" \
    '{systemMessage: $sm, additionalContext: $ac}'
elif [ -n "$MESSAGE" ]; then
  jq -n \
    --arg sm "$MESSAGE" \
    '{systemMessage: $sm}'
elif [ -n "$ADDITIONAL_CONTEXT" ]; then
  jq -n \
    --arg ac "$ADDITIONAL_CONTEXT" \
    '{additionalContext: $ac}'
else
  # Safe射はメッセージなし（トークン節約）
  echo "{}"
fi
