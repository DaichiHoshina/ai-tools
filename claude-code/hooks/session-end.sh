#!/usr/bin/env bash
# SessionEnd Hook - セッション統計ログ保存（簡素化版）

set -euo pipefail

# Claude Code 本体が stdout を閉じた状態で発火するため、echo の broken pipe が
# hook-errors.log を汚染する。SIGPIPE を無視して書き込み失敗を静かに扱う。
trap '' PIPE

exec 2>>"$HOME/.claude/logs/hook-errors.log"

_se_src="${BASH_SOURCE[0]}"
[[ "${_se_src}" == /* ]] || _se_src="${PWD}/${_se_src}"
SCRIPT_DIR="${_se_src%/*}"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
# shellcheck source=lib/log-rotation.sh
source "${SCRIPT_DIR}/lib/log-rotation.sh"
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# セッション情報を取得（jq 1回で全フィールド抽出）
# SessionEnd hook 入力には token フィールドが含まれないため transcript_path を取得して後で集計する
IFS=$'\t' read -r SESSION_ID PROJECT_DIR TOTAL_TOKENS TOTAL_MESSAGES DURATION _MODEL _GIT_BRANCH < <(
  extract_json_fields "$INPUT" \
    '.session_id // ""' \
    '.cwd // "."' \
    '.total_tokens // 0' \
    '.total_messages // 0' \
    '.duration // 0' \
    '.model // "unknown"' \
    '.git_branch // ""'
)
# transcript_path は空フィールドとの IFS read 混在を避けるため単独取得
_TRANSCRIPT_PATH=$(jq -r '.transcript_path // ""' <<< "$INPUT" 2>/dev/null || true)
# stdin JSON が canonical source。env CLAUDE_CODE_SESSION_ID は session 切替時に
# 前 session 値が leak することがあり fallback 専用にする (incident 2026-06-25)
SESSION_ID="${SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-unknown}}"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# token 集計: transcript_path の JSONL から assistant message の usage を合計する
# SessionEnd hook 入力 JSON には token 情報が含まれないため JSONL から直接集計する
_INPUT_TOKENS=0; _OUTPUT_TOKENS=0; _CACHE_READ=0; _CACHE_WRITE=0
_JSONL_PATH=""
if [[ -n "${_TRANSCRIPT_PATH}" && -f "${_TRANSCRIPT_PATH}" ]]; then
  _JSONL_PATH="${_TRANSCRIPT_PATH}"
else
  # fallback: cwd + session_id から JSONL パスを導出
  _SLUG="${PROJECT_DIR//\//-}"
  _SLUG="${_SLUG//\./-}"
  _JSONL_PATH="${HOME}/.claude/projects/${_SLUG}/${SESSION_ID}.jsonl"
fi
if [[ -f "${_JSONL_PATH}" ]]; then
  # process substitution 内の jq/echo が EPIPE で失敗しても set -e に引っかからないよう
  # read コマンド全体を || true で保護する（SIGPIPE は trap '' PIPE で無視済みだが
  # EPIPE errno による exit 非ゼロは set -e を発動させるため）
  IFS=$'\t' read -r _INPUT_TOKENS _OUTPUT_TOKENS _CACHE_WRITE _CACHE_READ < <(
    jq -sr '
      [.[] | select(.type == "assistant" and .message.usage != null) | .message.usage] |
      [
        (map(.input_tokens // 0) | add // 0),
        (map(.output_tokens // 0) | add // 0),
        (map(.cache_creation_input_tokens // 0) | add // 0),
        (map(.cache_read_input_tokens // 0) | add // 0)
      ] | @tsv
    ' "${_JSONL_PATH}" 2>/dev/null || printf '0\t0\t0\t0\n'
  ) 2>/dev/null || true
fi

# ログ保存
LOG_DIR="$HOME/.claude/session-logs"
mkdir -p "$LOG_DIR"
printf -v _LOG_DATE '%(%Y%m%d)T' -1
LOG_FILE="$LOG_DIR/${_LOG_DATE}.log"

# ローテーション（7日超削除）をバックグラウンドへ
find "$LOG_DIR" -type f -mtime +7 -delete 2>/dev/null &

# ログ追記
printf -v _SE_TS '%(%Y-%m-%d %H:%M:%S)T' -1
echo "[${_SE_TS}] $SESSION_ID | $PROJECT_NAME | msg:$TOTAL_MESSAGES | tok:$TOTAL_TOKENS | ${DURATION}s" >> "$LOG_FILE"

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
    _rotate_log_if_needed "${_LOGS_DIR}/hook-info.log"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] session-end: purged ${_purged} stale state file(s)" \
      >> "${_LOGS_DIR}/hook-info.log" 2>/dev/null || true
  fi
) 2>/dev/null || true

# JSON出力（stdout閉鎖時のbroken pipeを無視）
echo '{"systemMessage":"Session logged"}' 2>/dev/null || true
