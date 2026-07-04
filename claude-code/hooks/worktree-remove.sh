#!/usr/bin/env bash
# WorktreeRemove Hook
# 役割:
#   1. worktree 削除後に ~/.claude/projects/<sanitized> を掃除する
#   2. dangling cwd 問題の warn を systemMessage で Claude に通知し
#      cd <CLAUDE_PROJECT_DIR> を促す
#      (Claude Code spec: hook stdout は systemMessage として Claude に注入される)
# 安全策: wt パス形式 (/private/tmp/wt-* / *-wt-* / ~/ghq/worktrees/*) かつ memory 空 (or symlink) の場合のみ削除

set -euo pipefail
trap '' PIPE
exec 2>>"$HOME/.claude/logs/hook-errors.log"

LOG="$HOME/.claude/logs/worktree-cleanup.log"
mkdir -p "$(dirname "$LOG")"

# jq 必須（hook-utils.sh 非依存のため inline check）
if ! command -v jq &>/dev/null; then
  echo '{"error": "jq not installed. Please run: brew install jq (macOS) / apt install jq (Ubuntu)"}' >&2
  exit 1
fi

INPUT=$(cat)
WT_PATH=$(jq -r '.worktree_path // .cwd // .workspace.current_dir // empty' <<< "$INPUT")

# WT_PATH が空の場合でも dangling cwd warn は発行する
if [[ -z "$WT_PATH" ]]; then
  # worktree_path が取れない場合: warn のみ出力して終了
  _PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$HOME}"
  printf '%s [worktree-remove] worktree_path empty; cwd may be dangling. cwd reset to: %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$_PROJECT_ROOT" >> "$LOG"
  jq -n --arg msg "[WorktreeRemove] Worktree was removed. Your working directory may be dangling. Run: cd ${_PROJECT_ROOT}" \
    '{systemMessage: $msg}'
  exit 0
fi

# wt パターン以外は掃除対象外だが warn は発行する
case "$WT_PATH" in
  */wt-*|*-wt-*|*/ghq/worktrees/*)
    _IS_WT=1
    ;;
  *)
    _IS_WT=0
    ;;
esac

# dangling cwd warn を出力 (常に)
_PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$HOME}"
printf '%s [worktree-remove] removed: %s -> cd to: %s\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" "$WT_PATH" "$_PROJECT_ROOT" >> "$LOG"

# --- ~/.claude/projects/<sanitized> の掃除 (wt パターンのみ) ---
if [[ "$_IS_WT" = "1" ]]; then
  SANITIZED="${WT_PATH//\//-}"
  PROJECT_DIR="$HOME/.claude/projects/${SANITIZED}"

  if [[ -d "$PROJECT_DIR" ]]; then
    _jsonl_files=( "$PROJECT_DIR"/*.jsonl )
    [[ -e "${_jsonl_files[0]}" ]] && JSONL_COUNT=${#_jsonl_files[@]} || JSONL_COUNT=0
    _mem_files=( "$PROJECT_DIR/memory"/*.md )
    [[ -e "${_mem_files[0]}" ]] && MEM_REAL=${#_mem_files[@]} || MEM_REAL=0

    if [[ "$JSONL_COUNT" = "0" && "$MEM_REAL" = "0" ]]; then
      if [[ -L "$PROJECT_DIR/memory" ]]; then
        rm "$PROJECT_DIR/memory"
      fi
      rmdir "$PROJECT_DIR/memory" 2>/dev/null || true
      if rmdir "$PROJECT_DIR" 2>/dev/null; then
        printf '%s [worktree-remove] cleaned project dir: %s\n' \
          "$(date '+%Y-%m-%d %H:%M:%S')" "$PROJECT_DIR" >> "$LOG"
      fi
    fi
  fi
fi

# systemMessage で Claude に cwd reset を促す
jq -n --arg wt "$WT_PATH" --arg root "$_PROJECT_ROOT" \
  '{systemMessage: ("Worktree removed: " + $wt + ". Your cwd may be dangling. Run: cd " + $root)}'

exit 0
