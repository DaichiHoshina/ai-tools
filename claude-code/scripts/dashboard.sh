#!/usr/bin/env bash
# dashboard.sh - Claude Code Analytics ダッシュボード起動
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="${SCRIPT_DIR}/../../dashboard"
PORT="${1:-8765}"
DB_PATH="${HOME}/.claude/analytics/analytics.db"

# DB存在チェック
if [[ ! -f "$DB_PATH" ]]; then
    echo "Analytics DB not found. Running backfill first..."
    python3 "${SCRIPT_DIR}/backfill-analytics.py"
fi

# 既にポートが使用中かチェック
if lsof -i :"$PORT" &>/dev/null; then
    echo "Port $PORT is already in use. Opening browser..."
    open "http://localhost:${PORT}" 2>/dev/null || echo "Open http://localhost:${PORT}"
    exit 0
fi

echo "Starting Claude Code Analytics Dashboard on http://localhost:${PORT}"
echo "Press Ctrl+C to stop"

# ブラウザを遅延起動（サーバー起動待ち）
(sleep 1 && open "http://localhost:${PORT}" 2>/dev/null) &

# サーバー起動
cd "$DASHBOARD_DIR"
python3 server.py "$PORT"
