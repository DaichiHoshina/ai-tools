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

    # code comment 規範 inject: serena 編集系 (content / body / repl param) も Write/Edit と同様に検査
    case "$TOOL_NAME" in
      "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_content"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol")
        _SERENA_NEW_CONTENT=$(jq -r '[.tool_input.content // empty, .tool_input.body // empty, .tool_input.repl // empty] | join("\n")' <<< "$INPUT")
        _inject_code_comment_rules "$_SERENA_PATH" "$_SERENA_NEW_CONTENT"
        ;;
    esac
    ;;

  "mcp__jira__jira_post"|"mcp__jira__jira_put"|"mcp__jira__jira_patch"|"mcp__jira__jira_delete"|"mcp__confluence__conf_post"|"mcp__confluence__conf_put"|"mcp__confluence__conf_patch"|"mcp__confluence__conf_delete")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: Jira/Confluence変更"
    ;;

  "mcp__claude_ai_Notion__notion-create-pages"|"mcp__claude_ai_Notion__notion-update-page"|"mcp__claude_ai_Notion__notion-create-comment"|"mcp__claude_ai_Notion__notion-create-database" \
  |"mcp__claude_ai_Slack__slack_send_message"|"mcp__claude_ai_Slack__slack_schedule_message"|"mcp__claude_ai_Slack__slack_create_canvas"|"mcp__claude_ai_Slack__slack_update_canvas")
    # 対象: 文章を外向きに送信・投稿・作成する MCP
    # 除外 (構造操作で文章を書かない):
    #   notion-duplicate-page / notion-move-pages / notion-update-view / notion-update-data-source
    #   slack_add_reaction
    GUARD_CLASS="Safe"
    ADDITIONAL_CONTEXT="📝 投稿前自問5点: ①「で、つまり何？」と思わせないか ②初見が途中で止まらないか ③各段落の役割（背景/理由/具体例/結論/注意点）明確か ④抽象名詞の羅列で段落が終わってないか ⑤bullet 5連続+地の文0の金太郎飴か。詳細: claude-code/guidelines/writing/PRINCIPLES.md"

    # AI定型語チェック: text / content param + nested field を全連結して block
    # Notion children: paragraph/heading/bulleted_list_item/numbered_list_item の rich_text[].text.content
    # Slack blocks: blocks[].text.text
    _mcp_text=$(jq -r '
      [
        (.tool_input.text // empty),
        (.tool_input.content // empty),
        (.tool_input.children[]?
          | (.paragraph?.rich_text[]?.text?.content // empty),
            (.heading_1?.rich_text[]?.text?.content // empty),
            (.heading_2?.rich_text[]?.text?.content // empty),
            (.heading_3?.rich_text[]?.text?.content // empty),
            (.bulleted_list_item?.rich_text[]?.text?.content // empty),
            (.numbered_list_item?.rich_text[]?.text?.content // empty),
            (.quote?.rich_text[]?.text?.content // empty),
            (.callout?.rich_text[]?.text?.content // empty),
            (.toggle?.rich_text[]?.text?.content // empty)
        ),
        (.tool_input.blocks[]?.text?.text // empty)
      ] | map(select(. != null and . != "")) | join("\n")
    ' <<< "$INPUT")
    if [[ -n "$_mcp_text" ]]; then
      _block_if_ai_jargon "$_mcp_text" "$TOOL_NAME"
    fi

    # 書く系 MCP: NG-DICTIONARY pre-sweep + 今日の commit inject
    # (2026-06-25 V 改善: MCP Notion/Slack でも commit 系と同様に起草前 NG list を inject、
    #  retrospective 2026-06-24 で「単日 30+ 件 block、同じ語 leverage / 踏襲 / utilize が repeat」
    #  の root cause = MCP 分岐に commit_compose inject が配線されていなかったため対応)
    _inject_ng_dict_on_commit_compose
    _inject_today_commits
    ;;

  "Task"|"Agent")
    # Claude Code 2.1.152+ で Task tool は Agent に rename された (両 name で発火)
    # hook が "Task" のみ listen していた間 bundle-violation 検出が全 session で空振りしていた
    GUARD_CLASS="Safe"
    # エージェント起動はSafe（実際の操作は各エージェント内で判定）
    # ただし general-purpose は CLAUDE.md「絶対禁止」最大コスト源 → hard block (GP_BLOCK_OFF=1 で warn に緩和)
    SUBAGENT_TYPE=$(jq -r '.tool_input.subagent_type // empty' <<< "$INPUT")

    # 並列判定 self-review (session 1 回のみ inject、同一 session 内の Task 連発による重複を抑制)
    PARALLEL_REVIEW=""
    _PR_NL=""
    _PR_TODAY=""; printf -v _PR_TODAY '%(%Y%m%d)T' -1
    _PARALLEL_REVIEW_FLAG="/tmp/claude-parallel-review-$(_stable_session_key)-${_PR_TODAY}"
    if [[ ! -f "${_PARALLEL_REVIEW_FLAG}" ]]; then
      PARALLEL_REVIEW=$'【並列 self-review (強制 echo、default=並列/委譲)】\n0. default: 並列発火 + Sonnet 委譲。単発・inline 選択時は「なぜ並列/委譲しないか」を 1 行 echo。迷ったら並列・委譲側\n1. Manager 経由は formula_trace、直接 Task は judgment 行を echo (書式: references/PARALLEL-PATTERNS.md)\n2. 独立 task ≥2 なら 1 message に N 個 Agent を並べる (逐次発火だと peak=1)\n3. echo 抜けは under-parallel risk'
      _PR_NL=$'\n'
      touch "${_PARALLEL_REVIEW_FLAG}" 2>/dev/null || true
    fi

    # parent 事前準備 missing 検出 (warn-only、block しない)
    TASK_PROMPT=$(jq -r '.tool_input.prompt // empty' <<< "$INPUT")

    # developer-agent fire 時、prompt §1 touchable_files YAML から allowlist 抽出 →
    # state file に write。subagent 内 Edit/Write の literal match check に使う。
    if [ "${SUBAGENT_TYPE}" = "developer-agent" ] && [ -n "$TASK_PROMPT" ]; then
      _TF_LIST=$(_touchable_extract_from_prompt "$TASK_PROMPT")
      if [ -n "$_TF_LIST" ]; then
        # mapfile alternative for old bash: read into array
        _TF_PATHS=()
        while IFS= read -r _line; do
          [ -n "$_line" ] && _TF_PATHS+=("$_line")
        done <<< "$_TF_LIST"
        _touchable_write "$SESSION_ID" "${_TF_PATHS[@]}"
      fi
    fi

    PREP_WARN=""
    if _check_parent_prep_missing "$TASK_PROMPT"; then
      PREP_WARN="
【parent 事前準備 missing 疑い】≥500 word の prompt に target / file:line / verify / DoD いずれも未出現。委譲前 checklist を充足してから発火 (references/developer-agent-delegation-prompt.md §0)"
    fi
    if _check_colloquial_trigger_missing_delegation "$TASK_PROMPT"; then
      PREP_WARN="${PREP_WARN}
【colloquial 起動検出】口語トリガー (お任せ/全部/改善して 等) + file:line 未明示。inline throttle に注意、複数 task 列挙なら 1 message 内 N tool_use 並列発火を確認"
    fi

    if [ "${SUBAGENT_TYPE}" = "general-purpose" ]; then
      # CLAUDE.md「absolutely banned」最大コスト源 (実測 max 501s) → hard block。
      # GP_BLOCK_OFF=1 で従来の warn 据え置き (hook debug 用 escape hatch)。
      if [ "${GP_BLOCK_OFF:-0}" = "1" ]; then
        GUARD_CLASS="Boundary"
        MESSAGE="${ICON_WARNING} general-purpose agent（CLAUDE.md「原則使わない」、最大コスト源）"
        ADDITIONAL_CONTEXT="代替: claude-code-guide / Explore / 直接 grep+find / serena MCP（references/performance-insights.md 参照）${_PR_NL}${PARALLEL_REVIEW}${PREP_WARN}"
      else
        GUARD_CLASS="Forbidden"
        MESSAGE="${ICON_CRITICAL} general-purpose agent は禁止 (CLAUDE.md、最大コスト源 実測 max 501s)。代替: explore-agent (検索) / claude-code-guide (CLI/SDK) / developer-agent (実装)"
      fi
    elif [ -z "${SUBAGENT_TYPE}" ]; then
      # subagent_type 未指定は general-purpose bypass と同等 → hard block。
      # SUBTYPE_EMPTY_BLOCK_OFF=1 で warn-only に降格 (hook debug 用 escape hatch)。
      if [ "${SUBTYPE_EMPTY_BLOCK_OFF:-0}" = "1" ]; then
        GUARD_CLASS="Boundary"
        MESSAGE="${ICON_WARNING} subagent_type 未指定の Task (CLAUDE.md「subagent_type must be explicit」)"
        ADDITIONAL_CONTEXT="代替: explore-agent (検索) / claude-code-guide (CLI/SDK) / developer-agent (実装)${_PR_NL}${PARALLEL_REVIEW}${PREP_WARN}"
      else
        GUARD_CLASS="Forbidden"
        MESSAGE="${ICON_CRITICAL} subagent_type 未指定の Task は禁止 (CLAUDE.md「subagent_type must be explicit on every Task call」)。代替: explore-agent (検索) / claude-code-guide (CLI/SDK) / developer-agent (実装)"
      fi
    else
      ADDITIONAL_CONTEXT="${PARALLEL_REVIEW}${PREP_WARN}"
    fi

    # 逐次 Agent fire 検出 (warn-only、既存 ADDITIONAL_CONTEXT に append)
    _check_sequential_agent_fire "$SESSION_ID"

    # bundle 違反検出 (warn-only): developer-agent 限定で逐次発火を検出
    # work-context-20260618 next-action #1 / Gate A 衰弱点補強
    # /flow step 7 では Task(developer-agent)×N を 1 message bundle 必須
    # 連続発火 (>_TH_PARALLEL_WINDOW_NS) ≥2 回 = bundle 違反 = parentUuid serial chain
    # prompt を渡して serial_reason: 宣言 (依存 chain の逐次発火) を counter 対象外にする
    if [ "${SUBAGENT_TYPE}" = "developer-agent" ]; then
      _check_developer_agent_bundle_violation "$SESSION_ID" "$TASK_PROMPT"
    fi
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
