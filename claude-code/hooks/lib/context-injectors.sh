#!/usr/bin/env bash
# context injectors (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_CONTEXT_INJECTORS_LOADED:-}" == "1" ]]; then
    return 0
fi
_CONTEXT_INJECTORS_LOADED=1

# ====================================
# 今日の commit inject
# 書く系 tool (Write/Edit/Bash commit・gh・glab・Slack/Notion MCP) の直前に
# 今日の commit log を additionalContext に append して、最新規範の反映を促す
# session 重複抑制: /tmp/claude-today-commits-<SESSION_KEY>-<YYYYMMDD> に記録済フラグ
# ====================================
_inject_today_commits() {
  local _inject_log_dir="$HOME/.claude/logs"
  local _inject_log_file="${_inject_log_dir}/today-commit-inject.log"

  # session 重複抑制: stdin .session_id ベース (CLAUDE_CODE_SESSION_ID env 優先)
  # session_id が取得できた場合はそれを使用 (session 単位で確実に重複抑制)
  # 取得できない場合は $$ fallback (毎 hook 起動別PIDで重複抑制は機能しないが inject 自体は行う)
  local _session_key="${SESSION_ID:-$$}"
  local _today; printf -v _today '%(%Y%m%d)T' -1
  local _flag_file="/tmp/claude-today-commits-${_session_key}-${_today}"
  if [[ -f "$_flag_file" ]]; then
    return 0
  fi

  # cap: 行数上限 (env override 可)
  local _line_cap="${CLAUDE_HOOK_INJECT_CAP:-30}"
  # cap: commit 数上限 (env override 可)
  local _commit_cap="${CLAUDE_HOOK_INJECT_COMMIT_CAP:-5}"

  # git log: CLAUDE_PROJECT_DIR 優先、なければ HOME
  local _project_dir="${CLAUDE_PROJECT_DIR:-$HOME}"

  # Source 1: 作業中 repo の今日の commit
  local _proj_commits=""
  _proj_commits=$(git -C "$_project_dir" log --since="midnight" --pretty=format:'%h %s' --no-merges 2>/dev/null | head -n "${_commit_cap}" || true)
  # 非 git repo は silent skip (log 書かない、975 行 noise を防ぐ)。
  # debug 用に git repo だが today commit 0 件の case のみ log する場合は
  # CLAUDE_HOOK_INJECT_LOG_EMPTY=1 を設定する。
  if [[ -z "$_proj_commits" ]] && [[ "${CLAUDE_HOOK_INJECT_LOG_EMPTY:-0}" == "1" ]] \
      && git -C "$_project_dir" rev-parse --git-dir >/dev/null 2>&1; then
    mkdir -p "$_inject_log_dir" 2>/dev/null || true
    printf '[%s] today-commit inject: no commits today at %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$_project_dir" >> "$_inject_log_file" 2>/dev/null || true
  fi

  # Source 2: ai-tools writing 規約関連 commit (guidelines/ と CLAUDE.md 限定)
  # _project_dir が ~/ai-tools の時は重複しないよう skip
  local _aitools_repo_dir
  _aitools_repo_dir="$(_aitools_dir)"
  local _writing_commits=""
  local _aitools_real
  _aitools_real=$(cd "$_aitools_repo_dir" 2>/dev/null && pwd -P 2>/dev/null || echo "")
  local _project_real
  _project_real=$(cd "$_project_dir" 2>/dev/null && pwd -P 2>/dev/null || echo "")
  if [[ -n "$_aitools_real" && "$_aitools_real" != "$_project_real" ]]; then
    _writing_commits=$(git -C "$_aitools_repo_dir" log --since="midnight" --pretty=format:'%h %s' --no-merges \
      -- "claude-code/guidelines/" "claude-code/CLAUDE.global.md" 2>/dev/null | head -n "${_commit_cap}" || true)
    # 非 git repo は silent skip (上の Source 1 と同方針)。
    if [[ -z "$_writing_commits" ]] && [[ "${CLAUDE_HOOK_INJECT_LOG_EMPTY:-0}" == "1" ]] \
        && git -C "$_aitools_repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
      mkdir -p "$_inject_log_dir" 2>/dev/null || true
      printf '[%s] today-commit inject: no commits today at %s (writing path)\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$_aitools_repo_dir" >> "$_inject_log_file" 2>/dev/null || true
    fi
  fi

  # 両方 0 件 → silent skip (フラグも書かない)
  if [[ -z "$_proj_commits" && -z "$_writing_commits" ]]; then
    return 0
  fi

  # フラグ書き込み (以降は重複 inject しない)
  touch "$_flag_file" 2>/dev/null || true

  local _msg=""

  if [[ -n "$_proj_commits" ]]; then
    _msg="今日の commit: ${_proj_commits}"$'\n'"writing 規約 / guidelines / CLAUDE.md 更新が含まれる場合、出力前に当該 file を read して最新規範を反映すること。"
  fi

  if [[ -n "$_writing_commits" ]]; then
    local _writing_msg="writing 規約 (~/ai-tools) の今日更新: ${_writing_commits}"$'\n'"これらを read してから書く。"
    if [[ -n "$_msg" ]]; then
      _msg="${_msg}"$'\n'"${_writing_msg}"
    else
      _msg="${_writing_msg}"
    fi
  fi

  # 行数 cap 適用: _line_cap を超える場合は truncate して末尾に通知行を追加
  local _total_lines
  _total_lines=$(printf '%s\n' "${_msg}" | wc -l | tr -d ' ')
  if [[ "${_total_lines}" -gt "${_line_cap}" ]]; then
    local _truncated_lines=$(( _total_lines - _line_cap ))
    _msg=$(printf '%s\n' "${_msg}" | head -n "${_line_cap}")
    _msg="${_msg}"$'\n'"... (${_truncated_lines} more lines truncated)"
  fi

  if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_msg}"
  else
    ADDITIONAL_CONTEXT="${_msg}"
  fi
}

