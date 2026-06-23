#!/usr/bin/env bash
# hook-bench 週次 cron (launchd) install helper
#
# 目的: hook latency 退化を継続検出するため、毎週月曜 09:00 に
#   `./scripts/hook-bench.sh --log --diff` を実行する launchd plist を配置する。
#
# 安全性: plist 配置のみ自動、`launchctl load` は user が手動実行する。
#   誤起動回避のため、本 script は自動 enable しない。
#
# Usage:
#   ./scripts/install-hook-bench-cron.sh                 # plist を生成して手順を表示
#   ./scripts/install-hook-bench-cron.sh --dry-run       # plist 内容のみ表示
#   ./scripts/install-hook-bench-cron.sh --repo /path    # repo root を明示指定 (worktree から install するとき必須)
set -euo pipefail

DETECTED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT=""
LABEL="com.daichi.hook-bench.weekly"
PLIST_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${PLIST_DIR}/${LABEL}.plist"
LOG_DIR="${HOME}/.claude/logs"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --repo) REPO_ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$DETECTED_ROOT"
fi

# worktree 検出: REPO_ROOT が ai-tools-wt-* を含む場合は誤配置警告
# (bats など test 用途で意図的に許容したい場合は HOOK_BENCH_CRON_ALLOW_WT=1)
if [[ "${HOOK_BENCH_CRON_ALLOW_WT:-0}" -ne 1 && "$REPO_ROOT" == *"ai-tools-wt-"* ]]; then
  cat >&2 <<EOF
ERROR: REPO_ROOT が worktree 配下です: ${REPO_ROOT}
  cron 実行時には worktree が消えている可能性があります。
  main repo path を --repo で明示してください:
    ./scripts/install-hook-bench-cron.sh --repo \$HOME/ghq/github.com/DaichiHoshina/ai-tools/claude-code
EOF
  exit 2
fi

if [[ ! -x "${REPO_ROOT}/scripts/hook-bench.sh" ]]; then
  echo "ERROR: ${REPO_ROOT}/scripts/hook-bench.sh が見つかりません" >&2
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
    <string>cd ${REPO_ROOT} && ./scripts/hook-bench.sh --log --diff</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>1</integer>
    <key>Hour</key>
    <integer>9</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/hook-bench-cron.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/hook-bench-cron.stderr.log</string>
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

cat <<EOF
✓ plist を配置しました: ${PLIST_PATH}

次のコマンドで enable してください (自動実行しません):

  launchctl unload "${PLIST_PATH}" 2>/dev/null || true
  launchctl load   "${PLIST_PATH}"
  launchctl list | grep ${LABEL}      # Status 0 = OK

スケジュール: 毎週月曜 09:00 / cd ${REPO_ROOT} && ./scripts/hook-bench.sh --log --diff
log: ${LOG_DIR}/hook-bench-<ts>.log
cron stdout/stderr: ${LOG_DIR}/hook-bench-cron.{stdout,stderr}.log

uninstall:
  launchctl unload "${PLIST_PATH}"
  rm "${PLIST_PATH}"
EOF
