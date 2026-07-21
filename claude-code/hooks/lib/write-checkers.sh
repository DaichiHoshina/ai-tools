#!/usr/bin/env bash
# write-op checkers (extracted from pre-tool-use.sh)
# 多重 source 防止
if [[ "${_WRITE_CHECKERS_LOADED:-}" == "1" ]]; then
    return 0
fi
_WRITE_CHECKERS_LOADED=1

# thresholds.sh は portable_stat_mtime 前後で使う値には直接依存しないが、他 module と source 順を揃える
# shellcheck source=thresholds.sh
source "${BASH_SOURCE[0]%/*}/thresholds.sh"
# comment marker 抽出 (_comment_style_marker_re_for / _extract_comment_body_text) を AI 定型語 block で再利用する
# shellcheck source=../../lib/comment-style-checker.sh
source "${BASH_SOURCE[0]%/*}/../../lib/comment-style-checker.sh"

# ====================================
# Live Doc Required (warn-only)
# Edit/Write content に主要 library API method が含まれる場合に
# context7 / WebFetch での docs 取得を促す warn を注入する
# 誤検知対策: .sh / .bats / hook 自身は除外
# ====================================

# よく使われる library API method の keyword list (false positive を抑えるため絞り込む)
_LIVE_DOC_KEYWORDS=(
  "useState"
  "useEffect"
  "useCallback"
  "useMemo"
  "useRef"
  "useContext"
  "axios\.create"
  "axios\.get"
  "axios\.post"
  "fastapi\.Depends"
  "FastAPI\("
  "app\.include_router"
  "prisma\.connect"
  "prisma\.\w*\.findMany"
  "prisma\.\w*\.create"
  "supabase\.from"
  "createClient\("
  "getServerSession\("
  "NextResponse\.json"
  "OpenAI\("
  "anthropic\.messages\.create"
  "langchain\."
  "vite\.defineConfig"
  "defineConfig\("
  "nuxt\.config"
)

