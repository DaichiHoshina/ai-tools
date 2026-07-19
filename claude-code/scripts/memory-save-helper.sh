#!/usr/bin/env bash
# memory-save-helper.sh — /memory-save command の補助 script
#
# 機能:
#   1. resolve-dir         — save 先 dir を解決して echo (default: ~/ai-tools/memory)
#   1b. resolve-permanent-dir — 恒久 file 本文を stdin で受け、Tier 判定で保存先を echo
#       (snkrdunk 固有名詞含む → references-private/snkr-knowledge、無 → ai-tools/memory)
#   2. list-today          — 同日 work-context-YYYYMMDD-*.md を改行区切りで列挙
#   3. resolve-name        — name collision 回避 (-2/-3 suffix 付与)
#   4. update-index        — MEMORY.md 先頭に `- YYYY-MM-DD [desc](file.md) — hook` を追記 (重複 dedup)
#   5. append-clear-line   — /memory-save clear 用、MEMORY.md に `- YYYY-MM-DD [clear] <topic> — <summary> (commit: <hash>)` を prepend (dedup なし)
#   6. extract-issue-key   — 現 branch 名から issue key (`PROJ-123` / `#123` / `issue-123`) を抽出して echo、無ければ空
#   7. find-topic-match    — 同日 work-context-*-<topic>.md を exact suffix match で filter (issue key prefix は無視)
#   8. prepare / 9. finalize — 前段 metadata の一括返却と index 更新 + pbcopy 統合で往復を減らす
#
# 注意: 本 script は AI 経由の Write/Edit ばらつきを排除するための deterministic helper。
#       memory file 本体の write は /memory-save command (AI 側) が担当する。
set -euo pipefail

