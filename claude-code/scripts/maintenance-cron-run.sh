#!/usr/bin/env bash
# 週次 maintenance loop 本体 (launchd から呼ばれる)
#
# claude CLI headless (-p) で dry-run 系 maintenance command を順に実行し、
# 結果を ~/.claude/logs/maintenance-cron-<ts>.log に追記する。
# 全 command が report-only (repo への write なし) なので無人実行できる。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"
if [[ -z "$CLAUDE_BIN" ]]; then
  echo "ERROR: claude CLI が見つかりません (PATH または CLAUDE_BIN で指定してください)" >&2
  exit 2
fi

MAINTENANCE_COMMANDS=(
  "/memory-clean"
  "/claude-update-fix --dry-run"
  "/serena-update-fix --dry-run"
)

ts="$(date +%Y%m%d-%H%M%S)"
log_file="${LOG_DIR}/maintenance-cron-${ts}.log"

cd "$REPO_ROOT"
for cmd in "${MAINTENANCE_COMMANDS[@]}"; do
  printf '=== %s (%s) ===\n' "$cmd" "$(date '+%F %T')" >> "$log_file"
  if ! "$CLAUDE_BIN" -p "$cmd" --fallback-model sonnet >> "$log_file" 2>&1; then
    printf 'WARN: %s が非 0 で終了した\n' "$cmd" >> "$log_file"
  fi
done

echo "done: ${log_file}"
