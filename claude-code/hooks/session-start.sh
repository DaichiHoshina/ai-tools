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

# JSON入力を読み込む
_SS_INPUT=$(cat)

# ====================================
# ハーネス自己診断（非ブロッキング）
# ====================================
_HARNESS_WARNINGS=()

# 1. 必須hookファイルの存在・実行権限チェック
_REQUIRED_HOOKS=(
  "pre-tool-use.sh"
  "post-tool-use.sh"
  "permission-denied.sh"
  "session-start.sh"
  "stop.sh"
  "stop-failure.sh"
)
for _hook in "${_REQUIRED_HOOKS[@]}"; do
  _hook_path="${SCRIPT_DIR}/${_hook}"
  if [[ ! -f "${_hook_path}" ]]; then
    _HARNESS_WARNINGS+=("hook missing: ${_hook}")
  elif [[ ! -x "${_hook_path}" ]]; then
    _HARNESS_WARNINGS+=("hook not executable: ${_hook}")
  fi
done

# 2. 必須libファイルの存在チェック
_REQUIRED_LIBS=(
  "hook-utils.sh"
  "analytics-writer.sh"
)
_LIB_BASE="${SCRIPT_DIR}/../lib"
for _lib in "${_REQUIRED_LIBS[@]}"; do
  if [[ ! -f "${_LIB_BASE}/${_lib}" ]]; then
    _HARNESS_WARNINGS+=("lib missing: ${_lib}")
  fi
done

# 3. settings.json のhook参照先が実在するかチェック
_SETTINGS_FILE="${HOME}/.claude/settings.json"
if [[ -f "${_SETTINGS_FILE}" ]]; then
  while IFS= read -r _hook_cmd; do
    # ~/ をホームディレクトリに展開
    _expanded="${_hook_cmd/#\~\//${HOME}/}"
    if [[ ! -f "${_expanded}" ]]; then
      _HARNESS_WARNINGS+=("settings.json hook not found: ${_hook_cmd}")
    elif [[ ! -x "${_expanded}" ]]; then
      _HARNESS_WARNINGS+=("settings.json hook not executable: ${_hook_cmd}")
    fi
  done < <(jq -r '.. | objects | select(.type == "command") | .command // empty' "${_SETTINGS_FILE}" 2>/dev/null)
fi

# 診断結果を文字列化
_DIAG_MSG=""
if [[ ${#_HARNESS_WARNINGS[@]} -gt 0 ]]; then
  _DIAG_MSG="${ICON_WARNING} **Harness診断**: ${#_HARNESS_WARNINGS[@]}件の問題検出\n"
  for _w in "${_HARNESS_WARNINGS[@]}"; do
    _DIAG_MSG+="  - ${_w}\n"
  done
fi

# --- Analytics: セッション開始記録 ---
_SS_LIB_DIR="${SCRIPT_DIR}/../lib"
if [[ -f "${_SS_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_SS_LIB_DIR}/analytics-writer.sh"
    _SS_SESSION_ID=$(echo "${_SS_INPUT}" | jq -r '.session_id // "unknown"')
    _SS_PROJECT=$(basename "$(echo "${_SS_INPUT}" | jq -r '.cwd // "."')")
    analytics_start_session "${_SS_SESSION_ID}" "${_SS_PROJECT}" 2>/dev/null || true
fi

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

# --- 出力組み立て ---
_SM_PREFIX="${ICON_SUCCESS}"
if [[ ${#_HARNESS_WARNINGS[@]} -gt 0 ]]; then
  _SM_PREFIX="${ICON_WARNING}"
fi

_AC_BASE="**自動**: protection-mode, Serena自動初期化（onboarding確認, memory読み込み）\n\n原則: ${ICON_SUCCESS}安全操作→即実行 ${ICON_WARNING}要確認→承認 ${ICON_FORBIDDEN}禁止→拒否"
if [[ -n "${_DIAG_MSG}" ]]; then
    _AC_FULL="${_DIAG_MSG}\n${_AC_BASE}"
else
    _AC_FULL="${_AC_BASE}"
fi
if [[ -n "${_ANALYTICS_BRIEF}" ]]; then
    _AC_FULL="${_AC_FULL}\n\n${_ANALYTICS_BRIEF}"
fi

jq -n \
  --arg sm "${_SM_PREFIX} Session初期化完了 [color:${_SESSION_COLOR}]" \
  --arg ac "${_AC_FULL}" \
  --arg color "${_SESSION_COLOR}" \
  '{systemMessage: $sm, additionalContext: $ac, color: $color}'
