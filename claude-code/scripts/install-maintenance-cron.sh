#!/usr/bin/env bash
# maintenance loop 週次 cron (launchd) install helper
#
# 目的: dry-run 系 maintenance (/memory-clean, /claude-update-fix --dry-run,
#   /serena-update-fix --dry-run) を毎週月曜 09:20 に headless 実行する
#   launchd plist を配置する。実体は scripts/maintenance-cron-run.sh。
#   hook-bench cron (月曜 09:00) と時刻をずらして直列衝突を避ける。
#
# 安全性: default では plist 配置のみ、`launchctl bootstrap` は user 手動実行。
#   --enable で opt-in 自動 bootstrap (idempotent、bootout → bootstrap で再 load)。
#
# Usage:
#   ./scripts/install-maintenance-cron.sh                 # plist を生成して手順を表示
#   ./scripts/install-maintenance-cron.sh --enable        # plist 配置 + launchctl bootstrap まで自動
#   ./scripts/install-maintenance-cron.sh --dry-run       # plist 内容のみ表示
#   ./scripts/install-maintenance-cron.sh --repo /path    # repo root を明示指定 (worktree から install するとき必須)
set -euo pipefail

DETECTED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT=""
LABEL="com.daichi.ai-tools-maintenance.weekly"
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${PLIST_DIR}/${LABEL}.plist"
LOG_DIR="${HOME}/.claude/logs"
DRY_RUN=0
ENABLE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --enable) ENABLE=1; shift ;;
    --repo) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$DETECTED_ROOT"
fi

# worktree 検出: REPO_ROOT が ai-tools-wt-* を含む場合は誤配置警告
# (bats など test 用途で意図的に許容したい場合は MAINTENANCE_CRON_ALLOW_WT=1)
if [[ "${MAINTENANCE_CRON_ALLOW_WT:-0}" -ne 1 && "$REPO_ROOT" == *"ai-tools-wt-"* ]]; then
  cat >&2 <<EOF
ERROR: REPO_ROOT が worktree 配下です: ${REPO_ROOT}
  cron 実行時には worktree が消えている可能性があります。
  main repo path を --repo で明示してください:
    ./scripts/install-maintenance-cron.sh --repo \$HOME/ghq/github.com/DaichiHoshina/ai-tools/claude-code
EOF
  exit 2
fi

if [[ ! -x "${REPO_ROOT}/scripts/maintenance-cron-run.sh" ]]; then
  echo "ERROR: ${REPO_ROOT}/scripts/maintenance-cron-run.sh が見つかりません" >&2
  exit 2
fi

plist_body() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>cd ${REPO_ROOT} && ./scripts/maintenance-cron-run.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>1</integer>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>20</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/maintenance-cron.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/maintenance-cron.stderr.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "=== plist preview (${PLIST_PATH}) ==="
  plist_body
  exit 0
fi

mkdir -p "$PLIST_DIR" "$LOG_DIR"
plist_body > "$PLIST_PATH"

echo "✓ plist を配置しました: ${PLIST_PATH}"

if [[ "$ENABLE" -eq 1 ]]; then
  GUI_DOMAIN="gui/$(id -u)"
  # idempotent: 既 load なら bootout してから bootstrap (失敗は無視、未 load 時の bootout は exit 非 0)
  launchctl bootout "${GUI_DOMAIN}/${LABEL}" 2>/dev/null || true
  if launchctl bootstrap "$GUI_DOMAIN" "$PLIST_PATH"; then
    echo "✓ launchctl bootstrap 完了 (${GUI_DOMAIN}/${LABEL})"
    launchctl print "${GUI_DOMAIN}/${LABEL}" 2>/dev/null | grep -E '^\s*(state|last exit code)' || true
  else
    echo "ERROR: launchctl bootstrap 失敗。手動で実行してください:" >&2
    echo "  launchctl bootstrap ${GUI_DOMAIN} \"${PLIST_PATH}\"" >&2
    exit 1
  fi
else
  cat <<EOF

次のコマンドで enable してください (--enable で自動化可):

  launchctl bootout  gui/\$(id -u)/${LABEL} 2>/dev/null || true
  launchctl bootstrap gui/\$(id -u) "${PLIST_PATH}"
  launchctl print    gui/\$(id -u)/${LABEL} | grep state
EOF
fi

cat <<EOF

スケジュール: 毎週月曜 09:20 / cd ${REPO_ROOT} && ./scripts/maintenance-cron-run.sh
log: ${LOG_DIR}/maintenance-cron-<ts>.log
cron stdout/stderr: ${LOG_DIR}/maintenance-cron.{stdout,stderr}.log

uninstall:
  launchctl bootout gui/\$(id -u)/${LABEL}
  rm "${PLIST_PATH}"
EOF
