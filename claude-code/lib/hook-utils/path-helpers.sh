#!/bin/bash
# =============================================================================
# hook-utils / path-helpers module
# =============================================================================
if [[ "${_HOOK_UTILS_PATH_HELPERS_LOADED:-}" == "1" ]]; then
    return 0
fi
_HOOK_UTILS_PATH_HELPERS_LOADED=1

# git worktree の main リポジトリ絶対 path を解決する。
# linked worktree のときだけ main repo path を stdout へ出力し rc=0。
# worktree でない (通常 clone) / git 外なら stdout 空で rc=1 を返す。
# Usage: main_repo=$(_worktree_main_repo "/path/to/cwd") || return 0
_worktree_main_repo() {
  local target_dir="$1"
  [[ -z "${target_dir}" ]] && return 1

  # git-dir と common-dir を 1 コールで取得 (git fork を 2 → 1 に削減)。
  # 出力は 2 行 (1 行目=git-dir, 2 行目=common-dir)。
  local rp git_dir common_dir
  rp=$(git -C "${target_dir}" rev-parse --git-dir --git-common-dir 2>/dev/null) || return 1
  git_dir=$(printf '%s' "${rp}" | sed -n '1p')
  common_dir=$(printf '%s' "${rp}" | sed -n '2p')
  [[ -n "${git_dir}" && -n "${common_dir}" ]] || return 1

  # 相対パスなら絶対パスに変換
  [[ "${git_dir}" != /* ]] && git_dir="${target_dir}/${git_dir}"
  [[ "${common_dir}" != /* ]] && common_dir="${target_dir}/${common_dir}"

  # python3 でパス正規化を 1 コールで両方処理 (cd+pwd は chpwd フック等で余計な出力が混入する)
  local abs_git abs_common
  { read -r abs_git; read -r abs_common; } < <(python3 -c "import os,sys; [print(os.path.realpath(p)) for p in sys.argv[1:]]" "${git_dir}" "${common_dir}")

  # git-dir と common-dir が一致 = worktree でない
  [[ "${abs_git}" == "${abs_common}" ]] && return 1

  # メインリポジトリのパス = git-common-dirの親
  dirname "${abs_common}"
}

# linked worktree の親 org 階層 owner CLAUDE.md path を解決する。
# main repo の親 dir (= org 階層) の CLAUDE.md が実在すれば絶対 path を stdout、rc=0。
# worktree でない / owner CLAUDE.md 不在なら stdout 空で rc=1 を返す。
# linked worktree は親 dir 外にあり directory-based auto-load が効かないため、
# session-start hook がこの path で owner CLAUDE.md を読み context 注入するのに使う。
# Usage: owner=$(_resolve_worktree_owner_claude_md "/path/to/cwd") || return 0
_resolve_worktree_owner_claude_md() {
  local target_dir="$1"
  local main_repo owner_claude
  main_repo=$(_worktree_main_repo "${target_dir}") || return 1
  # org 階層 = main repo の親。owner CLAUDE.md はそこ直下の CLAUDE.md。
  owner_claude="$(dirname "${main_repo}")/CLAUDE.md"
  [[ -f "${owner_claude}" ]] || return 1
  printf '%s' "${owner_claude}"
}

# git worktreeのmemoryディレクトリをメインリポジトリにシンボリックリンク
# Usage: ensure_worktree_memory_link "/path/to/worktree"
ensure_worktree_memory_link() {
  local target_dir="$1"
  [[ -z "${target_dir}" ]] && return 0

  # メインリポジトリのパス (linked worktree のときのみ非空)
  local main_repo
  main_repo=$(_worktree_main_repo "${target_dir}") || return 0

  # パスをプロジェクトIDに変換（/ → -）
  local wt_id main_id
  wt_id=${target_dir//\//-}
  main_id=${main_repo//\//-}

  local projects_dir="${HOME}/.claude/projects"
  local wt_mem="${projects_dir}/${wt_id}/memory"
  local main_mem="${projects_dir}/${main_id}/memory"

  # 既にシンボリックリンクなら何もしない
  [[ -L "${wt_mem}" ]] && return 0

  # メインのmemoryディレクトリを確保
  mkdir -p "${main_mem}"
  mkdir -p "${projects_dir}/${wt_id}"

  # 既存memoryがあればメインに移動
  if [[ -d "${wt_mem}" ]]; then
    cp -rn "${wt_mem}/"* "${main_mem}/" 2>/dev/null || true
    rm -rf "${wt_mem}"
  fi

  ln -s "${main_mem}" "${wt_mem}"
}

# =============================================================================
# ISO8601 UTC timestamp → epoch 秒 変換関数 (クロスプラットフォーム)
# BSD (date -j) → GNU (date -d) の順に試行する。fractional 秒 (.225) / 末尾 Z は除去。
# 変換失敗の場合は stdout 空で rc=1 を返す。
# Usage: epoch=$(_iso8601_to_epoch "2026-06-12T01:02:03.000Z") || ...
# =============================================================================
_iso8601_to_epoch() {
  local ts="${1:-}"
  [[ -n "$ts" ]] || return 1
  local _trim="${ts%%.*}"  # .225Z → 除去
  _trim="${_trim%Z}"        # 末尾 Z 除去 (fractional なし場合)
  # jsonl timestamp は UTC。BSD は date -j -f、GNU は date -d で解釈
  TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$_trim" "+%s" 2>/dev/null \
    || TZ=UTC date -d "${_trim}Z" "+%s" 2>/dev/null \
    || return 1
}

# =============================================================================
# JSONL session epoch 解決関数
# session_id + cwd から JSONL path を導出し、先頭 timestamp を epoch 整数に変換して stdout へ出力する。
# JSONL 不在 / timestamp 不在 / date 変換失敗の場合は stdout 空で rc=1 を返す。
# Usage: epoch=$(_resolve_session_jsonl_epoch "$session_id" "$cwd") || return 0
# =============================================================================
_resolve_session_jsonl_epoch() {
  local session_id="$1"
  local cwd="$2"
  # slug 変換: / → -、. → -
  local _slug="${cwd//\//-}"
  _slug="${_slug//\./-}"
  local _JSONL="${HOME}/.claude/projects/${_slug}/${session_id}.jsonl"
  [[ -f "$_JSONL" ]] || return 1
  local _TS_RAW
  _TS_RAW=$(head -20 "$_JSONL" 2>/dev/null | grep -m1 '"timestamp":"' | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4) || true
  [[ -n "$_TS_RAW" ]] || return 1
  _iso8601_to_epoch "$_TS_RAW" || return 1
}

# =============================================================================
# ai-tools repo path helper
# sync.sh to-local が記録する ~/.claude/.ai-tools-root を最優先で使い、
# symlink (~/ai-tools/) と ghq 実 path を fallback として OR 判定する。
# clone 先が機体ごとに違う Mac でも block / path 解決が正常動作する。
# =============================================================================

# repo root 記録 file の path を返す (test 用に AITOOLS_ROOT_FILE で override 可)。
_aitools_root_file() {
  printf '%s' "${AITOOLS_ROOT_FILE:-$HOME/.claude/.ai-tools-root}"
}

# 記録済み repo root を返す。claude-code/ を含む実在 dir のみ有効とし、
# 不在・無効 (repo 移動後の stale 記録等) なら 1 を返す。
_aitools_recorded_root() {
  local f root
  f="$(_aitools_root_file)"
  [[ -f "$f" ]] || return 1
  IFS= read -r root < "$f" || true
  [[ -n "$root" && -d "$root/claude-code" ]] || return 1
  printf '%s' "$root"
}

# ai-tools repo の path prefix list を改行区切りで出力する。
# 記録済み root → symlink → ghq 実 path の順で返す。
_aitools_prefixes() {
  local recorded
  if recorded="$(_aitools_recorded_root)"; then
    printf '%s\n' "${recorded}/"
  fi
  printf '%s\n' \
    "$HOME/ai-tools/" \
    "$HOME/ghq/github.com/DaichiHoshina/ai-tools/"
}

# 与えられた path が ai-tools 配下かどうかを判定する。
# 戻り値: 0=ai-tools 配下 / 1=配下でない
# usage: _is_aitools_path "$path"
_is_aitools_path() {
  local p="$1"
  local prefix
  while IFS= read -r prefix; do
    # prefix は末尾 / 付き。repo root ちょうど (末尾 / なし) の cwd も配下と判定する
    [[ "$p" == "${prefix}"* || "${p}/" == "$prefix" ]] && return 0
  done < <(_aitools_prefixes)
  return 1
}

# 与えられた path が Claude Code auto-memory dir かどうかを判定する。
# 対象 dir:
#   - ~/.claude/projects/*/memory/    (session-bound auto-memory)
#   - ~/.claude/agent-memory/          (subagent 共通 memory 出力先)
# AI 自己分析の生記録 (work-context / writing_failure / pending-improvements 等) は
# 外向き prose 規則の対象外なので、jp-quality / NG 語 / 連続漢字 hook で skip 用に使う。
# 戻り値: 0=auto-memory 配下 / 1=配下でない
# usage: _is_auto_memory_path "$path"
_is_auto_memory_path() {
  local p="$1"
  [[ "$p" == "$HOME/.claude/projects/"*"/memory/"* ]] && return 0
  [[ "$p" == "$HOME/.claude/agent-memory/"* ]] && return 0
  return 1
}

# 与えられた path が /plan コマンドの plan 保存 dir かどうかを判定する。
# 対象 dir:
#   - ~/.claude/plans/   (`/plan` コマンドの設計書出力先)
# plan は AI 自身の作業計画 (要件・Architecture・Phase 分解) であり、
# 外向き prose ではないため jp-quality / NG 語 hook の skip 対象にする。
# 戻り値: 0=plans 配下 / 1=配下でない
# usage: _is_plans_path "$path"
_is_plans_path() {
  local p="$1"
  [[ "$p" == "$HOME/.claude/plans/"* ]] && return 0
  return 1
}

# memory file 判定: NG-DICTIONARY / private-name 等の文体 block を skip する対象 path
# canonical: CLAUDE.md § Memory write target + user 指示 (2026-06-30): memory save 時に NG word 検出を skip する
# 対象:
#   - ~/ai-tools/memory/         (ai-tools repo の memory write 先)
#   - ~/.claude/projects/*/memory/  (Claude Code auto-memory)
#   - ~/.claude/agent-memory/    (agent 共有 memory)
#   - */.serena/memories/        (Serena 旧 memory、書込自体は別 hook で block)
# usage: _is_memory_path "$path"
_is_memory_path() {
  local p="$1"
  [[ "$p" == "$HOME/ai-tools/memory/"* ]] && return 0
  [[ "$p" == "$HOME/ghq/"*"/memory/"* ]] && return 0
  [[ "$p" == "$HOME/.claude/projects/"*"/memory/"* ]] && return 0
  [[ "$p" == "$HOME/.claude/agent-memory/"* ]] && return 0
  [[ "$p" == *"/.serena/memories/"* ]] && return 0
  return 1
}

# 与えられた path が ~/.claude/references-private/ 配下かどうかを判定する。
# references-private は user 管理の private メモ dir。外向き prose 規則の対象外とする。
# 戻り値: 0=references-private 配下 / 1=配下でない
# usage: _is_references_private_path "$path"
_is_references_private_path() {
  local p="$1"
  [[ "$p" == "$HOME/.claude/references-private/"* ]] && return 0
  return 1
}

# ai-tools repo 相対 path を取得する (prefix 除去後)。
# どの prefix にも match しない場合は空文字を出力して 1 を返す。
# usage: rel=$(_aitools_relpath "$path")
_aitools_relpath() {
  local p="$1"
  local prefix
  while IFS= read -r prefix; do
    if [[ "$p" == "${prefix}"* ]]; then
      printf '%s' "${p#"${prefix}"}"
      return 0
    fi
  done < <(_aitools_prefixes)
  return 1
}

# 実在する ai-tools repo dir を 1 つ返す
# (記録済み root 優先 → ghq 実 path → symlink fallback)。
# いずれも存在しなければ ghq canonical path を返す (呼出側で -d チェック想定)。
# usage: dir=$(_aitools_dir)
_aitools_dir() {
  local recorded ghq symlink
  ghq="$HOME/ghq/github.com/DaichiHoshina/ai-tools"
  symlink="$HOME/ai-tools"
  if recorded="$(_aitools_recorded_root)"; then
    printf '%s' "$recorded"
  elif [[ -d "$ghq" ]]; then
    printf '%s' "$ghq"
  elif [[ -d "$symlink" ]]; then
    printf '%s' "$symlink"
  else
    printf '%s' "$ghq"
  fi
}
