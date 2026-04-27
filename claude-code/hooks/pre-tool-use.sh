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

# ツール名を取得
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")

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
  # grep外部プロセスを bash [[ =~ ]] に置換して高速化（v2.2.1）
  # /dev/null へのリダイレクトは安全、それ以外の /dev/ は禁止
  local _dev_forbidden=0
  if [[ "$cmd" =~ [0-9]*\>[[:space:]]*/dev/ ]] && ! [[ "$cmd" =~ [0-9]*\>[[:space:]]*/dev/null ]]; then
    _dev_forbidden=1
  fi
  if [[ "$_dev_forbidden" -eq 1 ]] || [[ "$cmd" =~ (rm[[:space:]]+-rf[[:space:]]+/|rm[[:space:]]+-rf[[:space:]]+\*|:\(\)\{|sudo[[:space:]]+rm|git[[:space:]]+push[[:space:]]+--force|git[[:space:]]+push[[:space:]]+-f) ]]; then
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} 禁止: 危険なコマンド検出"
    ADDITIONAL_CONTEXT="破壊的コマンド検出。実行を中止し安全な代替手段を提案"
    return
  fi

  # 自動処理禁止チェック
  if [[ "$cmd" =~ (npm[[:space:]]run[[:space:]]lint|prettier|eslint[[:space:]]--fix|go[[:space:]]fmt|autopep8|black[[:space:]]) ]]; then
    GUARD_CLASS="Boundary"
    MESSAGE="${ICON_WARNING} 要確認: 自動整形"
    return
  fi

  # 変更系コマンド
  if [[ "$cmd" =~ (git[[:space:]]commit|git[[:space:]]push|git[[:space:]]merge|git[[:space:]]rebase|npm[[:space:]]install|pip[[:space:]]install|go[[:space:]]mod|docker[[:space:]]build|docker[[:space:]]push) ]]; then
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: 変更系コマンド"
    return
  fi

  # 読み取り系コマンド（チェーン・パイプを含まない単純コマンドのみ）
  if [[ "$cmd" =~ ^(git[[:space:]](status|log|diff|branch)|ls[[:space:]]|pwd$|echo[[:space:]]|cat[[:space:]]|which[[:space:]]|type[[:space:]]) ]] && ! [[ "$cmd" =~ [\;\&\|] ]]; then
    GUARD_CLASS="Safe"
    return
  fi

  # その他のBashコマンドはBoundary扱い
  GUARD_CLASS="Boundary"
  MESSAGE="🔶 要確認: Bashコマンド"
}

# ====================================
# Edit/Write 内容の危険パターン検出
# security-guidance plugin（eval/exec 系）と相補的：
# クラウドメタデータSSRF・SQL文字列連結・機密情報リテラルを検出
# 機密リテラル系は Forbidden に昇格してブロック
# ====================================
detect_dangerous_patterns() {
  local content="$1"
  local detected=()
  local has_secret=0

  # 機密情報リテラル（Forbidden 昇格対象）
  if printf '%s' "$content" | grep -qE 'AKIA[A-Z0-9]{16}'; then
    detected+=("AWS Access Key literal")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE 'ghp_[A-Za-z0-9]{36}'; then
    detected+=("GitHub PAT literal")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE 'sk-[A-Za-z0-9]{40,}'; then
    detected+=("API key literal (sk-...)")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE 'xox[bp]-[A-Za-z0-9-]{20,}'; then
    detected+=("Slack token literal")
    has_secret=1
  fi
  if printf '%s' "$content" | grep -qE -- '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'; then
    detected+=("Private key literal")
    has_secret=1
  fi

  # SSRF クラウドメタデータ（Boundary 警告）
  if printf '%s' "$content" | grep -qE '(169\.254\.169\.254|metadata\.google\.internal|100\.100\.100\.200)'; then
    detected+=("SSRF cloud metadata access")
  fi

  # SQL 文字列連結（Boundary 警告）
  if printf '%s' "$content" | grep -qE '(f"|f'\''|`)(SELECT|INSERT|UPDATE|DELETE)[[:space:]].*\{[^}]+\}'; then
    detected+=("SQL string interpolation (f-string/template)")
  elif printf '%s' "$content" | grep -qE '(SELECT|INSERT|UPDATE|DELETE)[[:space:]].*\$\{[^}]+\}'; then
    detected+=("SQL template literal injection")
  fi

  # 一般的な password ハードコード
  if printf '%s' "$content" | grep -qE '(api_key|password|secret|access_token|auth_token)[[:space:]]*[=:][[:space:]]*['\''"][a-zA-Z0-9_/+=-]{20,}'; then
    detected+=("Hardcoded credential assignment")
  fi

  if [ ${#detected[@]} -eq 0 ]; then
    return
  fi

  local joined
  joined=$(IFS='; '; echo "${detected[*]}")

  if [ "$has_secret" -eq 1 ]; then
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL} 機密情報リテラル検出: ${joined}"
    ADDITIONAL_CONTEXT="ハードコードされた認証情報を検出。環境変数 or secret manager を使用すること。コミット前に履歴からも除去要"
  else
    MESSAGE="${ICON_WARNING} 危険パターン: ${joined}"
    ADDITIONAL_CONTEXT="security-guidance plugin と相補検出。SSRFはホワイトリスト・SQLはプレースホルダで防ぐ"
  fi
}

# ====================================
# protection-mode 3層分類判定
# ====================================

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
    # 危険パターン検出（機密リテラル/SSRF/SQL injection）
    EDIT_CONTENT=$(jq -r '
      if .tool_input.content then .tool_input.content
      elif .tool_input.new_string then .tool_input.new_string
      elif .tool_input.edits then [.tool_input.edits[].new_string] | join("\n")
      else "" end
    ' <<< "$INPUT")
    if [ -n "$EDIT_CONTENT" ]; then
      detect_dangerous_patterns "$EDIT_CONTENT"
    fi
    ;;

  "Bash")
    COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
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
    MESSAGE="🔶 要確認: 未分類ツール: $TOOL_NAME"
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

# Forbiddenの場合はexit 2でツール実行をブロック（v2.1.90で正常動作）
if [ "$GUARD_CLASS" = "Forbidden" ]; then
  exit 2
fi
