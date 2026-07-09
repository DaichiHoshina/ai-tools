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

# JSON入力を読み込む
INPUT=$(cat)

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
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: ファイル編集"

    # touchable_files allowlist guard (subagent context)
    # parent (user-prompt-submit hook) が developer-agent fire 時に
    # ~/.claude/state/touchable-<session>.txt へ allowlist を write。
    # state file が存在する間は Edit/Write/MultiEdit/NotebookEdit の
    # file_path を literal match で照合し、違反は exit 2 で block。
    # state file 不在 (= 通常 parent context) は noop。
    while IFS= read -r _TF_PATH; do
      [[ -z "$_TF_PATH" ]] && continue
      if ! _touchable_check "$SESSION_ID" "$_TF_PATH"; then
        _TS_TF=$(date '+%Y-%m-%dT%H:%M:%S')
        mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true
        printf '%s | %s | %s | target=%s\n' \
          "$_TS_TF" "$SESSION_ID" "$TOOL_NAME" "$_TF_PATH" \
          >> "${HOME}/.claude/logs/touchable-files-block.log" 2>/dev/null || true
        echo "[touchable-files-block] ${TOOL_NAME} target '${_TF_PATH}' は touchable_files allowlist 外 (scope creep)。parent から受領した prompt §1 touchable_files を確認するか、allowlist 拡張を parent に escalate (status: partial + scope creep blocker)。opt-out: env CLAUDE_TOUCHABLE_ENFORCE=0" >&2
        exit 2
      fi
    done < <(jq -r '[.tool_input.file_path, (.tool_input.edits[]?.file_path)] | .[] | select(. != null and . != "")' <<< "$INPUT")

    # worktree session 内 main repo 直接 Edit guard
    # MultiEdit は top-level file_path に加え edits[].file_path も持つため両方検査する
    while IFS= read -r _CWD_GUARD_PATH; do
      [[ -z "$_CWD_GUARD_PATH" ]] && continue
      _check_worktree_cwd_guard "$_CWD_GUARD_PATH"
      [[ "$GUARD_CLASS" == "Forbidden" ]] && break
    done < <(jq -r '[.tool_input.file_path, (.tool_input.edits[]?.file_path)] | .[] | select(. != null and . != "")' <<< "$INPUT")
    # Forbidden が立った場合は以降の処理をスキップ
    if [[ "$GUARD_CLASS" == "Forbidden" ]]; then
      :
    else

    # jq 集約: Write/Edit で必要な 4 フィールドを 1 回取得 (fork 削減)
    IFS=$'\t' read -r _EDIT_FILE_PATH EDIT_CONTENT _OLD_STRING _NEW_STRING < <(
      extract_json_fields "$INPUT" \
        '.tool_input.file_path // ""' \
        'if .tool_input.content then .tool_input.content elif .tool_input.new_string then .tool_input.new_string elif .tool_input.edits then [.tool_input.edits[].new_string] | join("\n") else "" end' \
        '.tool_input.old_string // ""' \
        '.tool_input.new_string // ""'
    )

    # large-repo 連続 Edit 委譲 signal (warn-only)
    _check_large_repo_consecutive_edit "$SESSION_ID" "$_EDIT_FILE_PATH"

    # 直編集ガード: ~/.claude/{synced_dir}/... で repo source 存在時に redirect 推奨
    # sync.sh to-local で上書き消失するため、必ず repo source を編集する規約
    _EDIT_PATH="$_EDIT_FILE_PATH"
    if [ -n "$_EDIT_PATH" ] && [[ "$_EDIT_PATH" == "$HOME/.claude/"* ]]; then
      _REL_PATH="${_EDIT_PATH#"$HOME/.claude/"}"
      _FIRST_COMP="${_REL_PATH%%/*}"
      case "$_FIRST_COMP" in
        commands|skills|hooks|agents|rules|guidelines|config|references|CLAUDE.md)
          _REPO_PATH="$(_aitools_dir)/claude-code/$_REL_PATH"
          if [ -f "$_REPO_PATH" ]; then
            _DIRECT_EDIT_WARN="⚠ 直編集警告: ${_EDIT_PATH} は sync.sh to-local で上書き消失します。代わりに repo source ${_REPO_PATH} を編集してください。"
            if [ -n "$ADDITIONAL_CONTEXT" ]; then
              ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_DIRECT_EDIT_WARN}"
            else
              ADDITIONAL_CONTEXT="${_DIRECT_EDIT_WARN}"
            fi
          fi
          ;;
      esac
    fi

    # 危険パターン検出（機密リテラル/SSRF/SQL injection）
    if [ -n "$EDIT_CONTENT" ]; then
      detect_dangerous_patterns "$EDIT_CONTENT"
    fi

    # social-hit block (Edit/Write): 恒久的に無効化 (2026-07-09、git commit / gh / glab 系のみ block)
    # 理由: local reversible な file 書込を毎回止めるとメモ集約作業等が回らない。
    # 不可逆な公開経路 (git push 経由 remote) は Bash 側の _check_social_hit_in_text で防ぐ。

    # live-doc warn: library API method 直書き検出 → context7 / WebFetch 確認を促す (warn-only)
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
      _check_live_doc_required "$_EDIT_FILE_PATH" "$EDIT_CONTENT"
    fi

    # hook-bench warn: hooks/*.sh 編集前 baseline 鮮度確認 (warn-only)
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$_EDIT_FILE_PATH" ]; then
      _check_hook_edit_baseline_missing "$_EDIT_FILE_PATH"
    fi

    # local-docs テンプレ準拠 block (Write のみ、新規 .html を _templates 由来でない content で Write したら block)
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$TOOL_NAME" == "Write" ]] && [ -n "$EDIT_CONTENT" ]; then
      _check_local_docs_template "$_EDIT_FILE_PATH" "$EDIT_CONTENT"
    fi

    # private-name block (Edit/Write): 恒久的に無効化 (2026-07-09、git commit / gh / glab 系のみ block)
    # 理由: local reversible な file 書込を毎回止めるとメモ集約作業等が回らない。
    # 不可逆な公開経路 (git push 経由 remote) は Bash 側の _check_private_name で防ぐ。

    # .serena/memories/ block: CLAUDE.md 規約違反パスへの書き込みを block
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$_EDIT_FILE_PATH" ]; then
      _check_serena_memory_path "$_EDIT_FILE_PATH"
    fi

    # ~/.claude/projects/*/ai-tools*/memory/ block: ai-tools repo の legacy auto-memory path を block
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$_EDIT_FILE_PATH" ]; then
      _check_legacy_auto_memory_path "$_EDIT_FILE_PATH"
    fi

    # AI定型語 block: 作業 repo の .md / .txt への書き込みを検査
    # ai-tools 配下は除外 (guidelines / NG-DICTIONARY など NG 語を literal 保持する設定 md の誤爆防止)
    # auto-memory dir (~/.claude/projects/*/memory/) も除外 (AI 自己分析の生記録、外向き prose 規則対象外)
    # ~/.claude/plans/ も除外 (`/plan` 出力は AI の作業計画、外向き prose ではない)
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
      _AJ_EXT="${_EDIT_FILE_PATH##*.}"
      if [[ "$_AJ_EXT" == "md" || "$_AJ_EXT" == "txt" ]]; then
        if ! _is_aitools_path "$_EDIT_FILE_PATH" && ! _is_auto_memory_path "$_EDIT_FILE_PATH" && ! _is_plans_path "$_EDIT_FILE_PATH" && ! _is_references_private_path "$_EDIT_FILE_PATH" && ! _is_memory_path "$_EDIT_FILE_PATH"; then
          _AJ_BASENAME=$(basename "${_EDIT_FILE_PATH:-file}")
          _block_if_ai_jargon "$EDIT_CONTENT" "ファイル: ${_AJ_BASENAME}"
        fi
      fi
    fi

    # Rename propagation detection (Edit tool only has old_string/new_string)
    if [ -n "$_OLD_STRING" ] && [ -n "$_NEW_STRING" ]; then
      detect_rename_propagation "$_OLD_STRING" "$_NEW_STRING" "$_EDIT_FILE_PATH"
    fi

    # Sonnet delegation declaration grep (CLAUDE.md Auto-Delegation "Edit/Write declaration rule")
    # fetch last 30 lines of latest assistant message from transcript_path; check for "Inline exception" / "Inline prohibited"
    # session+transcript mtime キャッシュ: transcript 更新がない場合は python3 fork を skip
    _TRANSCRIPT=$(jq -r '.transcript_path // empty' <<< "$INPUT")
    if [ -n "$_TRANSCRIPT" ] && [ -f "$_TRANSCRIPT" ]; then
      _TRANSCRIPT_MTIME=$(portable_stat_mtime "$_TRANSCRIPT")
      _TRANSCRIPT_CACHE_FLAG="/tmp/claude-transcript-decl-${SESSION_ID:-$$}-${_TRANSCRIPT_MTIME}"
      if [[ -f "$_TRANSCRIPT_CACHE_FLAG" ]]; then
        _DECL_FOUND=$(cat "$_TRANSCRIPT_CACHE_FLAG" 2>/dev/null || true)
      else
        # 古いキャッシュ (同セッション・異なる mtime) を削除してから scan
        rm -f "/tmp/claude-transcript-decl-${SESSION_ID:-$$}"-* 2>/dev/null || true
        _DECL_FOUND=$(python3 - "$_TRANSCRIPT" <<'PYEOF'
import sys, json
path = sys.argv[1]
lines = []
try:
    with open(path, encoding='utf-8') as f:
        lines = f.readlines()
except Exception:
    sys.exit(0)
# scan from the end to find the latest assistant entry and extract its text
for raw in reversed(lines):
    raw = raw.strip()
    if not raw:
        continue
    try:
        d = json.loads(raw)
    except Exception:
        continue
    if d.get('type') != 'assistant':
        continue
    content = d.get('message', {}).get('content', [])
    text = ''
    for c in content:
        if isinstance(c, dict) and c.get('type') == 'text':
            text = c.get('text', '')
            break
    if not text:
        continue
    tail = '\n'.join(text.splitlines()[-30:])
    if 'Inline exception' in tail or 'Inline prohibited' in tail:
        print('found')
    sys.exit(0)
PYEOF
        )
        # scan 結果を mtime キャッシュとして保存
        printf '%s' "${_DECL_FOUND:-}" > "$_TRANSCRIPT_CACHE_FLAG" 2>/dev/null || true
      fi  # end: cache hit / miss
      if [ "$_DECL_FOUND" != "found" ]; then
        _DECL_WARN="⚠ Sonnet 委譲宣言抜け: Edit/Write 前に 'Inline exception (reason: ...)' か 'Inline prohibited (reason: ...)' を 1 行宣言 (throttle 等詳細: references/auto-delegation-detailed.md)"
        if [ -n "$ADDITIONAL_CONTEXT" ]; then
          ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_DECL_WARN}"
        else
          ADDITIONAL_CONTEXT="${_DECL_WARN}"
        fi
      fi
    fi

    # 書く系 tool: 今日の commit inject（writing 規約更新を最新規範で反映させる）
    _inject_today_commits
    fi  # end: cwd-guard Forbidden skip
    ;;

  "Bash")
    COMMAND=$(jq -r '.tool_input.command // empty' <<< "$INPUT")
    classify_bash_command "$COMMAND"

    # AI定型語チェック: git commit / gh / glab の外向き text を抽出して block
    if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ -n "$COMMAND" ]]; then
      # single-quote 系 regex は変数経由で渡す (shell quoting による capture 空 bug 回避)
      _re_m_sq="-m[[:space:]]+\'([^\']*)\'"
      _re_body_sq="--body[[:space:]]+\'([^\']*)\'"
      _re_title_sq="--title[[:space:]]+\'([^\']*)\'"
      _re_notes_sq="--notes[[:space:]]+\'([^\']*)\'"
      _re_desc_sq="--description[[:space:]]+\'([^\']*)\'"

      _gh_body=""; _gh_title=""; _glab_desc=""; _glab_title=""
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
      if [[ "$COMMAND" =~ git[[:space:]]+commit([[:space:]]|$) ]]; then
        _commit_msg=""
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
          _commit_file_path=""
          _re_F_sq="-F[[:space:]]+\'([^\']*)\'"
          _re_file_sq="--file[[:space:]]+\'([^\']*)\'"
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
              _cwd=$(jq -r '.cwd // empty' <<< "$INPUT")
              [[ -n "$_cwd" ]] && _commit_file_path="${_cwd}/${_commit_file_path}"
            fi
            if [[ -f "$_commit_file_path" ]]; then
              _commit_file_content=$(cat "$_commit_file_path" 2>/dev/null || true)
              [[ -n "$_commit_file_content" ]] && _block_if_ai_jargon "$_commit_file_content" "commit message (file)"
            fi
          fi
        fi

        # --amend で inline body オプション (-m/--message/-F/--file) が無い場合:
        # editor 編集で hook は本文取得不可 → warn-only。
        # substring 判定だと --message が -m に誤マッチして warn を抑止するため word-boundary で判定する。
        if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ --amend ]] && \
           ! [[ "$COMMAND" =~ (^|[[:space:]])(-m|-F|--message|--file)([[:space:]=]|$) ]]; then
          _amend_warn="⚠ --amend で editor 編集する本文も NG 語を避けてください (hook は本文を検査できません)"
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
        _gh_text="$_gh_body"
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
        _re_body_file_sq="--body-file[[:space:]]+\'([^\']*)\'"
        _gh_body_file_path=""
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
            _cwd=$(jq -r '.cwd // empty' <<< "$INPUT")
            [[ -n "$_cwd" ]] && _gh_body_file_path="${_cwd}/${_gh_body_file_path}"
          fi
          if [[ -f "$_gh_body_file_path" ]]; then
            _gh_file_content=$(cat "$_gh_body_file_path" 2>/dev/null || true)
            [[ -n "$_gh_file_content" ]] && _gh_text="${_gh_text}"$'\n'"${_gh_file_content}"
          fi
        fi
        if [[ -n "$_gh_text" ]]; then
          _gh_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'gh (pr|issue) (create|edit|comment|review|merge)|gh release create' | head -1)
          _block_if_ai_jargon "$_gh_text" "${_gh_subcmd:-gh}"
        fi
      fi

      # --- glab mr create / glab issue create / glab mr note ---
      if [[ "$GUARD_CLASS" != "Forbidden" ]] && [[ "$COMMAND" =~ glab[[:space:]]+(mr|issue)[[:space:]]+(create|note) ]]; then
        _glab_text="$_glab_desc"
        if [[ -n "$_glab_title" ]]; then
          _glab_text="${_glab_text} ${_glab_title}"
        fi
        if [[ -n "$_glab_text" ]]; then
          _glab_subcmd=$(printf '%s' "$COMMAND" | grep -oE 'glab (mr|issue) (create|note)' | head -1)
          _block_if_ai_jargon "$_glab_text" "${_glab_subcmd:-glab}"
        fi
      fi

      # private-name block: git commit / gh / glab コマンドの外向き text を private-name-list.txt でチェック
      if [[ "$GUARD_CLASS" != "Forbidden" ]]; then
        _pn_cmd_text=""
        _pn_cmd_label=""
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
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}; 🔍 Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols"
      else
        ADDITIONAL_CONTEXT="🔍 Bash でコードファイル参照検出、Serena 振替推奨: get_symbols_overview / find_symbol(include_body=true) / find_referencing_symbols"
      fi
    fi

    # Read tool substitution hint: cat <doc/config file> は Read ツールで代替可能
    # 対象: cat .md/.json/.yaml/.toml/.txt/.sh/.bats (write 系・pipe 系は除外済み)
    if [ "$GUARD_CLASS" != "Forbidden" ] && _is_cat_simple_read "$COMMAND"; then
      _read_hint="📖 cat でファイル読み取り検出: Read ツールを使うこと (IMPORTANT: Avoid using this tool to run \`cat\`)"
      if [ -n "$ADDITIONAL_CONTEXT" ]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_read_hint}"
      else
        ADDITIONAL_CONTEXT="${_read_hint}"
      fi
      # 観測 log: 1 週間の発火頻度と誤検出パターンを記録
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
    ;;

  "mcp__serena__create_text_file"|"mcp__serena__replace_regex"|"mcp__serena__replace_content"|"mcp__serena__replace_symbol_body"|"mcp__serena__insert_after_symbol"|"mcp__serena__insert_before_symbol"|"mcp__serena__write_memory"|"mcp__serena__delete_memory"|"mcp__serena__execute_shell_command"|"mcp__serena__rename_symbol")
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: Serena変更操作"

    # .serena/memories/ block: create_text_file / write_memory 経由の書き込みも block
    # create_text_file は relative_path、write_memory は memory_name パラメータを使う
    _SERENA_PATH=$(jq -r '.tool_input.relative_path // .tool_input.memory_name // empty' <<< "$INPUT")
    if [[ -n "$_SERENA_PATH" ]]; then
      _check_serena_memory_path "$_SERENA_PATH"
    fi
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
    # ただし general-purpose は CLAUDE.md「原則使わない」最大コスト源 → Boundary 警告
    SUBAGENT_TYPE=$(jq -r '.tool_input.subagent_type // empty' <<< "$INPUT")

    # 並列判定 self-review (全 Task 発火時に inject)
    PARALLEL_REVIEW=$'【並列 self-review (強制 echo、default=並列/委譲)】\n0. default: 並列発火 + Sonnet 委譲。単発・inline 選択時は「なぜ並列/委譲しないか」を 1 行 echo。迷ったら並列・委譲側\n1. Manager 経由は formula_trace、直接 Task は judgment 行を echo (書式: references/PARALLEL-PATTERNS.md)\n2. 独立 task ≥2 なら 1 message に N 個 Agent を並べる (逐次発火だと peak=1)\n3. echo 抜けは under-parallel risk'

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
        ADDITIONAL_CONTEXT="代替: claude-code-guide / Explore / 直接 grep+find / serena MCP（references/performance-insights.md 参照）
${PARALLEL_REVIEW}${PREP_WARN}"
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
        ADDITIONAL_CONTEXT="代替: explore-agent (検索) / claude-code-guide (CLI/SDK) / developer-agent (実装)
${PARALLEL_REVIEW}${PREP_WARN}"
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
    # 未知のツールはBoundary扱い
    GUARD_CLASS="Boundary"
    MESSAGE="🔶 要確認: 未分類ツール: $TOOL_NAME"
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
if [ "$GUARD_CLASS" = "Forbidden" ]; then
  exit 2
fi