# commit/PR 起草前に NG-DICTIONARY の block 系 term を ADDITIONAL_CONTEXT で事前 inject する
# 目的: 起草段階でNG語を使わせず、block→retry ループを防ぐ (事後型 _inject_principles_on_commit と併存)
# trigger: git commit / gh pr create / gh pr edit / gh pr review / gh issue create / glab 系コマンド
# 重複抑制: SESSION_ID ベースの flag file で 1 session 1 回のみ inject
_inject_ng_dict_on_commit_compose() {
  local _session_key="${SESSION_ID:-$$}"
  local _today; printf -v _today '%(%Y%m%d)T' -1
  local _flag_file="/tmp/claude-ng-inject-${_session_key}-${_today}"
  if [[ -f "$_flag_file" ]]; then
    return 0
  fi

  local _ng_dict_file="${HOME}/.claude/guidelines/writing/NG-DICTIONARY.md"
  local _word_replace_file="${HOME}/.claude/guidelines/writing/PRINCIPLES-word-replace.md"

  # NG-DICTIONARY.md が存在しない場合は silent skip
  if [[ ! -f "$_ng_dict_file" ]]; then
    return 0
  fi

  # block 系 term を動的抽出: "(block)" を含む行から term list を取得
  # 形式: **<name> (block)**: term1 / term2 / ...
  local _block_terms=""
  while IFS= read -r _line; do
    if [[ "$_line" =~ \(block\) ]]; then
      # "**: " 以降を term list として取得
      local _terms_part="${_line#*\*\*: }"
      if [[ -n "$_terms_part" && "$_terms_part" != "$_line" ]]; then
        if [[ -n "$_block_terms" ]]; then
          _block_terms="${_block_terms} / ${_terms_part}"
        else
          _block_terms="${_terms_part}"
        fi
      fi
    fi
  done < "$_ng_dict_file"

  # 1 件も取れなければ silent skip
  if [[ -z "$_block_terms" ]]; then
    return 0
  fi

  # flag 書き込み (以降は重複 inject しない)
  touch "$_flag_file" 2>/dev/null || true

  # 置換ヒント: PRINCIPLES-word-replace.md があれば非日常英語の主要置換表を付加
  local _replace_hint=""
  if [[ -f "$_word_replace_file" ]]; then
    # leverage/utilize/mitigate 等の代表的な非日常英語置換行を抽出 (最大 5 行)
    _replace_hint=$(grep -E 'leverage|utilize|mitigate|facilitate|comprehensive' "$_word_replace_file" 2>/dev/null | head -5 | sed 's/^/  /' || true)
  fi

  local _inject_msg="【起草前 NG 語回避】以下の用語を commit message / PR 本文に使わないでください。source: guidelines/writing/NG-DICTIONARY.md
block_terms: ${_block_terms}
【閉じてない文章 NG】常体 plain JP の開いた文章で書く (rules/genshijin.md)。
  - 体言止め羅列 NG: 「sync 完了。push 済。」 → 「sync した。push した。」
  - 助詞省略 NG: 「file 編集 → sync 必要」 → 「file を編集したら sync が必要になる」
  - 名詞ぶつ切り NG: 「修正 3 件、commit 1 個」 → 「修正を 3 件加えて 1 commit にまとめた」"
  if [[ -n "$_replace_hint" ]]; then
    _inject_msg="${_inject_msg}
置換例 (非日常英語 → 平易な日本語):
${_replace_hint}
詳細: guidelines/writing/PRINCIPLES-word-replace.md"
  fi

  if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_inject_msg}"
  else
    ADDITIONAL_CONTEXT="${_inject_msg}"
  fi

  # inject 効果計測用 log (trigger tool / block_terms 数)
  local _SWEEP_LOG="${HOME}/.claude/logs/ng-pre-sweep-inject.log"
  local _TS_INJ _NTERMS
  printf -v _TS_INJ '%(%Y-%m-%dT%H:%M:%S)T' -1
  _NTERMS=$(awk -F' / ' '{print NF}' <<< "$_block_terms" 2>/dev/null || echo 0)
  printf '%s | pre-tool-use | trigger=%s | n_terms=%s\n' \
    "$_TS_INJ" "${TOOL_NAME:-unknown}" "${_NTERMS}" \
    >> "$_SWEEP_LOG" 2>/dev/null || true
}
