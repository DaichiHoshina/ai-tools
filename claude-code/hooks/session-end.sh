#!/usr/bin/env bash
# SessionEnd Hook - セッション統計ログ保存（簡素化版）

set -euo pipefail

# Claude Code 本体が stdout を閉じた状態で発火するため、echo の broken pipe が
# hook-errors.log を汚染する。SIGPIPE を無視して書き込み失敗を静かに扱う。
trap '' PIPE

exec 2>>"$HOME/.claude/logs/hook-errors.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# JSON入力を読み込む
INPUT=$(cat)

# セッション情報を取得（jq 1回で全フィールド抽出）
IFS=$'\t' read -r SESSION_ID PROJECT_DIR TOTAL_TOKENS TOTAL_MESSAGES DURATION _MODEL _GIT_BRANCH _INPUT_TOKENS _CACHE_READ _CACHE_WRITE _OUTPUT_TOKENS < <(
  extract_json_fields "$INPUT" \
    '.session_id // "unknown"' \
    '.workspace.current_dir // "."' \
    '.total_tokens // 0' \
    '.total_messages // 0' \
    '.duration // 0' \
    '.model // "unknown"' \
    '.git_branch // ""' \
    '.input_tokens // 0' \
    '.cache_read_tokens // 0' \
    '.cache_write_tokens // 0' \
    '.output_tokens // 0'
)
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${SESSION_ID}}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# ログ保存
LOG_DIR="$HOME/.claude/session-logs"
mkdir -p "$LOG_DIR"
printf -v _LOG_DATE '%(%Y%m%d)T' -1
LOG_FILE="$LOG_DIR/${_LOG_DATE}.log"

# ローテーション（7日超削除）をバックグラウンドへ
find "$LOG_DIR" -type f -mtime +7 -delete 2>/dev/null &

# ログ追記
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SESSION_ID | $PROJECT_NAME | msg:$TOTAL_MESSAGES | tok:$TOTAL_TOKENS | ${DURATION}s" >> "$LOG_FILE"

# --- Analytics記録をバックグラウンドへ ---
(
  _LIB_DIR="${SCRIPT_DIR}/../lib"
  if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"

    # session-init-timing.log から当セッションの init_duration_ms を取得
    _TIMING_LOG="${HOME}/.claude/logs/session-init-timing.log"
    _INIT_DURATION_MS=0
    if [[ -f "${_TIMING_LOG}" ]]; then
      _TIMING_LINE=$(grep "session_id=${SESSION_ID} " "${_TIMING_LOG}" 2>/dev/null | tail -n 1 || true)
      if [[ -n "${_TIMING_LINE}" ]]; then
        _EXTRACTED=$(echo "${_TIMING_LINE}" | grep -o 'duration_ms=[0-9]*' | cut -d= -f2 || true)
        [[ "${_EXTRACTED}" =~ ^[0-9]+$ ]] && _INIT_DURATION_MS="${_EXTRACTED}"
      fi
    fi

    analytics_insert_session "$SESSION_ID" "$PROJECT_NAME" "$_MODEL" "$_GIT_BRANCH" \
        "$_INPUT_TOKENS" "$_CACHE_READ" "$_CACHE_WRITE" "$_OUTPUT_TOKENS" "$TOTAL_MESSAGES" "$DURATION" \
        "$_INIT_DURATION_MS" 2>/dev/null || true
    analytics_cleanup_old_records 90 || true
  fi
) 2>/dev/null &

# --- hook state file purge（2日以上前の stale file を削除）---
# 対象: 本 repo の hook 群が ~/.claude/logs/ 下に作る 6 種 state file
# mtime +2 (48h超) のみ削除、warn-only (exit 0 維持)
# 24h 超 session で当日 file を誤削除するリスクを回避するため mtime +2 を採用
(
  _LOGS_DIR="${HOME}/.claude/logs"
  _purged=0
  STATE_FILE_PATTERNS=(
    ".session-split-warned-*"
    ".large-repo-edit-count-*"
    ".delegation-warned-*"
    ".agent-fire-count-*"
    ".agent-fire-lastts-*"
    ".sequential-fire-warned-*"
  )
  for _pat in "${STATE_FILE_PATTERNS[@]}"; do
    while IFS= read -r -d '' _f; do
      rm -f -- "${_f}" 2>/dev/null && _purged=$(( _purged + 1 ))
    done < <(find "${_LOGS_DIR}" -maxdepth 1 -name "${_pat}" -type f -mtime +2 -print0 2>/dev/null)
  done
  if [[ "${_purged}" -gt 0 ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] session-end: purged ${_purged} stale state file(s)" \
      >> "${_LOGS_DIR}/hook-errors.log" 2>/dev/null || true
  fi
) 2>/dev/null || true

# JSON出力（stdout閉鎖時のbroken pipeを無視）
echo '{"systemMessage":"Session logged"}' 2>/dev/null || true
