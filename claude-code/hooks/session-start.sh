#!/usr/bin/env bash
# SessionStart Hook - protection-mode + guidelines 自動読み込み
# セッション開始時にSerena memoryリストを確認 + compact-restore読み込み
# NOTE: Serena有無はチェックしない（compact直後はMCP未初期化の可能性あり）

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icons
# ICON_* \u306f hook-utils.sh \u3067\u5b9a\u7fa9\u6e08\u307f

# jq前提条件チェック
require_jq

# JSON入力を読み込む
_SS_INPUT=$(cat)

# jq 1回で全フィールド取得（v2.2.1 fork削減）
eval "$(jq -r '@sh "_SS_SESSION_ID=\(.session_id // "unknown") _CWD=\(.cwd // "")"' <<< "${_SS_INPUT}")"
_SS_PROJECT=$(basename "${_CWD:-.}")

# ====================================
# ハーネス自己診断（24時間キャッシュ）
# ====================================
_HARNESS_WARNINGS=()
_DIAG_MSG=""
_DIAG_CACHE="${HOME}/.claude/cache/harness-diag.cache"
_SETTINGS_FILE="${HOME}/.claude/settings.json"

# キャッシュが24時間以内なら再利用
_NEED_DIAG=true
if [[ -f "${_DIAG_CACHE}" ]]; then
  _CACHE_AGE=$(( $(date +%s) - $(stat -f%m "${_DIAG_CACHE}" 2>/dev/null || echo 0) ))
  if [[ ${_CACHE_AGE} -lt 86400 ]]; then
    _DIAG_MSG=$(cat "${_DIAG_CACHE}")
    _NEED_DIAG=false
  fi
fi

if [[ "${_NEED_DIAG}" == "true" ]]; then
  # 1. 必須hookファイルの存在・実行権限チェック
  for _hook in pre-tool-use.sh post-tool-use.sh permission-denied.sh session-start.sh stop.sh stop-failure.sh; do
    _hook_path="${SCRIPT_DIR}/${_hook}"
    if [[ ! -f "${_hook_path}" ]]; then
      _HARNESS_WARNINGS+=("hook missing: ${_hook}")
    elif [[ ! -x "${_hook_path}" ]]; then
      _HARNESS_WARNINGS+=("hook not executable: ${_hook}")
    fi
  done

  # 2. 必須libファイルの存在チェック
  _LIB_BASE="${SCRIPT_DIR}/../lib"
  for _lib in hook-utils.sh analytics-writer.sh; do
    if [[ ! -f "${_LIB_BASE}/${_lib}" ]]; then
      _HARNESS_WARNINGS+=("lib missing: ${_lib}")
    fi
  done

  # 3. settings.json のhook参照先チェック
  if [[ -f "${_SETTINGS_FILE}" ]]; then
    while IFS= read -r _hook_cmd; do
      _expanded="${_hook_cmd/#\~\//${HOME}/}"
      if [[ ! -f "${_expanded}" ]]; then
        _HARNESS_WARNINGS+=("settings.json hook not found: ${_hook_cmd}")
      elif [[ ! -x "${_expanded}" ]]; then
        _HARNESS_WARNINGS+=("settings.json hook not executable: ${_hook_cmd}")
      fi
    done < <(jq -r '.. | objects | select(.type == "command") | .command // empty' "${_SETTINGS_FILE}" 2>/dev/null)
  fi

  # 診断結果を文字列化 & キャッシュ
  if [[ ${#_HARNESS_WARNINGS[@]} -gt 0 ]]; then
    _DIAG_MSG="${ICON_WARNING} **Harness診断**: ${#_HARNESS_WARNINGS[@]}件の問題検出\n"
    for _w in "${_HARNESS_WARNINGS[@]}"; do
      _DIAG_MSG+="  - ${_w}\n"
    done
  fi
  mkdir -p "$(dirname "${_DIAG_CACHE}")"
  printf '%s' "${_DIAG_MSG}" > "${_DIAG_CACHE}"
fi

# --- 多リポ配下起動ガード ---
# cwd がリポジトリルートでない（.git 無し）かつ子孫に複数の git リポがある場合、
# git/rg/Glob が全体を舐めに行き体感が極端に遅くなる。個別リポ cd を促す警告。
# キャッシュとは独立して毎回評価する（cwd はセッション毎に変わるため）。
_CWD_GUARD_MSG=""
if [[ -n "${_CWD:-}" ]] && [[ -d "${_CWD}" ]] && [[ ! -d "${_CWD}/.git" ]]; then
  _NESTED_REPOS=$(find "${_CWD}" -maxdepth 3 -type d -name ".git" 2>/dev/null | head -2 | wc -l | tr -d ' ')
  if [[ "${_NESTED_REPOS}" -ge 2 ]]; then
    _CWD_GUARD_MSG="${ICON_WARNING} **cwd警告**: 複数リポジトリの親ディレクトリで起動中（${_CWD}）。git/rg/Glob が全体を舐めて重くなる。個別リポに cd してから起動推奨\n"
  fi
fi

# --- Worktree Memory Symlink ---
ensure_worktree_memory_link "${_CWD}" 2>/dev/null || true

# --- Analytics: セッション開始記録 ---
_SS_LIB_DIR="${SCRIPT_DIR}/../lib"
if [[ -f "${_SS_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_SS_LIB_DIR}/analytics-writer.sh"
    analytics_start_session "${_SS_SESSION_ID}" "${_SS_PROJECT}" 2>/dev/null || true
fi

# --- Directory Color ---
# jq 1回で default + mappings を取得して bash側でマッチング（fork大幅削減）
_COLOR_CONFIG="${HOME}/.claude/config/dir-colors.json"
_SESSION_COLOR="default"
if [[ -f "${_COLOR_CONFIG}" ]]; then
    # 1行目=default、2行目以降="pattern\tcolor"
    _COLOR_DATA=$(jq -r '.default // "default", (.mappings[]? | "\(.pattern)\t\(.color)")' "${_COLOR_CONFIG}" 2>/dev/null || echo "default")
    _FIRST=true
    while IFS=$'\t' read -r _PATTERN _COLOR; do
        if $_FIRST; then
            _SESSION_COLOR="${_PATTERN}"  # 1行目は default 値
            _FIRST=false
            continue
        fi
        if [[ -n "${_PATTERN}" ]] && [[ "${PWD}" == *"${_PATTERN}"* ]]; then
            _SESSION_COLOR="${_COLOR}"
            break
        fi
    done <<< "${_COLOR_DATA}"
fi

# --- 出力組み立て ---
_SM_PREFIX="${ICON_SUCCESS}"
if [[ ${#_HARNESS_WARNINGS[@]} -gt 0 ]] || [[ -n "${_CWD_GUARD_MSG}" ]]; then
  _SM_PREFIX="${ICON_WARNING}"
fi

_AC_BASE="**自動実行（必須）**: 以下を順に実行してください\n1. \`mcp__serena__activate_project\` を path=\"${_CWD}\" で呼び出す\n2. \`mcp__serena__list_memories\` でメモリ一覧を確認する\n3. 関連メモリがあれば読み込む\n\n原則: ${ICON_SUCCESS}安全操作→即実行 ${ICON_WARNING}要確認→承認 ${ICON_FORBIDDEN}禁止→拒否"
_AC_PREFIX=""
if [[ -n "${_CWD_GUARD_MSG}" ]]; then
    _AC_PREFIX+="${_CWD_GUARD_MSG}"
fi
if [[ -n "${_DIAG_MSG}" ]]; then
    _AC_PREFIX+="${_DIAG_MSG}"
fi
if [[ -n "${_AC_PREFIX}" ]]; then
    _AC_FULL="${_AC_PREFIX}\n${_AC_BASE}"
else
    _AC_FULL="${_AC_BASE}"
fi
jq -n \
  --arg sm "${_SM_PREFIX} Session初期化完了 [color:${_SESSION_COLOR}]" \
  --arg ac "${_AC_FULL}" \
  --arg color "${_SESSION_COLOR}" \
  '{systemMessage: $sm, additionalContext: $ac, color: $color}'