_check_live_doc_required() {
  local file_path="$1"
  local content="$2"

  # 空 content はスキップ
  [ -z "$content" ] && return 0

  # 実装例を含む設定 file で誤爆するため、.sh / .bats / hook 自身 / tests/ は除外する
  case "$file_path" in
    *.sh|*.bats) return 0 ;;
    */tests/*|*/hooks/*) return 0 ;;
    */skills/context7/*) return 0 ;;
  esac

  local matched_keyword=""
  for kw in "${_LIVE_DOC_KEYWORDS[@]}"; do
    if echo "$content" | grep -qE "$kw" 2>/dev/null; then
      matched_keyword="$kw"
      break
    fi
  done

  [ -z "$matched_keyword" ] && return 0

  local warn_msg="${ICON_WARNING} [live-doc] library API method「${matched_keyword}」を直書き検出。training cutoff (Jan 2026) 後の API 変更がある可能性があります。context7 skill か WebFetch で最新 docs を確認してください (CLAUDE.md § Library API Live Doc Required)"
  if [ -n "$ADDITIONAL_CONTEXT" ]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${warn_msg}"
  else
    ADDITIONAL_CONTEXT="${warn_msg}"
  fi
}

# ====================================
# hook-edit baseline 鮮度 warn
# claude-code/hooks/*.sh を Edit / Write / MultiEdit する直前に
# 24h 以内の hook-bench baseline log が存在しない場合 warn する
# 例外 (log 出力のみ / 読み取り専用 hook 変更) は user 判定に委ねるため block ではなく warn
# 参照: references/on-demand-rules/measure-before-hook-change.md
# ====================================
_HOOK_BENCH_LOG_DIR="${HOME}/.claude/logs"
_HOOK_BENCH_FRESH_SEC=$((24 * 60 * 60))

_check_hook_edit_baseline_missing() {
  local file_path="$1"
  [[ -z "$file_path" ]] && return 0

  # claude-code/hooks/*.sh 以外は対象外
  case "$file_path" in
    */claude-code/hooks/*.sh) ;;
    *) return 0 ;;
  esac

  # baseline log の最新 mtime を取得 (なければ 0)
  local latest_mtime=0
  if [ -d "$_HOOK_BENCH_LOG_DIR" ]; then
    local f
    for f in "$_HOOK_BENCH_LOG_DIR"/hook-bench-*.log; do
      [ -e "$f" ] || continue
      local m
      m=$(portable_stat_mtime "$f")
      [ "$m" -gt "$latest_mtime" ] && latest_mtime=$m
    done
  fi

  local now
  now=$(date +%s)
  local age=$((now - latest_mtime))

  if [ "$latest_mtime" -eq 0 ] || [ "$age" -gt "$_HOOK_BENCH_FRESH_SEC" ]; then
    local warn_msg
    if [ "$latest_mtime" -eq 0 ]; then
      warn_msg="${ICON_WARNING} [hook-bench] hook 編集前 baseline 未取得。\`./scripts/hook-bench.sh --log\` で latency baseline を採取してから rollout してください (references/on-demand-rules/measure-before-hook-change.md)。log のみ / 読み取り専用 hook 変更ならスキップ可"
    else
      local age_hours=$((age / 3600))
      warn_msg="${ICON_WARNING} [hook-bench] 最新 baseline が ${age_hours}h 前 (>24h)。\`./scripts/hook-bench.sh --log\` で再採取してから rollout してください (references/on-demand-rules/measure-before-hook-change.md)。log のみ / 読み取り専用変更ならスキップ可"
    fi
    if [ -n "$ADDITIONAL_CONTEXT" ]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${warn_msg}"
    else
      ADDITIONAL_CONTEXT="${warn_msg}"
    fi
  fi
}

# ====================================
# worktree session 内 main repo 直接 Edit guard
# worktree session (CWD が **/.claude/worktrees/* 配下) で file_path が
# worktree 外を指す Edit/Write/NotebookEdit を exit 2 でブロックする
# ====================================
_check_worktree_cwd_guard() {
  local file_path="$1"
  [[ -z "$file_path" ]] && return 0

  # CWD 取得: CLAUDE_PROJECT_DIR 優先、なければ pwd
  local cwd="${CLAUDE_PROJECT_DIR:-}"
  if [[ -z "$cwd" ]]; then
    cwd=$(pwd 2>/dev/null || true)
  fi
  [[ -z "$cwd" ]] && return 0

  # worktree session 判定: CWD が /.claude/worktrees/ 配下か
  # パターン: */.claude/worktrees/<name> or */.claude/worktrees/<name>/<subdir>
  if [[ "$cwd" != */.claude/worktrees/* ]]; then
    # worktree 外 session → guard 不要
    return 0
  fi

  # worktree root を抽出: /.claude/worktrees/<name> までのパス
  # bash パターン展開で最短 prefix match
  local wt_root="${cwd%%/.claude/worktrees/*}/.claude/worktrees/"
  # worktrees/<name> の name 部分を取得
  local after_wt="${cwd#*/.claude/worktrees/}"
  local wt_name="${after_wt%%/*}"
  wt_root="${wt_root}${wt_name}"

  # file_path が worktree root 配下かチェック
  # 正規化: 末尾スラッシュ除去して前方一致
  local norm_wt="${wt_root%/}"
  local norm_fp="${file_path%/}"

  if [[ "$norm_fp" == "$norm_wt" || "$norm_fp" == "$norm_wt/"* ]]; then
    # worktree 内 path → OK
    return 0
  fi

  # worktree 外 path → block
  GUARD_CLASS="Forbidden"
  MESSAGE="${ICON_CRITICAL} [cwd-guard] worktree session 中の main repo 直接 Edit を block"
  ADDITIONAL_CONTEXT="worktree 内 path を指定するか、ExitWorktree してから再実行する。worktree root: ${wt_root} / 指定 path: ${file_path}"
}

