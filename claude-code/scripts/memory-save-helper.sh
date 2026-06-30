#!/usr/bin/env bash
# memory-save-helper.sh — /memory-save command の補助 script
#
# 機能:
#   1. resolve-dir         — save 先 dir を解決して echo (default: ~/ai-tools/memory)
#   2. list-today          — 同日 work-context-YYYYMMDD-*.md を改行区切りで列挙
#   3. resolve-name        — name collision 回避 (-2/-3 suffix 付与)
#   4. update-index        — MEMORY.md 先頭に `- YYYY-MM-DD [desc](file.md) — hook` を追記 (重複 dedup)
#   5. append-clear-line   — /memory-save clear 用、個別 file なしで MEMORY.md に `- YYYY-MM-DD [clear] <topic> — <summary> (commit: <hash>)` を prepend (dedup なし)
#
# 注意: 本 script は AI 経由の Write/Edit ばらつきを排除するための deterministic helper。
#       memory file 本体の write は /memory-save command (AI 側) が担当する。
set -euo pipefail

# save 先 dir 解決ルール (canonical: commands/memory-save.md § "Save target dir"):
#   1. $MEMORY_SAVE_DIR が set されていればそれを使う (override)
#   2. cwd の git toplevel が ai-tools repo → ${HOME}/ai-tools/memory
#   3. cwd の git toplevel が他 repo で `<repo-parent>/memory/` dir が存在 → repo-local memory
#      sub-project 識別子は basename($(git rev-parse --show-toplevel)) で 1 段ネスト
#      (例: ~/ghq/github.com/<org>/<repo> 配下なら ~/ghq/github.com/<org>/memory/<repo>)
#   4. 上記いずれも該当しない → fallback ${HOME}/ai-tools/memory
_resolve_memory_dir() {
  if [ -n "${MEMORY_SAVE_DIR:-}" ]; then
    printf '%s\n' "$MEMORY_SAVE_DIR"
    return 0
  fi
  local toplevel
  toplevel=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -z "$toplevel" ]; then
    printf '%s\n' "${HOME}/ai-tools/memory"
    return 0
  fi
  case "$toplevel" in
    "${HOME}/ai-tools"|"${HOME}/ai-tools/"*)
      printf '%s\n' "${HOME}/ai-tools/memory"
      return 0
      ;;
  esac
  # repo-local memory dir: <repo-parent>/memory/<repo-basename>
  local parent repo_base
  parent=$(dirname "$toplevel")
  repo_base=$(basename "$toplevel")
  if [ -d "${parent}/memory" ]; then
    printf '%s\n' "${parent}/memory/${repo_base}"
    return 0
  fi
  printf '%s\n' "${HOME}/ai-tools/memory"
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
}

usage() {
  sed -n '2,15p' "$0"
  exit "${1:-0}"
}

main() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    resolve-dir)   cmd_resolve_dir "$@" ;;
    list-today)    cmd_list_today "$@" ;;
    resolve-name)  cmd_resolve_name "$@" ;;
    update-index)  cmd_update_index "$@" ;;
    append-clear-line) cmd_append_clear_line "$@" ;;
    -h|--help|help|"") usage 0 ;;
    *) printf 'unknown subcommand: %s\n' "$sub" >&2; usage 1 ;;
  esac
}

main "$@"
