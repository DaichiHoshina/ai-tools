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

  # .sh / .bats / hook 自身 / tests/ は除外 (実装例を含む設定 file での誤爆防止)
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