# save 先 dir 解決ルール (canonical: commands/memory-save.md § "Save target dir"):
#   1. $MEMORY_SAVE_DIR が set されていればそれを使う (override、test 用)
#   2. cwd の repo origin が ~/ghq/github.com/<org>/ 配下で <org-root>/memory/ が存在すれば
#      <org-root>/memory/<repo> (org 作業 memory、2026-07-16 分離)。worktree も origin URL で同判定
#   3. それ以外は ${HOME}/ai-tools/memory (3 tool 共有 SoT、汎用知見)
_resolve_memory_dir() {
  if [ -n "${MEMORY_SAVE_DIR:-}" ]; then
    printf '%s\n' "$MEMORY_SAVE_DIR"
    return 0
  fi
  local origin org repo org_mem
  origin=$(git config --get remote.origin.url 2>/dev/null || true)
  if [ -n "$origin" ]; then
    org=$(printf '%s' "$origin" | sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##' | cut -d/ -f1)
    repo=$(printf '%s' "$origin" | sed -E 's#^(git@[^:]+:|ssh://[^/]+/|https?://[^/]+/)##; s#\.git$##' | cut -d/ -f2)
    org_mem="${HOME}/ghq/github.com/${org}/memory"
    if [ -n "$org" ] && [ -n "$repo" ] && [ -d "$org_mem" ]; then
      mkdir -p "${org_mem}/${repo}"
      printf '%s\n' "${org_mem}/${repo}"
      return 0
    fi
  fi
  printf '%s\n' "${HOME}/ai-tools/memory"
}

# private 退避先 (Tier B = project 固有知識、on-demand read の raw 保管)。
# canonical: references/memory-relocation-pattern.md / 2026-07-09 memory-consolidation。
# $MEMORY_PRIVATE_DIR override 可 (test 用)。
_resolve_private_dir() {
  if [ -n "${MEMORY_PRIVATE_DIR:-}" ]; then
    printf '%s\n' "$MEMORY_PRIVATE_DIR"
    return 0
  fi
  printf '%s\n' "${HOME}/.claude/references-private/snkr-knowledge"
}

# social-hit term の canonical rule file。term literal は複製せず本 file から抽出する
# (no-derived-literals 遵守)。$MEMORY_SOCIAL_HIT_RULE override 可 (test 用)。
_social_hit_rule_file() {
  printf '%s\n' "${MEMORY_SOCIAL_HIT_RULE:-${HOME}/.claude/rules/public-repo-private-data-block.md}"
}

# rule file の「**social-hit (block)**: 語1 / 語2 / ...」行から term を 1 行 1 語で抽出。
# hooks/lib/jp-quality/term-extraction.sh:_extract_term_list と同じ抽出規則
# (hook lib は hook 依存変数が絡むため source せず抽出ロジックのみ移植)。
_memory_social_hit_terms() {
  local rule; rule=$(_social_hit_rule_file)
  [ -f "$rule" ] || return 0
  local line; line=$(grep -m1 '^\*\*social-hit (block)\*\*:' "$rule" 2>/dev/null || true)
  [ -z "$line" ] && return 0
  local body="${line#*: }"
  printf '%s' "$body" | tr '/' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true
}

# 恒久 file (feedback/project) の保存先を Tier 判定で解決する。
# 引数: file 本文 (heredoc / cat で渡す) を stdin から読む。
# social-hit term を 1 つでも含めば private dir (Tier B)、含まなければ ai-tools/memory (Tier A) を echo。
# canonical: commands/memory-save.md § exit post-processing (Tier B routing)。
cmd_resolve_permanent_dir() {
  local content; content=$(cat)
  local ai_dir; ai_dir=$(_resolve_memory_dir)
  # org 作業 memory (git 管理外の private dir) が dest なら social-hit 退避は不要。
  # path pattern で限定し、MEMORY_SAVE_DIR override (test 等) では従来どおり退避判定する
  case "$ai_dir" in
    "${HOME}"/ghq/github.com/*/memory/*)
      printf '%s\n' "$ai_dir"
      return 0
      ;;
  esac
  local term
  while IFS= read -r term; do
    [ -z "$term" ] && continue
    if printf '%s' "$content" | grep -qiF -- "$term"; then
      _resolve_private_dir
      return 0
    fi
  done < <(_memory_social_hit_terms)
  printf '%s\n' "$ai_dir"
}

MEMORY_DIR=$(_resolve_memory_dir)
INDEX_FILE="${MEMORY_DIR}/MEMORY.md"

_today() { date +%Y%m%d; }
_today_iso() { date +%Y-%m-%d; }

cmd_resolve_dir() {
  printf '%s\n' "$MEMORY_DIR"
}

cmd_list_today() {
  local today; today=$(_today)
  [ -d "$MEMORY_DIR" ] || { return 0; }
  find "$MEMORY_DIR" -maxdepth 1 -name "work-context-${today}-*.md" -type f 2>/dev/null | sort
}

cmd_resolve_name() {
  local base="${1:?base name required}"
  local candidate="$base" n=2
  while [ -e "${MEMORY_DIR}/${candidate}.md" ]; do
    candidate="${base}-${n}"
    n=$((n + 1))
  done
  printf '%s\n' "$candidate"
}

cmd_update_index() {
  local name="${1:?name required}" desc="${2:?description required}" hook="${3:-}"
  mkdir -p "$MEMORY_DIR"
  local file="${name}.md" date_iso; date_iso=$(_today_iso)
  local line
  if [ -n "$hook" ]; then
    line="- \`${date_iso}\` [${desc}](${file}) — ${hook}"
  else
    line="- \`${date_iso}\` [${desc}](${file})"
  fi

  if [ ! -f "$INDEX_FILE" ]; then
    printf '%s\n' "$line" > "$INDEX_FILE"
    return 0
  fi

  # 既存 entry に同 file への link あれば差し替え (dedup)
  if grep -Fq "](${file})" "$INDEX_FILE"; then
    # 旧行削除 → 先頭に新行
    local tmp; tmp=$(mktemp)
    grep -Fv "](${file})" "$INDEX_FILE" > "$tmp" || true
    { printf '%s\n' "$line"; cat "$tmp"; } > "$INDEX_FILE"
    rm -f "$tmp"
  else
    # 先頭に prepend
    local tmp; tmp=$(mktemp)
    { printf '%s\n' "$line"; cat "$INDEX_FILE"; } > "$tmp"
    mv "$tmp" "$INDEX_FILE"
  fi
}

# /memory-save clear 専用: 個別 file を作らず MEMORY.md に 1 行 entry を prepend する。
# canonical: commands/memory-save.md § "clear" post-processing (2026-06-30 改訂: 肥大化対策で file なしに変更)
# format: - `YYYY-MM-DD` [clear] <topic> — <1 行 summary> (commit: <hash>)
cmd_append_clear_line() {
  local topic="${1:?topic required}" summary="${2:?summary required}" commit="${3:-}"
  mkdir -p "$MEMORY_DIR"
  local date_iso; date_iso=$(_today_iso)
  local line
  if [ -n "$commit" ]; then
    line="- \`${date_iso}\` [clear] ${topic} — ${summary} (commit: ${commit})"
  else
    line="- \`${date_iso}\` [clear] ${topic} — ${summary}"
  fi

  if [ ! -f "$INDEX_FILE" ]; then
    printf '%s\n' "$line" > "$INDEX_FILE"
    return 0
  fi

  # clear entry は dedup しない (同日複数 clear save を残す)。先頭 prepend。
  local tmp; tmp=$(mktemp)
  { printf '%s\n' "$line"; cat "$INDEX_FILE"; } > "$tmp"
  mv "$tmp" "$INDEX_FILE"

  # 肥大防止: [clear] entry は最新 CLEAR_LINE_MAX 件のみ保持する。
  # 超過分の削除は index からのみで、同 topic の work-context 個別 file は残るため情報損失なし
  local max="${CLEAR_LINE_MAX:-10}"
  local tmp2; tmp2=$(mktemp)
  awk -v max="$max" '/^- `[0-9]{4}-[0-9]{2}-[0-9]{2}` \[clear\] / { c++; if (c > max) next } { print }' \
    "$INDEX_FILE" > "$tmp2" && mv "$tmp2" "$INDEX_FILE"
}

# 現 branch 名から issue key を抽出。優先順:
#   1. `PROJ-123` 形式 (JIRA / Linear / Shortcut 等の大文字英字 + 数字)
#   2. `#123` 形式 (GitHub issue 参照、`123` を返す)
#   3. `issue-123` / `issue/123` 形式
# 引数で branch 名を明示可 (test 用)。省略時は `git branch --show-current`。
# 抽出できなければ空を返し exit 0。
# canonical: commands/memory-save.md § "Auto issue key suffix"
cmd_extract_issue_key() {
  local branch="${1:-}"
  if [ -z "$branch" ]; then
    branch=$(git -C "$(pwd)" branch --show-current 2>/dev/null || echo "")
  fi
  [ -z "$branch" ] && return 0
  # 1. PROJ-123 (JIRA/Linear 形式) — 2 文字以上の大文字英字 + `-` + 数字
  if [[ "$branch" =~ ([A-Z][A-Z0-9]+-[0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  # 2. #123 形式
  if [[ "$branch" =~ \#([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  # 3. issue-123 / issue/123 形式 (大文字小文字問わず)
  if [[ "$branch" =~ [Ii]ssue[-/_]([0-9]+) ]]; then
    printf 'issue-%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 0
}

# 同日 work-context-*-<topic>.md を exact suffix match で filter する。
# issue key prefix (`PROJ-123` 等) を無視して `<topic>` 部分のみで match するので、
# branch 切替後も同 topic を merge 対象として拾える。
# canonical: commands/memory-save.md § Flow (auto merge/new mode) step 1
cmd_find_topic_match() {
  local topic="${1:?topic required}"
  local today; today=$(_today)
  [ -d "$MEMORY_DIR" ] || return 0
  find "$MEMORY_DIR" -maxdepth 1 -name "work-context-${today}-*-${topic}.md" -o -name "work-context-${today}-${topic}.md" 2>/dev/null | sort
}

# MEMORY.md 先頭から `[clear] <topic>` entry を 1 件返す (直近優先)。
# clear は個別 file を作らないので、reload の名指し経路が topic から直近 state を
# 拾うための source になる。見つからなければ空を返し exit 0。
# canonical: commands/reload.md § 名指し fast path (clear entry 経路)
cmd_find_clear_entry() {
  local topic="${1:?topic required}"
  [ -f "$INDEX_FILE" ] || return 0
  grep -m1 -F -- "[clear] ${topic} " "$INDEX_FILE" 2>/dev/null || return 0
}

# `/reload <topic>` を clipboard へコピーする。pbcopy 不在環境 (Linux/CI) は
# silent skip し exit 0 (fail させない)。実際にコピーしたコマンド文字列を stdout に返す。
# canonical: commands/memory-save.md § clear post-processing
cmd_pbcopy_reload() {
  local topic="${1:?topic required}"
  local cmd="/reload ${topic}"
  if command -v pbcopy >/dev/null 2>&1; then
    printf '%s' "$cmd" | pbcopy 2>/dev/null || true
  fi
  printf '%s\n' "$cmd"
}

# /memory-save 前段の dir / worktree / issue key / merge-new 判定を 1 call に統合して往復を減らす。
# merge_target 非空なら最古 file へ merge し、空なら new_name を使う (第 2 引数は test 用の branch 明示)。
cmd_prepare() {
  local topic="${1:?topic required}" branch_override="${2:-}"
  local today today_iso; today=$(_today); today_iso=$(_today_iso)
  local worktree="" branch="" toplevel
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$toplevel" ]; then
    branch=$(git branch --show-current 2>/dev/null || true)
    if [ -f "${toplevel}/.git" ]; then
      worktree="$toplevel"
    fi
  fi
  local issue_key; issue_key=$(cmd_extract_issue_key "$branch_override")
  local merge_target new_name=""
  merge_target=$(cmd_find_topic_match "$topic" | head -1)
  if [ -z "$merge_target" ]; then
    local base="work-context-${today}-${topic}"
    if [ -n "$issue_key" ]; then
      base="work-context-${today}-${issue_key}-${topic}"
    fi
    new_name=$(cmd_resolve_name "$base")
  fi
  printf 'dir=%s\n' "$MEMORY_DIR"
  printf 'today=%s\n' "$today"
  printf 'today_iso=%s\n' "$today_iso"
  printf 'worktree=%s\n' "$worktree"
  printf 'branch=%s\n' "$branch"
  printf 'issue_key=%s\n' "$issue_key"
  printf 'merge_target=%s\n' "$merge_target"
  printf 'new_name=%s\n' "$new_name"
}

# index 更新と pbcopy-reload を 1 call に束ねて往復を減らす。stdout は `/reload <topic>` の 1 行だ。
# mode は clear (append-clear-line 相当) と topic (update-index 相当) の 2 系統を持つ。
cmd_finalize() {
  local mode="${1:?mode (clear|topic) required}"; shift
  case "$mode" in
    clear)
      local topic="${1:?topic required}" summary="${2:?summary required}" commit="${3:-}"
      cmd_append_clear_line "$topic" "$summary" "$commit"
      cmd_pbcopy_reload "$topic"
      ;;
    topic)
      local name="${1:?name required}" topic="${2:?topic required}" desc="${3:?description required}" hook="${4:-}"
      cmd_update_index "$name" "$desc" "$hook"
      cmd_pbcopy_reload "$topic"
      ;;
    *)
      printf 'unknown finalize mode: %s\n' "$mode" >&2
      return 1
      ;;
  esac
}

usage() {
  sed -n '2,16p' "$0"
  exit "${1:-0}"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    resolve-dir)   cmd_resolve_dir "$@" ;;
    resolve-permanent-dir) cmd_resolve_permanent_dir "$@" ;;
    list-today)    cmd_list_today "$@" ;;
    resolve-name)  cmd_resolve_name "$@" ;;
    update-index)  cmd_update_index "$@" ;;
    append-clear-line) cmd_append_clear_line "$@" ;;
    extract-issue-key) cmd_extract_issue_key "$@" ;;
    find-topic-match)  cmd_find_topic_match "$@" ;;
    find-clear-entry)  cmd_find_clear_entry "$@" ;;
    pbcopy-reload)     cmd_pbcopy_reload "$@" ;;
    prepare)           cmd_prepare "$@" ;;
    finalize)          cmd_finalize "$@" ;;
    -h|--help|help|"") usage 0 ;;
    *) printf 'unknown subcommand: %s\n' "$sub" >&2; usage 1 ;;
  esac
}

main "$@"
