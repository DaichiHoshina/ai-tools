#!/usr/bin/env bash
# 週次 maintenance loop 本体 (launchd から呼ばれる)
#
# claude CLI headless (-p) で maintenance command を順に実行し、
# 結果を ~/.claude/logs/maintenance-cron-<ts>.log に追記する。
# memory-clean のみ --apply (trash + MEMORY.md prune + 表記揺れ修正まで実行、
# cluster / graduate 等の判断が要る操作は --apply でも提案止まり)。他は report-only。
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
  "/memory-clean --apply"
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

# first-ctx 床値の regression 検知 (claude CLI 不要の直接実行、warn は log で確認)
printf '=== first-ctx-check (%s) ===\n' "$(date '+%F %T')" >> "$log_file"
if ! "${REPO_ROOT}/scripts/first-ctx-check.sh" --log >> "$log_file" 2>&1; then
  printf 'WARN: first-ctx threshold 超過 session あり\n' >> "$log_file"
fi

# 第 1 月曜のみ月次棚卸しを出す (weekly 月曜実行 × 日付 gate)
if [[ "$(date +%d | sed 's/^0//')" -le 7 ]]; then
  printf '=== toolchain-health-report (%s) ===\n' "$(date '+%F %T')" >> "$log_file"
  "${REPO_ROOT}/scripts/toolchain-health-report.sh" >> "$log_file" 2>&1 \
    || printf 'WARN: toolchain-health-report failed\n' >> "$log_file"
else
  printf 'skip: toolchain-health-report (第 1 月曜のみ)\n' >> "$log_file"
fi

echo "done: ${log_file}"
