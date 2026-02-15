#!/usr/bin/env bash
# SessionEnd Hook - セッション統計ログ保存（簡素化版）

set -euo pipefail

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

# JSON出力
echo '{"systemMessage":"Session logged"}'
