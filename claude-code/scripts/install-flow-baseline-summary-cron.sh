#!/usr/bin/env bash
set -euo pipefail

DETECTED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT=""
LABEL="com.daichi.flow-baseline-summary.weekly"
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

if [[ "${FLOW_BASELINE_SUMMARY_CRON_ALLOW_WT:-0}" -ne 1 && "$REPO_ROOT" == *"ai-tools-wt-"* ]]; then
  cat >&2 <<EOF
ERROR: REPO_ROOT が worktree 配下です: ${REPO_ROOT}
  cron 実行時には worktree が消えている可能性があります。
  main repo path を --repo で明示してください:
    ./scripts/install-flow-baseline-summary-cron.sh --repo \$HOME/ghq/github.com/DaichiHoshina/ai-tools/claude-code
EOF
  exit 2
fi

if [[ ! -x "${REPO_ROOT}/scripts/flow-baseline-summary-cron.sh" ]]; then
  echo "ERROR: ${REPO_ROOT}/scripts/flow-baseline-summary-cron.sh が見つかりません" >&2
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
    <string>cd ${REPO_ROOT} && ./scripts/flow-baseline-summary-cron.sh --diff</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>1</integer>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>40</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/flow-baseline-summary-cron.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/flow-baseline-summary-cron.stderr.log</string>
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

スケジュール: 毎週月曜 09:40 / cd ${REPO_ROOT} && ./scripts/flow-baseline-summary-cron.sh --diff
log: ${LOG_DIR}/flow-baseline-summary-<date>.log
cron stdout/stderr: ${LOG_DIR}/flow-baseline-summary-cron.{stdout,stderr}.log

uninstall:
  launchctl bootout gui/\$(id -u)/${LABEL}
  rm "${PLIST_PATH}"
EOF
