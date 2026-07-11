#!/usr/bin/env bash
# loop.sh 定期実行 (launchd) install helper
#
# 目的: /loop cron の実体。指定 loop を launchd で定期実行する plist を配置する。
#
# MVL 順序 enforcement: state.md に `- Status: done` (= manual run の exit 0 実績) が
#   ない loop の cron 化は拒否する (manual run reliable → loop-ify → schedule)。
#   意図的に skip する場合のみ LOOP_CRON_FORCE=1。
#
# 安全性: default では plist 配置のみ、`launchctl bootstrap` は user 手動実行。
#   --enable で opt-in 自動 bootstrap (idempotent、bootout → bootstrap で再 load)。
#
# Usage:
#   ./scripts/install-loop-cron.sh --name <name> --gate "<cmd>" --schedule "<5-field cron>" [options]
#
# Options:
#   --name <name>        loop ID (必須)
#   --gate "<cmd>"       objective gate (必須)
#   --schedule "<cron>"  "min hour dom mon dow" 形式。数値と * のみ対応 (必須)
#   --repo <path>        loop.sh に渡す作業 repo (default: このスクリプトの repo root)
#   --loop-args "<args>" loop.sh への追加 flag をそのまま渡す (例: "--max-iter 5 --review")
#   --enable             launchctl bootstrap まで自動
#   --dry-run            plist 内容のみ表示
set -euo pipefail

DETECTED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME=""
GATE=""
SCHEDULE=""
REPO=""
LOOP_ARGS=""
DRY_RUN=0
ENABLE=0
PLIST_DIR="${HOME}/Library/LaunchAgents"
LOG_DIR="${HOME}/.claude/logs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --gate) GATE="$2"; shift 2 ;;
    --schedule) SCHEDULE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --loop-args) LOOP_ARGS="$2"; shift 2 ;;
    --enable) ENABLE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$NAME" && -n "$GATE" && -n "$SCHEDULE" ]] || {
  echo "ERROR: --name / --gate / --schedule は必須" >&2
  exit 2
}
[[ "$NAME" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ERROR: --name は英数と . _ - のみ" >&2; exit 2; }
[[ -n "$REPO" ]] || REPO="$DETECTED_ROOT"

LABEL="com.daichi.loop.${NAME}"
PLIST_PATH="${PLIST_DIR}/${LABEL}.plist"
LOOP_SH="${DETECTED_ROOT}/scripts/loop.sh"
STATE="${HOME}/.claude/loops/${NAME}/state.md"

# worktree 検出: cron 実行時に worktree が消えている可能性がある (hook-bench-cron と同じ guard)
if [[ "${LOOP_CRON_ALLOW_WT:-0}" -ne 1 && "$DETECTED_ROOT" == *"worktree"* ]]; then
  echo "ERROR: script root が worktree 配下です: ${DETECTED_ROOT}" >&2
  echo "  main repo の scripts/install-loop-cron.sh から実行してください" >&2
  exit 2
fi

[[ -x "$LOOP_SH" ]] || { echo "ERROR: ${LOOP_SH} が見つかりません" >&2; exit 2; }

# MVL 順序 enforcement: manual run の成功実績 (Status: done) を要求
if [[ "${LOOP_CRON_FORCE:-0}" -ne 1 ]]; then
  if ! grep -q '^- Status: done' "$STATE" 2>/dev/null; then
    cat >&2 <<EOF
ERROR: loop '${NAME}' に manual run の成功実績 (Status: done) がありません。
  先に手動で green を確認してください: ${LOOP_SH} --name ${NAME} --gate "<cmd>"
  (manual run reliable → loop-ify → schedule。強行は LOOP_CRON_FORCE=1)
EOF
    exit 2
  fi
fi

# 5-field cron (数値 / * のみ) → launchd StartCalendarInterval
read -r C_MIN C_HOUR C_DOM C_MON C_DOW extra <<< "$SCHEDULE"
[[ -z "${extra:-}" && -n "${C_DOW:-}" ]] || { echo "ERROR: --schedule は 5 field (min hour dom mon dow)" >&2; exit 2; }
_interval_lines=""
_add_key() {
  local key="$1" val="$2"
  [[ "$val" == "*" ]] && return 0
  [[ "$val" =~ ^[0-9]+$ ]] || { echo "ERROR: schedule field '${val}' は数値か * のみ対応" >&2; exit 2; }
  _interval_lines+="    <key>${key}</key><integer>${val}</integer>
"
}
_add_key Minute "$C_MIN"
_add_key Hour "$C_HOUR"
_add_key Day "$C_DOM"
_add_key Month "$C_MON"
_add_key Weekday "$C_DOW"

# loop.sh は連想配列非依存だが、launchd の PATH は最小構成のため
# claude / jq を解決できる login shell 経由 (-lc) で起動する
BASH_BIN="$(command -v bash)"

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
    <string>${LOOP_SH} --name ${NAME} --repo ${REPO} --gate '${GATE}' --notify ${LOOP_ARGS}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
${_interval_lines}  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/loop-cron-${NAME}.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/loop-cron-${NAME}.stderr.log</string>
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

uninstall:
  launchctl bootout gui/\$(id -u)/${LABEL}
  rm "${PLIST_PATH}"
EOF
fi