# ====================================
# local-docs テンプレ準拠 block
# local-docs 配下に新規 .html を Write する場合、_templates/{type}.html 由来 (= <style id="local-docs-style"> を含む) で
# ない content を Forbidden で block する。Write 直書きで共通 CSS / decorate が落ちる事故の事前防止。
# 適用範囲: Write のみ (Edit は既存 file の部分編集なので除外)
# 除外 path: _templates/ / _index/ / root meta 5 (CLAUDE.md / AGENTS.md / STRUCTURE.md / README.md / _redirects.md)
# ====================================
_check_local_docs_template() {
  local file_path="$1"
  local content="$2"
  [[ -z "$file_path" || -z "$content" ]] && return 0

  # local-docs 配下かつ .html のみ対象
  [[ "$file_path" != */local-docs/* ]] && return 0
  [[ "$file_path" != *.html ]] && return 0

  # 除外: _templates / _index 配下
  [[ "$file_path" == */local-docs/_templates/* ]] && return 0
  [[ "$file_path" == */local-docs/_index/* ]] && return 0

  # 除外: root meta (5 file は .md だが念のため html 拡張子でも除外)
  local _basename
  _basename=$(basename "$file_path")
  case "$_basename" in
    CLAUDE.md|AGENTS.md|STRUCTURE.md|README.md|_redirects.md) return 0 ;;
  esac

  # テンプレ準拠マーカーが両方あれば OK
  if [[ "$content" == *'<style id="local-docs-style">'* ]] && \
     [[ "$content" == *'<script id="local-docs-script">'* ]]; then
    return 0
  fi

  # local-docs repo root 推定: path 中の "/local-docs/" の手前までを root とする
  local _ld_root="${file_path%%/local-docs/*}/local-docs"
  GUARD_CLASS="Forbidden"
  MESSAGE="${ICON_CRITICAL} [local-docs] テンプレ非準拠 .html の Write を block"
  ADDITIONAL_CONTEXT="local-docs 配下の新規 .html は \`_templates/{type}.html\` 由来でなければならない。Write 直書きで <style id=\"local-docs-style\"> / <script id=\"local-docs-script\"> が欠落すると共通 CSS / decorate / _index/ build が全て効かなくなる。手順: (1) Bash \`cp ${_ld_root}/_templates/{type}.html ${file_path}\` でテンプレ複製、(2) Edit で本文 placeholder を差し替え。type 一覧は local-docs/CLAUDE.md \"Templates\" 参照。"

  # block log
  local _log="$HOME/.claude/logs/local-docs-template-block.log"
  mkdir -p "$(dirname "$_log")" 2>/dev/null || true
  printf '[%s] block: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$file_path" >> "$_log" 2>/dev/null || true
}

# ====================================
# "Edit"|"Write"|"MultiEdit"|"NotebookEdit" tool 分岐の本体。pre-tool-use.sh の
# case "$TOOL_NAME" in "Edit"|"Write"|"MultiEdit"|"NotebookEdit") から
# 挙動を変えずに切り出したもの。GUARD_CLASS / ADDITIONAL_CONTEXT は
# 呼び出し元 (pre-tool-use.sh) のグローバル変数をそのまま読み書きする。
# ====================================

# code 拡張子は comment 行だけを抽出して判定する。全文判定だと識別子や URL に誤爆する。
# md/txt は全文、対象外拡張子は silent skip する。
_run_ai_jargon_check() {
  local _path="$1"
  local _content="$2"
  [[ "$GUARD_CLASS" == "Forbidden" ]] && return 0
  [[ -z "$_content" ]] && return 0
  if _is_aitools_path "$_path" || _is_auto_memory_path "$_path" || _is_plans_path "$_path" || _is_references_private_path "$_path" || _is_memory_path "$_path"; then
    return 0
  fi
  local _ext="${_path##*.}"
  local _bn
  _bn=$(basename "${_path:-file}")
  if [[ "$_ext" == "md" || "$_ext" == "txt" ]]; then
    _block_if_ai_jargon "$_content" "ファイル: ${_bn}"
    return 0
  fi
  local _comment_text
  if _comment_text="$(_extract_comment_body_text "$_path" "$_content")" && [[ -n "$_comment_text" ]]; then
    _block_if_ai_jargon "$_comment_text" "ファイル: ${_bn} (comment)"
  fi
}

_is_target_project_path() {
  local _path="$1"
  local _pat="${CLAUDE_TARGET_PROJECT_PATH_PATTERN:-}"
  [[ -z "$_pat" ]] && return 1
  case "$_path" in
    $_pat) return 0 ;;
    *) return 1 ;;
  esac
}

_check_target_migration_safety() {
  local _path="$1"
  local _content="$2"
  [[ "$GUARD_CLASS" == "Forbidden" ]] && return 0
  [[ -z "$_path" || -z "$_content" ]] && return 0
  [[ "$_path" != *.sql ]] && return 0
  _is_target_project_path "$_path" || return 0
  local _warns=""
  if printf '%s' "$_content" | grep -qiE 'ON DELETE CASCADE'; then
    _warns="${_warns}CASCADE 削除を検出 → RESTRICT を優先すべき / "
  fi
  if [[ "$_path" == *.up.sql || "$_path" == *migration*.sql ]]; then
    if printf '%s' "$_content" | grep -qiE 'CREATE TABLE'; then
      if ! printf '%s' "$_content" | grep -qiE 'created_at'; then
        _warns="${_warns}CREATE TABLE に created_at 欠如 / "
      fi
      if ! printf '%s' "$_content" | grep -qiE 'updated_at'; then
        _warns="${_warns}CREATE TABLE に updated_at 欠如 / "
      fi
    fi
    if [[ "$_path" == *.up.sql ]]; then
      local _down="${_path%.up.sql}.down.sql"
      if [[ ! -f "$_down" ]]; then
        _warns="${_warns}対応する down.sql が存在しない / "
      fi
    fi
  fi
  [[ -z "$_warns" ]] && return 0
  local _bn
  _bn=$(basename "$_path")
  local _log_dir="$HOME/.claude/logs"
  mkdir -p "$_log_dir" 2>/dev/null
  local _log="$_log_dir/review-pattern-warn.log"
  _rotate_log_if_needed "$_log" 2>/dev/null || true
  printf '[%s] %s | migration-safety | %s | %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "${SESSION_ID:-unknown}" "$_path" "${_warns%/ }" >> "$_log" 2>/dev/null || true
  local _warn="▲ migration safety warn: ${_bn} → ${_warns%/ }"
  if [ -n "$ADDITIONAL_CONTEXT" ]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_warn}"
  else
    ADDITIONAL_CONTEXT="${_warn}"
  fi
  return 0
}

_check_edit_churn() {
  local _session="$1"
  local _path="$2"
  [[ -z "$_session" || -z "$_path" ]] && return 0
  local _state_dir="$HOME/.claude/state"
  local _state_file="$_state_dir/churn-count-${_session}.tsv"
  mkdir -p "$_state_dir" 2>/dev/null || return 0
  local _count=0
  if [[ -f "$_state_file" ]]; then
    _count=$(awk -F'\t' -v p="$_path" '$1==p {print $2}' "$_state_file" 2>/dev/null | tail -1)
    [[ -z "$_count" ]] && _count=0
  fi
  _count=$((_count + 1))
  local _tmp="${_state_file}.tmp.$$"
  {
    [[ -f "$_state_file" ]] && awk -F'\t' -v p="$_path" '$1!=p' "$_state_file"
    printf '%s\t%s\n' "$_path" "$_count"
  } > "$_tmp" 2>/dev/null && mv "$_tmp" "$_state_file" 2>/dev/null || rm -f "$_tmp" 2>/dev/null
  if [[ $_count -ge 3 ]]; then
    local _log_dir="$HOME/.claude/logs"
    mkdir -p "$_log_dir" 2>/dev/null
    local _log="$_log_dir/review-pattern-warn.log"
    _rotate_log_if_needed "$_log" 2>/dev/null || true
    printf '[%s] %s | churn | %s | %d\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$_session" "$_path" "$_count" >> "$_log" 2>/dev/null || true
    local _bn
    _bn=$(basename "$_path")
    local _warn="▲ churn warn: ${_bn} は本 session で ${_count} 回目の書き換え。差分の意図を確認し、無意味な rename / 有用 comment 削除がないか見直す (log: ~/.claude/logs/review-pattern-warn.log)"
    if [ -n "$ADDITIONAL_CONTEXT" ]; then
      ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_warn}"
    else
      ADDITIONAL_CONTEXT="${_warn}"
    fi
  fi
  return 0
}

_check_ai_coined_terms() {
  local _path="$1"
  local _content="$2"
  [[ "$GUARD_CLASS" == "Forbidden" ]] && return 0
  [[ -z "$_path" || -z "$_content" ]] && return 0
  local _pat="${CLAUDE_AI_COINED_TERMS_PATTERN:-}"
  [[ -z "$_pat" ]] && return 0
  _is_target_project_path "$_path" || return 0
  local _ext="${_path##*.}"
  local _target=""
  if [[ "$_ext" == "md" || "$_ext" == "txt" ]]; then
    _target="$_content"
  else
    _target="$(_extract_comment_body_text "$_path" "$_content" 2>/dev/null || true)"
    [[ -z "$_target" ]] && return 0
  fi
  local _hits
  _hits=$(printf '%s' "$_target" | grep -nE "$_pat" 2>/dev/null | head -5 || true)
  [[ -z "$_hits" ]] && return 0
  local _bn
  _bn=$(basename "$_path")
  local _msg
  _msg="◉ AI 造語 block (ファイル: ${_bn}): code review で「AI 生成の造語」と指摘された語を検出した。定義された用語で書き直すか、初出なら定義を添える。検出行:
${_hits}"
  {
    printf '%s\n' "$_msg"
  } >&2
  GUARD_CLASS="Forbidden"
  return 0
}

_check_target_subtest_parallel() {
  local _path="$1"
  local _content="$2"
  [[ "$GUARD_CLASS" == "Forbidden" ]] && return 0
  [[ -z "$_path" || -z "$_content" ]] && return 0
  [[ "$_path" != *_test.go ]] && return 0
  _is_target_project_path "$_path" || return 0
  local _missing
  _missing=$(printf '%s' "$_content" | awk '
    /t\.Run\(/ { in_run=1; brace=0; has_parallel=0; start=NR; next }
    in_run && /t\.Parallel\(\)/ { has_parallel=1 }
    in_run {
      for (i=1; i<=length($0); i++) {
        c = substr($0, i, 1)
        if (c == "{") brace++
        if (c == "}") { brace--; if (brace == 0) { if (!has_parallel) print start; in_run=0; break } }
      }
    }
  ' 2>/dev/null | head -3)
  [[ -z "$_missing" ]] && return 0
  local _bn
  _bn=$(basename "$_path")
  local _log_dir="$HOME/.claude/logs"
  mkdir -p "$_log_dir" 2>/dev/null
  local _log="$_log_dir/review-pattern-warn.log"
  _rotate_log_if_needed "$_log" 2>/dev/null || true
  printf '[%s] %s | subtest-parallel | %s | lines=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "${SESSION_ID:-unknown}" "$_path" "$(echo "$_missing" | tr '\n' ',')" >> "$_log" 2>/dev/null || true
  local _warn="▲ subtest parallel warn: ${_bn} の t.Run( block に t.Parallel() が抜けている行 (${_missing//$'\n'/, })"
  if [ -n "$ADDITIONAL_CONTEXT" ]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_warn}"
  else
    ADDITIONAL_CONTEXT="${_warn}"
  fi
  return 0
}

_check_target_sql_null_handwriting() {
  local _path="$1"
  local _content="$2"
  [[ "$GUARD_CLASS" == "Forbidden" ]] && return 0
  [[ -z "$_path" || -z "$_content" ]] && return 0
  [[ "$_path" != *.go ]] && return 0
  _is_target_project_path "$_path" || return 0
  [[ "$_path" == *_test.go ]] && return 0
  local _hits
  _hits=$(printf '%s' "$_content" | grep -nE 'sql\.(Null\[|NullString\b|NullInt64\b|NullInt32\b|NullInt16\b|NullBool\b|NullFloat64\b|NullTime\b|NullByte\b)' 2>/dev/null | head -3 || true)
  [[ -z "$_hits" ]] && return 0
  local _bn
  _bn=$(basename "$_path")
  local _msg
  _msg="◉ sql.Null[T] 手書き block (ファイル: ${_bn}): 対象 project の nullable wrapper 経由 API を使う (project 側の canonical 規約を参照する)。検出行:
${_hits}"
  {
    printf '%s\n' "$_msg"
  } >&2
  GUARD_CLASS="Forbidden"
  return 0
}

_handle_edit_write_tool() {
  local INPUT="$1"
  local TOOL_NAME="$2"
  local SESSION_ID="$3"

  # MESSAGE なし: 毎 Edit 発火の静的 header は noise。下流 check が必要時のみ context を積む
  GUARD_CLASS="Boundary"

  # touchable_files allowlist guard (subagent context)
  # parent (user-prompt-submit hook) が developer-agent fire 時に
  # ~/.claude/state/touchable-<session>.txt へ allowlist を write。
  # state file が存在する間は Edit/Write/MultiEdit/NotebookEdit の
  # file_path を literal match で照合し、違反は exit 2 で block。
  # state file 不在 (= 通常 parent context) は noop。
  local _TF_PATH
  while IFS= read -r _TF_PATH; do
    [[ -z "$_TF_PATH" ]] && continue
    if ! _touchable_check "$SESSION_ID" "$_TF_PATH"; then
      local _TS_TF
      _TS_TF=$(date '+%Y-%m-%dT%H:%M:%S')
      mkdir -p "${HOME}/.claude/logs" 2>/dev/null || true
      _rotate_log_if_needed "${HOME}/.claude/logs/touchable-files-block.log"
      printf '%s | %s | %s | target=%s\n' \
        "$_TS_TF" "$SESSION_ID" "$TOOL_NAME" "$_TF_PATH" \
        >> "${HOME}/.claude/logs/touchable-files-block.log" 2>/dev/null || true
      echo "[touchable-files-block] ${TOOL_NAME} target '${_TF_PATH}' は touchable_files allowlist 外 (scope creep)。parent から受領した prompt §1 touchable_files を確認するか、allowlist 拡張を parent に escalate (status: partial + scope creep blocker)。opt-out: env CLAUDE_TOUCHABLE_ENFORCE=0" >&2
      exit 2
    fi
  done < <(jq -r '[.tool_input.file_path, (.tool_input.edits[]?.file_path)] | .[] | select(. != null and . != "")' <<< "$INPUT")

  # worktree session 内 main repo 直接 Edit guard
  # MultiEdit は top-level file_path に加え edits[].file_path も持つため両方検査する
  local _CWD_GUARD_PATH
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
  local _EDIT_FILE_PATH EDIT_CONTENT _OLD_STRING _NEW_STRING
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
  local _EDIT_PATH="$_EDIT_FILE_PATH"
  if [ -n "$_EDIT_PATH" ] && [[ "$_EDIT_PATH" == "$HOME/.claude/"* ]]; then
    local _REL_PATH="${_EDIT_PATH#"$HOME/.claude/"}"
    local _FIRST_COMP="${_REL_PATH%%/*}"
    case "$_FIRST_COMP" in
      commands|skills|hooks|agents|rules|guidelines|config|references|CLAUDE.md)
        local _REPO_PATH
        _REPO_PATH="$(_aitools_dir)/claude-code/$_REL_PATH"
        if [ -f "$_REPO_PATH" ]; then
          local _DIRECT_EDIT_WARN="⚠ 直編集警告: ${_EDIT_PATH} は sync.sh to-local で上書き消失します。代わりに repo source ${_REPO_PATH} を編集してください。"
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

  # AI定型語 block: code file も対象にする。ai-tools 配下等は NG 語 literal 保持のため除外する。
  # EDIT_CONTENT は @tsv 経由で改行が \n にエスケープされるため、渡す前に実改行へ戻す。
  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
    _run_ai_jargon_check "$_EDIT_FILE_PATH" "${EDIT_CONTENT//\\n/$'\n'}"
  fi

  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
    _check_target_sql_null_handwriting "$_EDIT_FILE_PATH" "${EDIT_CONTENT//\\n/$'\n'}"
  fi

  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
    _check_target_subtest_parallel "$_EDIT_FILE_PATH" "${EDIT_CONTENT//\\n/$'\n'}"
  fi

  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
    _check_ai_coined_terms "$_EDIT_FILE_PATH" "${EDIT_CONTENT//\\n/$'\n'}"
  fi

  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$_EDIT_FILE_PATH" ] && [ -n "$SESSION_ID" ]; then
    _check_edit_churn "$SESSION_ID" "$_EDIT_FILE_PATH"
  fi

  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$EDIT_CONTENT" ]; then
    _check_target_migration_safety "$_EDIT_FILE_PATH" "${EDIT_CONTENT//\\n/$'\n'}"
  fi

  # comment 体言止め block + comment 量 gate: 新規 comment 行だけを対象にする。
  # Write は disk と diff して新規行を絞り込み、diff 不能時は block を見送り既存 warn に委ねる。
  if [[ "$GUARD_CLASS" != "Forbidden" ]] && [ -n "$_EDIT_FILE_PATH" ] && [ -n "$EDIT_CONTENT" ]; then
    local _CS_CONTENT="${EDIT_CONTENT//\\n/$'\n'}"
    local _CS_TARGET=""
    if [[ "$TOOL_NAME" == "Write" ]]; then
      local _CS_NEW_ONLY
      if _CS_NEW_ONLY="$(run_comment_style_new_lines_for_write "$_EDIT_FILE_PATH" "$_CS_CONTENT")"; then
        _CS_TARGET="$_CS_NEW_ONLY"
      fi
    else
      _CS_TARGET="$_CS_CONTENT"
    fi
    if [ -n "$_CS_TARGET" ]; then
      run_comment_style_block_check "$_EDIT_FILE_PATH" "$_CS_TARGET"
      run_comment_quantity_gate_check "$_EDIT_FILE_PATH" "$_CS_TARGET"
    fi
  fi

  # Rename propagation detection (Edit tool only has old_string/new_string)
  if [ -n "$_OLD_STRING" ] && [ -n "$_NEW_STRING" ]; then
    detect_rename_propagation "$_OLD_STRING" "$_NEW_STRING" "$_EDIT_FILE_PATH"
  fi

  # Sonnet delegation declaration grep (CLAUDE.md Auto-Delegation "Edit/Write declaration rule")
  # fetch last 30 lines of latest assistant message from transcript_path; check for "Inline exception" / "Inline prohibited"
  # session+transcript mtime キャッシュ: transcript 更新がない場合は python3 fork を skip
  local _TRANSCRIPT
  _TRANSCRIPT=$(jq -r '.transcript_path // empty' <<< "$INPUT")
  if [ -n "$_TRANSCRIPT" ] && [ -f "$_TRANSCRIPT" ]; then
    local _TRANSCRIPT_MTIME
    _TRANSCRIPT_MTIME=$(portable_stat_mtime "$_TRANSCRIPT")
    local _TRANSCRIPT_CACHE_FLAG="/tmp/claude-transcript-decl-${SESSION_ID:-$$}-${_TRANSCRIPT_MTIME}"
    local _DECL_FOUND
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
      # session 1 回 dedup: 同一警告の毎 Edit/Write 再注入は token を浪費する (2026-07-16 実測)
      local _decl_today _DECL_WARN_FLAG
      printf -v _decl_today '%(%Y%m%d)T' -1
      _DECL_WARN_FLAG="/tmp/claude-decl-warn-$(_stable_session_key)-${_decl_today}"
      if [ ! -f "$_DECL_WARN_FLAG" ]; then
        : > "$_DECL_WARN_FLAG" 2>/dev/null || true
        local _DECL_WARN="⚠ Sonnet 委譲宣言抜け: Edit/Write 前に 'Inline exception (reason: ...)' か 'Inline prohibited (reason: ...)' を 1 行宣言 (throttle 等詳細: references/auto-delegation-detailed.md)"
        if [ -n "$ADDITIONAL_CONTEXT" ]; then
          ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_DECL_WARN}"
        else
          ADDITIONAL_CONTEXT="${_DECL_WARN}"
        fi
      fi
    fi
  fi

  # 書く系 tool: 今日の commit inject（writing 規約更新を最新規範で反映させる）
  _inject_today_commits

  # code comment 規範 inject: code file への comment 追加を検出したら digest を 1 session 1 回 inject
  _inject_code_comment_rules "$_EDIT_FILE_PATH" "$EDIT_CONTENT"
  fi  # end: cwd-guard Forbidden skip
}
