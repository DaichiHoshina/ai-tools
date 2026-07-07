#!/usr/bin/env bash
# hook-bench 週次 cron (launchd) install helper
#
# 目的: hook latency 退化を継続検出するため、毎週月曜 09:00 に
#   `./scripts/hook-bench.sh --log --diff` を実行する launchd plist を配置する。
#
# 安全性: default では plist 配置のみ、`launchctl bootstrap` は user 手動実行。
#   --enable で opt-in 自動 bootstrap (idempotent、bootout → bootstrap で再 load)。
#
# Usage:
#   ./scripts/install-hook-bench-cron.sh                 # plist を生成して手順を表示
#   ./scripts/install-hook-bench-cron.sh --enable        # plist 配置 + launchctl bootstrap まで自動
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

# hook-bench.sh は連想配列 (declare -A) を使うため bash 4+ が必須。
# launchd の login shell から `env bash` を解決すると macOS 標準の 3.2 を拾い
# `declare: -A: invalid option` で失敗するため、install 時に 4+ の bash を
# 検出して plist の interpreter に絶対 path で固定する。
BASH_BIN=""
for cand in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash 2>/dev/null)"; do
  [[ -x "$cand" ]] || continue
  major="$("$cand" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null)"
  if [[ "${major:-0}" -ge 4 ]]; then
    BASH_BIN="$cand"
    break
  fi
done
if [[ -z "$BASH_BIN" ]]; then
  echo "ERROR: bash 4+ が見つかりません (hook-bench.sh は declare -A 依存)。'brew install bash' してください" >&2
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
    <string>${BASH_BIN}</string>
    <string>-lc</string>
    <string>cd ${REPO_ROOT} && ${BASH_BIN} ./scripts/hook-bench.sh --log --diff</string>
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

スケジュール: 毎週月曜 09:00 / cd ${REPO_ROOT} && ./scripts/hook-bench.sh --log --diff
log: ${LOG_DIR}/hook-bench-<ts>.log
cron stdout/stderr: ${LOG_DIR}/hook-bench-cron.{stdout,stderr}.log

uninstall:
  launchctl bootout gui/\$(id -u)/${LABEL}
  rm "${PLIST_PATH}"
EOF
