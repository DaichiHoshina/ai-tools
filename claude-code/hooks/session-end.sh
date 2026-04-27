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
PROJECT_NAME=$(basename "$PROJECT_DIR")

# ログ保存
LOG_DIR="$HOME/.claude/session-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d).log"

# ローテーション（7日超削除）
find "$LOG_DIR" -type f -mtime +7 -delete 2>/dev/null || true

# ログ追記
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $SESSION_ID | $PROJECT_NAME | msg:$TOTAL_MESSAGES | tok:$TOTAL_TOKENS | ${DURATION}s" >> "$LOG_FILE"

# --- Analytics記録 ---
_LIB_DIR="${SCRIPT_DIR}/../lib"
if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    analytics_insert_session "$SESSION_ID" "$PROJECT_NAME" "$_MODEL" "$_GIT_BRANCH" \
        "$_INPUT_TOKENS" "$_CACHE_READ" "$_CACHE_WRITE" "$_OUTPUT_TOKENS" "$TOTAL_MESSAGES" "$DURATION" 2>/dev/null || true
    # stderr は exec 2>> で hook-errors.log に既にリダイレクト済（6行目）。明示捨てない
    analytics_cleanup_old_records 90 || true
fi

# JSON出力（stdout閉鎖時のbroken pipeを無視）
echo '{"systemMessage":"Session logged"}' 2>/dev/null || true
