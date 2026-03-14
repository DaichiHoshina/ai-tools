#!/usr/bin/env bash
# SessionStart Hook - protection-mode + guidelines 自動読み込み
# セッション開始時にSerena memoryリストを確認 + compact-restore読み込み
# NOTE: Serena有無はチェックしない（compact直後はMCP未初期化の可能性あり）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icons
ICON_SUCCESS=$'\u2713'    # check-circle
ICON_WARNING=$'\u25b2'    # exclamation-triangle
ICON_FORBIDDEN=$'\u2297'  # ban

# jq前提条件チェック
require_jq

# JSON入力を消費（未使用だが読み捨て必要）
cat > /dev/null

# --- Directory Color ---
_COLOR_CONFIG="${HOME}/.claude/config/dir-colors.json"
_SESSION_COLOR="default"
if [[ -f "${_COLOR_CONFIG}" ]]; then
    _DEFAULT_COLOR=$(jq -r '.default // "default"' "${_COLOR_CONFIG}")
    _SESSION_COLOR="${_DEFAULT_COLOR}"
    while IFS= read -r _MAPPING; do
        _PATTERN=$(echo "${_MAPPING}" | jq -r '.pattern')
        _COLOR=$(echo "${_MAPPING}" | jq -r '.color')
        if [[ "${PWD}" == *"${_PATTERN}"* ]]; then
            _SESSION_COLOR="${_COLOR}"
            break
        fi
    done < <(jq -c '.mappings[]' "${_COLOR_CONFIG}" 2>/dev/null || true)
fi

# --- Analytics Brief ---
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPORT_SCRIPT="${_HOOK_DIR}/../scripts/analytics-report.py"
_ANALYTICS_BRIEF=""
if [[ -f "${_REPORT_SCRIPT}" ]]; then
    _ANALYTICS_BRIEF=$(python3 "${_REPORT_SCRIPT}" --mode brief 2>/dev/null || true)
fi

_AC_BASE="**自動**: protection-mode, Serena自動初期化（onboarding確認, memory読み込み）\n\n原則: ${ICON_SUCCESS}安全操作→即実行 ${ICON_WARNING}要確認→承認 ${ICON_FORBIDDEN}禁止→拒否"
if [[ -n "${_ANALYTICS_BRIEF}" ]]; then
    _AC_FULL="${_AC_BASE}\n\n${_ANALYTICS_BRIEF}"
else
    _AC_FULL="${_AC_BASE}"
fi

jq -n \
  --arg sm "${ICON_SUCCESS} Session初期化完了 [color:${_SESSION_COLOR}]" \
  --arg ac "${_AC_FULL}" \
  --arg color "${_SESSION_COLOR}" \
  '{systemMessage: $sm, additionalContext: $ac, color: $color}'
