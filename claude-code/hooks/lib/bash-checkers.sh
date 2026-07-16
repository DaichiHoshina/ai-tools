#!/usr/bin/env bash
# Bash tool case body checkers (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_BASH_CHECKERS_LOADED:-}" == "1" ]]; then
    return 0
fi
_BASH_CHECKERS_LOADED=1

# ====================================
# "Bash" tool 分岐の本体。pre-tool-use.sh の case "$TOOL_NAME" in "Bash") から
# 挙動を変えずに切り出したもの。GUARD_CLASS / MESSAGE / ADDITIONAL_CONTEXT は
# 呼び出し元 (pre-tool-use.sh) のグローバル変数をそのまま読み書きする。
# ====================================
_handle_bash_tool() {
  local INPUT="$1"
  local COMMAND
  COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
  classify_bash_command "$COMMAND"

  # AI定型語チェック: git commit / gh / glab の外向き text を抽出して block
  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
    # single-quote 系 regex は変数経由で渡す (shell quoting による capture 空 bug 回避)
    local _re_m_sq="-m[[:space:]]+\'([^\']*)\'"
    local _re_body_sq="--body[[:space:]]+\'([^\']*)\'"
    local _re_title_sq="--title[[:space:]]+\'([^\']*)\'"
    local _re_notes_sq="--notes[[:space:]]+\'([^\']*)\'"
    local _re_desc_sq="--description[[:space:]]+\'([^\']*)\'"

    local _gh_body=""; local _gh_title=""; local _glab_desc=""; local _glab_title=""
    if [[ "$COMMAND" =~ $_re_body_sq ]]; then
      _gh_body="${BASH_REMATCH[1]}"
    elif [[ "$COMMAND" =~ --body[[:space:]]\"([^\"]*)\" ]]; then
      _gh_body="${BASH_REMATCH[1]}"
    fi
    if [[ "$COMMAND" =~ $_re_title_sq ]]; then
      _gh_title="${BASH_REMATCH[1]}"
    elif [[ "$COMMAND" =~ --title[[:space:]]\"([^\"]*)\" ]]; then
      _gh_title="${BASH_REMATCH[1]}"
    fi
    _glab_title="$_gh_title"
    if [[ "$COMMAND" =~ $_re_desc_sq ]]; then
      _glab_desc="${BASH_REMATCH[1]}"
    elif [[ "$COMMAND" =~ --description[[:space:]]\"([^\"]*)\" ]]; then
      _glab_desc="${BASH_REMATCH[1]}"
    fi

    # --- git commit: -m オプション値を抽出 (commit-tree / commit-graph は除外) ---
    local _commit_file_content=""
    local _gh_file_content=""
    if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]]; then
      local _commit_msg=""
      # -m / --message "..." 形式 (space / = 区切り、long form を含む)
      if [[ "$COMMAND" =~ $_re_m_sq ]]; then
        _commit_msg="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ -m[[:space:]]\"([^\"]*)\" ]]; then
        _commit_msg="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ --message[[:space:]=]\'([^\']*)\' ]]; then
        _commit_msg="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ --message[[:space:]=]\"([^\"]*)\" ]]; then
        _commit_msg="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ -m=\'([^\']*)\' ]]; then
        _commit_msg="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ -m=\"([^\"]*)\" ]]; then
        _commit_msg="${BASH_REMATCH[1]}"
      fi
      [[ -n "$_commit_msg" ]] && _block_if_ai_jargon "$_commit_msg" "commit message"

      # -F / --file <file> 形式: ファイル内容を読んで block
      if [[ "$GUARD_CLASS" != "Forbidden" ]]; then
        local _commit_file_path=""
        local _re_F_sq="-F[[:space:]]+\'([^\']*)\'"
        local _re_file_sq="--file[[:space:]]+\'([^\']*)\'"
        if [[ "$COMMAND" =~ $_re_F_sq ]]; then
          _commit_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -F[[:space:]]\"([^\"]*)\" ]]; then
          _commit_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -F[[:space:]]+([^[:space:]\'\"]+) ]]; then
          _commit_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ $_re_file_sq ]]; then
          _commit_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --file[[:space:]]\"([^\"]*)\" ]]; then
          _commit_file_path="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ --file[[:space:]]+([^[:space:]\'\"]+) ]]; then
          _commit_file_path="${BASH_REMATCH[1]}"
        fi
        if [[ -n "$_commit_file_path" ]]; then
          # 相対パスは cwd 起点で解決
          if [[ "$_commit_file_path" != /* ]]; then
            local _cwd
            _cwd=$(jq -r '.cwd // empty' <<< "$INPUT")
            [[ -n "$_cwd" ]] && _commit_file_path="${_cwd}/${_commit_file_path}"
          fi
          if [[ -f "$_commit_file_path" ]]; then
            _commit_file_content=$(cat "$_commit_file_path" 2>/dev/null || true)
            [[ -n "$_commit_file_content" ]] && _block_if_ai_jargon "$_commit_file_content" "commit message (file)"
          fi
        fi
      fi

      # --- 並行 session 巻き込み guard: staged file が本 session 編集 log に無ければ warn ---
      # skip 条件: SESSION_ID 空 / log 不在 / log 空 / git repo 外。誤爆防止優先で block しない
      if [[ -n "$SESSION_ID" ]]; then
        local _SES_LOG="/tmp/claude-session-edits-${SESSION_ID}.log"
        if [[ -f "$_SES_LOG" && -s "$_SES_LOG" ]]; then
          local _CWD_COMMIT
          _CWD_COMMIT=$(jq -r '.cwd // empty' <<< "$INPUT")
          [[ -z "$_CWD_COMMIT" ]] && _CWD_COMMIT="."
          local _GIT_TOPLEVEL
          if _GIT_TOPLEVEL=$(git -C "$_CWD_COMMIT" rev-parse --show-toplevel 2>/dev/null); then
            # staged file の絶対 path (git ls-files 相対 path を repo root から解決)
            # macOS の /tmp /var は /private への symlink のため、両側 realpath で正規化して突合する
            local _STAGED_ABS
            _STAGED_ABS=$(git -C "$_GIT_TOPLEVEL" diff --cached --name-only 2>/dev/null \
              | awk -v r="$_GIT_TOPLEVEL" 'NF{print r"/"$0}' \
              | while IFS= read -r _p; do realpath "$_p" 2>/dev/null || printf '%s\n' "$_p"; done)
            if [[ -n "$_STAGED_ABS" ]]; then
              local _SES_UNIQ
              _SES_UNIQ=$(sort -u "$_SES_LOG" 2>/dev/null \
                | while IFS= read -r _p; do realpath "$_p" 2>/dev/null || printf '%s\n' "$_p"; done \
                | sort -u)
              local _INTRUDERS
              _INTRUDERS=$(printf '%s\n' "$_STAGED_ABS" | grep -Fxv -f <(printf '%s\n' "$_SES_UNIQ") 2>/dev/null || true)
              if [[ -n "$_INTRUDERS" ]]; then
                local _COMMIT_GUARD_WARN="⚠ 並行 session 巻き込み疑い: 本 session の編集 log に無い staged file が commit に含まれる可能性。並行 session 変更混入の確認を推奨:"$'\n'"${_INTRUDERS}"
                if [ -n "$ADDITIONAL_CONTEXT" ]; then
                  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_COMMIT_GUARD_WARN}"
                else
                  ADDITIONAL_CONTEXT="${_COMMIT_GUARD_WARN}"
                fi
              fi
            fi
          fi
        fi
      fi

      # --- staged diff scan (warn-only 第二防衛線): 追加行の private term を検出 ---
      # Edit/Write 即時 block 廃止後の補完。ai-tools 外 cwd は関数内で即 return する
      if [[ "$GUARD_CLASS" != "Forbidden" ]]; then
        local _CWD_DIFF
        _CWD_DIFF=$(jq -r '.cwd // empty' <<< "$INPUT")
        [[ -z "$_CWD_DIFF" ]] && _CWD_DIFF="$PWD"
        local _STAGED_DIFF_WARN
        _STAGED_DIFF_WARN=$(_warn_private_terms_in_staged_diff "$_CWD_DIFF")
        if [[ -n "$_STAGED_DIFF_WARN" ]]; then
          if [ -n "$ADDITIONAL_CONTEXT" ]; then
            ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_STAGED_DIFF_WARN}"
          else
            ADDITIONAL_CONTEXT="${_STAGED_DIFF_WARN}"
          fi
        fi
      fi

      # --amend で inline body オプション (-m/--message/-F/--file) が無い場合:
      # editor 編集で hook は本文取得不可 → warn-only。
      # substring 判定だと --message が -m に誤マッチして warn を抑止するため word-boundary で判定する。
      if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ --amend ]] && \
         ! [[ "$COMMAND" =~ (^|[[:space:]])(-m|-F|--message|--file)([[:space:]=]|$) ]]; then
        local _amend_warn="⚠ --amend で editor 編集する本文も NG 語を避けてください (hook は本文を検査できません)"
        if [ -n "$ADDITIONAL_CONTEXT" ]; then
          ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_amend_warn}"
        else
          ADDITIONAL_CONTEXT="${_amend_warn}"
        fi
      fi
    fi

    # --- gh pr create / gh pr edit / gh pr review / gh pr merge / gh issue create / gh issue comment ---
    # --- gh release create ---
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && { \
        [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] || \
        [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]]; }; then
      local _gh_text="$_gh_body"
      if [[ -n "$_gh_title" ]]; then
        _gh_text="${_gh_text} ${_gh_title}"
      fi
      # --notes "..." or --notes '...' (gh release create)
      if [[ "$COMMAND" =~ $_re_notes_sq ]]; then
        _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ --notes[[:space:]]\"([^\"]*)\" ]]; then
        _gh_text="${_gh_text} ${BASH_REMATCH[1]}"
      fi
      # --body-file <file> / --body-file="<file>": ファイル内容を読んで body に追加
      local _re_body_file_sq="--body-file[[:space:]]+\'([^\']*)\'"
      local _gh_body_file_path=""
      if [[ "$COMMAND" =~ $_re_body_file_sq ]]; then
        _gh_body_file_path="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ --body-file[[:space:]]\"([^\"]*)\" ]]; then
        _gh_body_file_path="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ --body-file[[:space:]]+([^[:space:]\'\"]+) ]]; then
        _gh_body_file_path="${BASH_REMATCH[1]}"
      elif [[ "$COMMAND" =~ --body-file=([^[:space:]\'\"]+) ]]; then
        _gh_body_file_path="${BASH_REMATCH[1]}"
      fi
      if [[ -n "$_gh_body_file_path" ]]; then
        if [[ "$_gh_body_file_path" != /* ]]; then
          local _cwd
          _cwd=$(jq -r '.cwd // empty' <<< "$INPUT")
          [[ -n "$_cwd" ]] && _gh_body_file_path="${_cwd}/${_gh_body_file_path}"
        fi
        if [[ -f "$_gh_body_file_path" ]]; then
          _gh_file_content=$(cat "$_gh_body_file_path" 2>/dev/null || true)
          [[ -n "$_gh_file_content" ]] && _gh_text="${_gh_text}"$'\n'"${_gh_file_content}"
        fi
      fi
      if [[ -n "$_gh_text" ]]; then
        local _gh_subcmd
        _gh_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'gh (pr|issue) (create|edit|comment|review|merge)|gh release create' | head -1)
        _block_if_ai_jargon "$_gh_text" "${_gh_subcmd:-gh}"
      fi
    fi

    # --- glab mr create / glab issue create / glab mr note ---
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]]; then
      local _glab_text="$_glab_desc"
      if [[ -n "$_glab_title" ]]; then
        _glab_text="${_glab_text} ${_glab_title}"
      fi
      if [[ -n "$_glab_text" ]]; then
        local _glab_subcmd
        _glab_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'glab (mr|issue) (create|note)' | head -1)
        _block_if_ai_jargon "$_glab_text" "${_glab_subcmd:-glab}"
      fi
    fi

    # private-name block: git commit / gh / glab コマンドの外向き text を private-name-list.txt でチェック
    if [[ "$GUARD_CLASS" != "Forbidden" ]]; then
      local _pn_cmd_text=""
      local _pn_cmd_label=""
      # git commit -m / -F (AI 定型語 block と同様、file 経由本文も対象)
      if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]]; then
        if [[ "$COMMAND" =~ $_re_m_sq ]]; then
          _pn_cmd_text="${BASH_REMATCH[1]}"
        elif [[ "$COMMAND" =~ -m[[:space:]]\"([^\"]*)\" ]]; then
          _pn_cmd_text="${BASH_REMATCH[1]}"
        fi
        # -F / --file 経由本文も追加 (AI 定型語 block の _commit_file_content を再利用)
        [[ -n "${_commit_file_content:-}" ]] && _pn_cmd_text="${_pn_cmd_text}"$'\n'"${_commit_file_content}"
        _pn_cmd_label="commit message"
      fi
      # gh pr / issue / release
      if [[ -z "$_pn_cmd_label" ]] && { \
          [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] || \
          [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]]; }; then
        _pn_cmd_text="$_gh_body"
        if [[ -n "$_gh_title" ]]; then
          _pn_cmd_text="${_pn_cmd_text} ${_gh_title}"
        fi
        [[ -n "${_gh_file_content:-}" ]] && _pn_cmd_text="${_pn_cmd_text}"$'\n'"${_gh_file_content}"
        _pn_cmd_label=$(printf '%s' "$COMMAND" | grep -oE 'gh (pr|issue) (create|edit|comment|review|merge)|gh release create' | head -1)
      fi
      # glab
      if [[ -z "$_pn_cmd_label" ]] && [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]]; then
        _pn_cmd_text="$_glab_desc"
        if [[ -n "$_glab_title" ]]; then
          _pn_cmd_text="${_pn_cmd_text} ${_glab_title}"
        fi
        _pn_cmd_label=$(printf '%s' "$COMMAND" | grep -oE 'glab (mr|issue) (create|note)' | head -1)
      fi
      if [[ -n "$_pn_cmd_text" && -n "$_pn_cmd_label" ]]; then
        _check_social_hit_in_text "${_pn_cmd_label}" "$_pn_cmd_text"
        [[ "$GUARD_CLASS" == "Forbidden" ]] || _check_private_name "${_pn_cmd_label}" "$_pn_cmd_text"
      fi
    fi
  fi

  # Serena substitution hint: notify Claude when Bash code-file read is detected
  # structurally prevents Bash ratio 51% (analytics) violating CLAUDE.md "Tool selection" principle
  if [ "$GUARD_CLASS" != "Forbidden" ] && _is_serena_replaceable "$COMMAND"; then
    # session 1 回 dedup (同 pattern 反復時の再注入抑止)
    local _serena_hint_today _SERENA_HINT_FLAG
    printf -v _serena_hint_today '%(%Y%m%d)T' -1
    _SERENA_HINT_FLAG="/tmp/claude-serena-hint-$(_stable_session_key)-${_serena_hint_today}"
    if [ ! -f "$_SERENA_HINT_FLAG" ]; then
      : > "$_SERENA_HINT_FLAG" 2>/dev/null || true
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}; 🔍 Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols"
      else
        ADDITIONAL_CONTEXT="🔍 Bash でコードファイル参照検出、Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols"
      fi
    fi
  fi

  # go build ./... / go test ./... の全体実行を block (linker 並列でマシン停止 + docker fixture 起動地獄)
  # canonical: feedback_go_build_scope_limit.md
  if [ "$GUARD_CLASS" != "Forbidden" ] && _is_go_full_build_or_test "$COMMAND"; then
    GUARD_CLASS="Forbidden"
    MESSAGE="${ICON_CRITICAL:-🚫} 禁止: go build/test ./... 全体実行 (linker 並走で machine 停止、test は docker fixture 起動)"
    ADDITIONAL_CONTEXT="変更 package 限定 (\`go build ./pkg/foo/...\` / \`go test ./pkg/foo/...\`) か \`go vet ./...\` を使う。全体が本当に要る時のみ \`-p 4\` 付き。canonical: ~/ai-tools/memory/feedback_go_build_scope_limit.md"
  fi

  # Read tool substitution hint: cat <doc/config file> は Read ツールで代替可能
  # 対象: cat .md/.json/.yaml/.toml/.txt/.sh/.bats (write 系・pipe 系は除外済み)
  if [ "$GUARD_CLASS" != "Forbidden" ] && _is_cat_simple_read "$COMMAND"; then
    # 注入は session 1 回 dedup。観測 log は発火頻度計測のため無条件で記録し続ける
    local _read_hint_today _READ_HINT_FLAG
    printf -v _read_hint_today '%(%Y%m%d)T' -1
    _READ_HINT_FLAG="/tmp/claude-cat-read-hint-$(_stable_session_key)-${_read_hint_today}"
    if [ ! -f "$_READ_HINT_FLAG" ]; then
      : > "$_READ_HINT_FLAG" 2>/dev/null || true
      local _read_hint="📖 cat でファイル読み取り検出: Read ツールを使うこと (IMPORTANT: Avoid using this tool to run \`cat\`)"
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_read_hint}"
      else
        ADDITIONAL_CONTEXT="${_read_hint}"
      fi
    fi
    # 観測 log: 1 週間の発火頻度と誤検出パターンを記録
    _rotate_log_if_needed "$HOME/.claude/logs/cat-read-hint.log"
    printf '[%s] cat-read-hint fired | cmd=%.150s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$COMMAND" >> "$HOME/.claude/logs/cat-read-hint.log" 2>/dev/null || true
  fi

  # 書く系 Bash コマンド: 起草前 NG-DICTIONARY inject + 今日の commit inject
  # 対象: git commit / gh pr|issue|release / glab mr|issue|release
  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
    if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]] \
       || [[ "$COMMAND" =~ gh[[:space:]]+(pr|issue)[[:space:]]+(create|edit|comment|review|merge) ]] \
       || [[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+create ]] \
       || [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]] \
       || [[ "$COMMAND" =~ glab[[:space:]]+release[[:space:]]+create ]]; then
      _inject_ng_dict_on_commit_compose
      _inject_today_commits
    fi
  fi
}
