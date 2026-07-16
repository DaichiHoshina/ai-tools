#!/usr/bin/env bash
# Task/Agent tool checkers (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_TASK_AGENT_CHECKERS_LOADED:-}" == "1" ]]; then
    return 0
fi
_TASK_AGENT_CHECKERS_LOADED=1

# shellcheck source=thresholds.sh
source "${BASH_SOURCE[0]%/*}/thresholds.sh"

# ====================================
# Task/Agent tool 分岐ハンドラ (pre-tool-use.sh "Task"|"Agent" case から切り出し)
# Claude Code 2.1.152+ で Task tool は Agent に rename された (両 name で発火)
# 引数: INPUT (stdin JSON) / TOOL_NAME / SESSION_ID
# GUARD_CLASS / MESSAGE / ADDITIONAL_CONTEXT はグローバル変数として設定する
# ====================================
_handle_task_agent_tool() {
  local INPUT="$1"
  local TOOL_NAME="$2"
  local SESSION_ID="$3"

  GUARD_CLASS="Safe"
  # エージェント起動はSafe（実際の操作は各エージェント内で判定）
  # ただし general-purpose は CLAUDE.md「絶対禁止」最大コスト源 → hard block (GP_BLOCK_OFF=1 で warn に緩和)
  local SUBAGENT_TYPE
  SUBAGENT_TYPE=$(jq -r '.tool_input.subagent_type // empty' <<< "$INPUT")

  # 並列判定 self-review (session 1 回のみ inject、同一 session 内の Task 連発による重複を抑制)
  local PARALLEL_REVIEW=""
  local _PR_NL=""
  local _PR_TODAY=""; printf -v _PR_TODAY '%(%Y%m%d)T' -1
  local _PARALLEL_REVIEW_FLAG="/tmp/claude-parallel-review-$(_stable_session_key)-${_PR_TODAY}"
  if [[ ! -f "${_PARALLEL_REVIEW_FLAG}" ]]; then
    PARALLEL_REVIEW=$'【並列 self-review (強制 echo、default=並列/委譲)】\n0. default: 並列発火 + Sonnet 委譲。単発・inline 選択時は「なぜ並列/委譲しないか」を 1 行 echo。迷ったら並列・委譲側\n1. Manager 経由は formula_trace、直接 Task は judgment 行を echo (書式: references/PARALLEL-PATTERNS.md)\n2. 独立 task ≥2 なら 1 message に N 個 Agent を並べる (逐次発火だと peak=1)\n3. echo 抜けは under-parallel risk'
    _PR_NL=$'\n'
    touch "${_PARALLEL_REVIEW_FLAG}" 2>/dev/null || true
  fi

  # parent 事前準備 missing 検出 (warn-only、block しない)
  local TASK_PROMPT
  TASK_PROMPT=$(jq -r '.tool_input.prompt // empty' <<< "$INPUT")

  # developer-agent fire 時、prompt §1 touchable_files YAML から allowlist 抽出 →
  # state file に write。subagent 内 Edit/Write の literal match check に使う。
  if [ "${SUBAGENT_TYPE}" = "developer-agent" ] && [ -n "$TASK_PROMPT" ]; then
    local _TF_LIST
    _TF_LIST=$(_touchable_extract_from_prompt "$TASK_PROMPT")
    if [ -n "$_TF_LIST" ]; then
      # mapfile alternative for old bash: read into array
      local _TF_PATHS=()
      local _line
      while IFS= read -r _line; do
        [ -n "$_line" ] && _TF_PATHS+=("$_line")
      done <<< "$_TF_LIST"
      _touchable_write "$SESSION_ID" "${_TF_PATHS[@]}"
    fi
  fi

  local PREP_WARN=""
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
}
