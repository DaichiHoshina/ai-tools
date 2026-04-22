#!/usr/bin/env bash
# SessionEnd Hook - セッション統計ログ保存（簡素化版）

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

# JSON入力を読み込む
INPUT=$(cat)

# セッション情報を取得
SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$INPUT")
PROJECT_NAME=$(basename "$(jq -r '.workspace.current_dir // "."' <<< "$INPUT")")
TOTAL_TOKENS=$(jq -r '.total_tokens // 0' <<< "$INPUT")
TOTAL_MESSAGES=$(jq -r '.total_messages // 0' <<< "$INPUT")
DURATION=$(jq -r '.duration // 0' <<< "$INPUT")

# ログ保存
LOG_DIR="$HOME/.claude/session-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d).log"

# ローテーション（7日超削除）
find "$LOG_DIR" -type f -mtime +7 -delete 2>/dev/null || true

# ログ追記
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SESSION_ID | $PROJECT_NAME | msg:$TOTAL_MESSAGES | tok:$TOTAL_TOKENS | ${DURATION}s" >> "$LOG_FILE"

# --- Analytics記録 ---
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${_HOOK_DIR}/../lib"
if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    _MODEL=$(jq -r '.model // "unknown"' <<< "$INPUT")
    _GIT_BRANCH=$(jq -r '.git_branch // ""' <<< "$INPUT")
    _INPUT_TOKENS=$(jq -r '.input_tokens // 0' <<< "$INPUT")
    _CACHE_READ=$(jq -r '.cache_read_tokens // 0' <<< "$INPUT")
    _CACHE_WRITE=$(jq -r '.cache_write_tokens // 0' <<< "$INPUT")
    _OUTPUT_TOKENS=$(jq -r '.output_tokens // 0' <<< "$INPUT")
    analytics_insert_session "$SESSION_ID" "$PROJECT_NAME" "$_MODEL" "$_GIT_BRANCH" \
        "$_INPUT_TOKENS" "$_CACHE_READ" "$_CACHE_WRITE" "$_OUTPUT_TOKENS" "$TOTAL_MESSAGES" "$DURATION" 2>/dev/null || true
    analytics_cleanup_old_records 90 2>/dev/null || true
fi

# JSON出力（stdout閉鎖時のbroken pipeを無視）
echo '{"systemMessage":"Session logged"}' 2>/dev/null || true
