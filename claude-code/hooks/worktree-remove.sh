#!/usr/bin/env bash
# WorktreeRemove Hook - worktree 削除時に ~/.claude/projects/<sanitized> も掃除
# 安全策: wt パス形式 (/private/tmp/wt-* or *-wt-*) かつ memory 空 (or symlink) の場合のみ削除

set -euo pipefail
trap '' PIPE
exec 2>>"$HOME/.claude/logs/hook-errors.log"

INPUT=$(cat)
WT_PATH=$(jq -r '.worktree_path // .cwd // .workspace.current_dir // empty' <<< "$INPUT")

[[ -z "$WT_PATH" ]] && exit 0

case "$WT_PATH" in
  */wt-*|*-wt-*) ;;
  *) exit 0 ;;
esac

SANITIZED="${WT_PATH//\//-}"
PROJECT_DIR="$HOME/.claude/projects/${SANITIZED}"

[[ ! -d "$PROJECT_DIR" ]] && exit 0

_jsonl_files=( "$PROJECT_DIR"/*.jsonl )
[[ -e "${_jsonl_files[0]}" ]] && JSONL_COUNT=${#_jsonl_files[@]} || JSONL_COUNT=0
_mem_files=( "$PROJECT_DIR/memory"/*.md )
[[ -e "${_mem_files[0]}" ]] && MEM_REAL=${#_mem_files[@]} || MEM_REAL=0

if [[ "$JSONL_COUNT" = "0" && "$MEM_REAL" = "0" ]]; then
  if [[ -L "$PROJECT_DIR/memory" ]]; then
    rm "$PROJECT_DIR/memory"
  fi
  rmdir "$PROJECT_DIR/memory" 2>/dev/null || true
  rmdir "$PROJECT_DIR" 2>/dev/null && \
    echo "[worktree-remove] cleaned: $PROJECT_DIR" >&2
fi

exit 0
