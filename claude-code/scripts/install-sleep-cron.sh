#!/usr/bin/env bash
# Usage: install-sleep-cron.sh [--schedule "<5-field cron>"] [--repo <path>] [--enable] [--dry-run]
# sleep-cron-run.sh を launchd で毎晩実行する plist を配置する。default は 03:30。
# 手動 run 実績 (state.md の Status: done) がなければ拒否する (強行は SLEEP_CRON_FORCE=1)。
set -euo pipefail

DETECTED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEDULE="30 3 * * *"
REPO=""
DRY_RUN=0
ENABLE=0
PLIST_DIR="${HOME}/Library/LaunchAgents"
LOG_DIR="${HOME}/.claude/logs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --schedule) SCHEDULE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --enable) ENABLE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "${REPO}" ]] || REPO="$(cd "${DETECTED_ROOT}/.." && pwd)"

LABEL="com.daichi.sleep-pipeline.daily"
PLIST_PATH="${PLIST_DIR}/${LABEL}.plist"
RUN_SH="${DETECTED_ROOT}/scripts/sleep-cron-run.sh"
STATE="${SLEEP_STATE_DIR:-${HOME}/.claude/sleep}/state.md"

if [[ "${SLEEP_CRON_ALLOW_WT:-0}" -ne 1 && "${DETECTED_ROOT}" == *"worktree"* ]]; then
  echo "ERROR: script root が worktree 配下です: ${DETECTED_ROOT}" >&2
  echo "  main repo の scripts/install-sleep-cron.sh から実行してください" >&2
  exit 2
fi

[[ -x "${RUN_SH}" ]] || { echo "ERROR: ${RUN_SH} が見つかりません" >&2; exit 2; }

if [[ "${SLEEP_CRON_FORCE:-0}" -ne 1 ]]; then
  if ! grep -q '^- Status: done' "${STATE}" 2>/dev/null; then
    cat >&2 <<EOF
ERROR: sleep pipeline に manual run の成功実績 (Status: done) がありません。
  先に手動で確認してください: ${RUN_SH}
  (manual run reliable → loop-ify → schedule。強行は SLEEP_CRON_FORCE=1)
EOF
    exit 2
  fi
fi

read -r C_MIN C_HOUR C_DOM C_MON C_DOW extra <<< "${SCHEDULE}"
[[ -z "${extra:-}" && -n "${C_DOW:-}" ]] || { echo "ERROR: --schedule は 5 field (min hour dom mon dow)" >&2; exit 2; }
_interval_lines=""
_add_key() {
  local key="$1" val="$2"
  [[ "${val}" == "*" ]] && return 0
  [[ "${val}" =~ ^[0-9]+$ ]] || { echo "ERROR: schedule field '${val}' は数値か * のみ対応" >&2; exit 2; }
  _interval_lines+="    <key>${key}</key><integer>${val}</integer>
"
}
_add_key Minute "${C_MIN}"
_add_key Hour "${C_HOUR}"
_add_key Day "${C_DOM}"
_add_key Month "${C_MON}"
_add_key Weekday "${C_DOW}"

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
    <string>${RUN_SH} --repo ${REPO}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
${_interval_lines}  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/sleep-cron.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/sleep-cron.stderr.log</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
EOF
}

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "=== plist preview (${PLIST_PATH}) ==="
  plist_body
  exit 0
fi

mkdir -p "${PLIST_DIR}" "${LOG_DIR}"
plist_body > "${PLIST_PATH}"
echo "✓ plist を配置しました: ${PLIST_PATH}"

if [[ "${ENABLE}" -eq 1 ]]; then
  GUI_DOMAIN="gui/$(id -u)"
  launchctl bootout "${GUI_DOMAIN}/${LABEL}" 2>/dev/null || true
  if launchctl bootstrap "${GUI_DOMAIN}" "${PLIST_PATH}"; then
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
