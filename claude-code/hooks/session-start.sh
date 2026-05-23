#!/usr/bin/env bash
# SessionStart Hook - protection-mode + guidelines 自動読み込み
# セッション開始時にSerena memoryリストを確認 + compact-restore読み込み
# NOTE: Serena有無はチェックしない（compact直後はMCP未初期化の可能性あり）

set -euo pipefail

# init_duration 計測: microsec 精度で hook 処理開始時刻を記録 (bash 5.0+ EPOCHREALTIME)
# bash 5+: EPOCHREALTIME 利用 / bash 3-4: fallback (timing 計測無効化)
if (( BASH_VERSINFO[0] >= 5 )); then
    _SS_START_US="${EPOCHREALTIME/./}"
else
    _SS_START_US=0
fi

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
_SS_SESSION_ID="${CLAUDE_CODE_SESSION_ID:-${_SS_SESSION_ID}}"
_SS_PROJECT=$(basename "${_CWD:-.}")

# ====================================
# statusline マーカー初期化
# ====================================
# /tmp/claude-wt-${SESSION_ID} は post-tool-use.sh が cd 検出時に書き込み、
# statusline.js が cwd 解決の優先元として読む。session 開始時に最新の cwd で
# 初期化することで、過去 session で書かれた古いマーカーが残るのを防ぐ
# （例: 同セッションで一時的 cd した後、cd 含まない Bash が続いてマーカーが
# 古いままになるケースの再発防止は別途必要、ここでは session 境界のみ対処）。
if [[ -n "${_SS_SESSION_ID}" && "${_SS_SESSION_ID}" != "unknown" && -n "${_CWD:-}" && -d "${_CWD:-}" ]]; then
  if git -C "${_CWD}" rev-parse --git-dir >/dev/null 2>&1; then
    _SS_ABS=$(cd "${_CWD}" && pwd)
    echo "${_SS_ABS}" > "/tmp/claude-wt-${_SS_SESSION_ID}"
  fi
fi

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
  _CACHE_AGE=$(( EPOCHSECONDS - $(stat -f%m "${_DIAG_CACHE}" 2>/dev/null || echo 0) ))
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
      # command フィールドは "path arg1 arg2..." 形式があり得る（例: serena-hook.sh activate）。
      # 存在チェックは実行ファイル部分（最初の空白までのトークン）のみ対象。
      _hook_path="${_hook_cmd%% *}"
      _expanded="${_hook_path/#\~\//${HOME}/}"
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
  _NESTED_REPOS=0
  shopt -s nullglob
  for _git_dir in "${_CWD}"/*/.git "${_CWD}"/*/*/.git "${_CWD}"/*/*/*/.git; do
    if [[ -d "${_git_dir}" ]]; then
      _NESTED_REPOS=$(( _NESTED_REPOS + 1 ))
      [[ ${_NESTED_REPOS} -ge 2 ]] && break
    fi
  done
  shopt -u nullglob
  if [[ "${_NESTED_REPOS}" -ge 2 ]]; then
    _CWD_GUARD_MSG="${ICON_WARNING} **cwd警告**: 複数リポジトリの親ディレクトリで起動中（${_CWD}）。git/rg/Glob が全体を舐めて重くなる。個別リポに cd してから起動推奨\n"
  fi
fi

# --- Worktree Memory Symlink ---
ensure_worktree_memory_link "${_CWD}" 2>/dev/null || true

# --- Analytics: セッション開始記録 ---
# init_duration_ms は analytics_start_session 呼び出し直前で確定する
# （その後の処理 = dir-color / 出力組み立て は analytics 対象外）
if (( BASH_VERSINFO[0] >= 5 && _SS_START_US > 0 )); then
    _SS_DURATION_MS=$(( (${EPOCHREALTIME/./} - _SS_START_US) / 1000 ))
else
    _SS_DURATION_MS=0
fi

# session-init-timing.log に append（session-end.sh がここから直近 duration を参照）
_SS_TIMING_LOG="${HOME}/.claude/logs/session-init-timing.log"
mkdir -p "$(dirname "${_SS_TIMING_LOG}")"
_SS_PLUGIN_COUNT=$(jq '.enabledPlugins | length' "${HOME}/.claude/settings.json" 2>/dev/null || echo 0)
TZ=UTC printf -v _SS_TS '%(%Y-%m-%dT%H:%M:%SZ)T' -1
echo "[${_SS_TS}] session_id=${_SS_SESSION_ID} duration_ms=${_SS_DURATION_MS} plugin_count=${_SS_PLUGIN_COUNT}" >> "${_SS_TIMING_LOG}" 2>/dev/null || true
# 直近 1000 行に切り詰め (session-end.sh の grep スキャン量を上限化)
if [[ -f "${_SS_TIMING_LOG}" ]] && [[ $(wc -l < "${_SS_TIMING_LOG}" 2>/dev/null || echo 0) -gt 1000 ]]; then
    tail -n 1000 "${_SS_TIMING_LOG}" > "${_SS_TIMING_LOG}.tmp" 2>/dev/null \
        && mv "${_SS_TIMING_LOG}.tmp" "${_SS_TIMING_LOG}" 2>/dev/null || true
fi

_SS_LIB_DIR="${SCRIPT_DIR}/../lib"
if [[ -f "${_SS_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_SS_LIB_DIR}/analytics-writer.sh"
    analytics_start_session "${_SS_SESSION_ID}" "${_SS_PROJECT}" "${_SS_DURATION_MS}" 2>/dev/null || true
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

_AC_BASE="**自動実行（必須）**: 以下を順に実行してください\n1. \`mcp__serena__activate_project\` を project=\"${_CWD}\" で呼び出す\n2. \`mcp__serena__list_memories\` でメモリ一覧を確認する\n3. 関連メモリがあれば読み込む\n\n**追加推奨**: コーディング作業を開始する場合、最初の編集前に \`/load-guidelines\` を実行 (tech stack 自動検出、summary mode 軽量)\n\n原則: ${ICON_SUCCESS}安全操作→即実行 ${ICON_WARNING}要確認→承認 ${ICON_FORBIDDEN}禁止→拒否"
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
