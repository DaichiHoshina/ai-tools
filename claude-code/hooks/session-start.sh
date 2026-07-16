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

# dirname + cd + pwd の 2 fork → bash parameter expansion に削減
_ss_src="${BASH_SOURCE[0]}"
[[ "${_ss_src}" == /* ]] || _ss_src="${PWD}/${_ss_src}"
SCRIPT_DIR="${_ss_src%/*}"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icons
# ICON_* は hook-utils.sh で定義済み

# stat コマンドの mtime フラグを先頭で 1 回判定（macOS: -f%m / GNU: -c%Y）
# 各キャッシュ age チェックで dual call していた失敗 fork を排除する
if stat -c%Y /dev/null >/dev/null 2>&1; then
    _SS_STAT_FLAG="-c%Y"
else
    _SS_STAT_FLAG="-f%m"
fi

# jq前提条件チェック
require_jq

# JSON入力を読み込み、jq 1回で全フィールド取得（v2.2.1 fork削減 / _SS_INPUT 変数廃止）
eval "$(jq -r '@sh "_SS_SESSION_ID=\(.session_id // "") _CWD=\(.cwd // "")"')"
# stdin JSON が canonical source。env CLAUDE_CODE_SESSION_ID は session 切替時に
# 前 session 値が leak することがあり fallback 専用にする (incident 2026-06-25)
_SS_SESSION_ID="${_SS_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-unknown}}"
_SS_PROJECT=$(basename "${_CWD:-.}")
# 日付を事前取得してキャッシュ（date fork を hook 起動 1 回に抑える）
printf -v _SS_DATE_TODAY '%(%Y%m%d)T' -1

# git 状態を 1 回だけ取得してキャッシュ（statusline marker + session title ブロックで再利用）
# git fork を 2 回 → 1 回に削減:
# rev-parse --abbrev-ref HEAD は git repo 外で失敗するため --git-dir チェックを兼ねる
_SS_IS_GIT=false
_SS_GIT_BRANCH=""
if [[ -n "${_CWD:-}" ]] && [[ -d "${_CWD}" ]]; then
    if _SS_GIT_BRANCH=$(git -C "${_CWD}" rev-parse --abbrev-ref HEAD 2>/dev/null); then
        _SS_IS_GIT=true
    fi
fi

# ====================================
# statusline マーカー初期化
# ====================================
# /tmp/claude-wt-${SESSION_ID}-YYYYMMDD は post-tool-use.sh が cd 検出時に書き込み、
# statusline.js が cwd 解決の優先元として読む。session 開始時に最新の cwd で
# 初期化することで、過去 session で書かれた古いマーカーが残るのを防ぐ
# （例: 同セッションで一時的 cd した後、cd 含まない Bash が続いてマーカーが
# 古いままになるケースの再発防止は別途必要、ここでは session 境界のみ対処）。
if [[ -n "${_SS_SESSION_ID}" && "${_SS_SESSION_ID}" != "unknown" && -n "${_CWD:-}" && -d "${_CWD:-}" ]]; then
  if [[ "${_SS_IS_GIT}" == "true" ]]; then
    _SS_ABS=$(cd "${_CWD}" && pwd)
    echo "${_SS_ABS}" > "/tmp/claude-wt-${_SS_SESSION_ID}-${_SS_DATE_TODAY}"
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
  _CACHE_AGE=$(( EPOCHSECONDS - $(stat ${_SS_STAT_FLAG} "${_DIAG_CACHE}" 2>/dev/null || echo 0) ))
  if [[ ${_CACHE_AGE} -lt 86400 ]]; then
    _DIAG_MSG=$(<"${_DIAG_CACHE}")
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

# --- 多リポ配下起動ガード（cwd単位 1時間キャッシュ）---
# cwd がリポジトリルートでない（.git 無し）かつ子孫に複数の git リポがある場合、
# git/rg/Glob が全体を舐めに行き体感が極端に遅くなる。個別リポ cd を促す警告。
# glob 走査は重いため cwd ハッシュ単位で 1h キャッシュ化。
_CWD_GUARD_MSG=""
if [[ -n "${_CWD:-}" ]] && [[ -d "${_CWD}" ]] && [[ ! -d "${_CWD}/.git" ]]; then
  _CWD_SAFE="${_CWD//\//_}"
  _CWD_CACHE="${HOME}/.claude/cache/cwd-multi-repo-${_CWD_SAFE}.cache"
  _CWD_CACHE_HIT=false
  if [[ -f "${_CWD_CACHE}" ]]; then
    _CWD_CACHE_AGE=$(( EPOCHSECONDS - $(stat ${_SS_STAT_FLAG} "${_CWD_CACHE}" 2>/dev/null || echo 0) ))
    if [[ ${_CWD_CACHE_AGE} -lt 3600 ]]; then
      _CWD_GUARD_MSG=$(<"${_CWD_CACHE}")
      _CWD_CACHE_HIT=true
    fi
  fi
  if [[ "${_CWD_CACHE_HIT}" == "false" ]]; then
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
    mkdir -p "$(dirname "${_CWD_CACHE}")"
    printf '%s' "${_CWD_GUARD_MSG}" > "${_CWD_CACHE}"
  fi
fi

# --- linked worktree の owner CLAUDE.md auto-load ---
# linked worktree (~/ghq/worktrees/<repo>-*) は親 org dir の外にあるため、
# org 階層 owner CLAUDE.md (~/ghq/github.com/<org>/CLAUDE.md) が
# directory-based auto-load されない。session 開始時に hook が中身を読み context 注入し、
# AI の自発判断 / onboarding 経由に依存せず org 規範を効かせる。
# cache は owner CLAUDE.md の mtime 追従 (org 規範更新を取りこぼさない)。
_WT_OWNER_MSG=""
if [[ "${_SS_IS_GIT}" == "true" ]] && [[ -n "${_CWD:-}" ]]; then
  _WT_OWNER_CLAUDE="$(_resolve_worktree_owner_claude_md "${_CWD}" 2>/dev/null || true)"
  if [[ -n "${_WT_OWNER_CLAUDE}" ]] && [[ -f "${_WT_OWNER_CLAUDE}" ]]; then
    _WT_OWNER_SAFE="${_CWD//\//_}"
    _WT_OWNER_CACHE="${HOME}/.claude/cache/wt-owner-claude-${_WT_OWNER_SAFE}.cache"
    _WT_OWNER_CACHE_HIT=false
    # cache が owner CLAUDE.md より新しければ再読込しない (source mtime 追従)
    if [[ -f "${_WT_OWNER_CACHE}" ]]; then
      _WT_OWNER_CACHE_MT=$(stat ${_SS_STAT_FLAG} "${_WT_OWNER_CACHE}" 2>/dev/null || echo 0)
      _WT_OWNER_SRC_MT=$(stat ${_SS_STAT_FLAG} "${_WT_OWNER_CLAUDE}" 2>/dev/null || echo 0)
      if [[ ${_WT_OWNER_CACHE_MT} -ge ${_WT_OWNER_SRC_MT} ]]; then
        _WT_OWNER_MSG=$(<"${_WT_OWNER_CACHE}")
        _WT_OWNER_CACHE_HIT=true
      fi
    fi
    if [[ "${_WT_OWNER_CACHE_HIT}" == "false" ]]; then
      # サイズ安全弁: 16KB 超は全文でなく先頭 200 行 + 明示 Read 促進で肥大回避
      _WT_OWNER_BYTES=$(wc -c < "${_WT_OWNER_CLAUDE}" 2>/dev/null || echo 0)
      _WT_OWNER_HEAD="${ICON_WARNING} **linked worktree で作業中**: 親 org owner CLAUDE.md (\`${_WT_OWNER_CLAUDE}\`) は親 dir 外のため auto-load されない。以下の org 規範に従うこと。\n\n"
      if [[ "${_WT_OWNER_BYTES}" -gt 16384 ]]; then
        _WT_OWNER_BODY="$(head -200 "${_WT_OWNER_CLAUDE}")\n\n(以下省略。全文は上記 path を Read すること)"
      else
        _WT_OWNER_BODY="$(<"${_WT_OWNER_CLAUDE}")"
      fi
      _WT_OWNER_MSG="${_WT_OWNER_HEAD}---\n${_WT_OWNER_BODY}\n---\n"
      mkdir -p "$(dirname "${_WT_OWNER_CACHE}")"
      printf '%s' "${_WT_OWNER_MSG}" > "${_WT_OWNER_CACHE}"
    fi
  fi
fi

# NOTE: project-scope .mcp.json 自動再生成は user-scope MCP 登録に移行したため撤去
# (2026-06-17)。Serena MCP は ~/.claude.json の mcpServers で --project-from-cwd 起動。

# --- Worktree Memory Symlink（バックグラウンド実行）---
# symlink 操作のみで出力に依存しないため非同期化
( ensure_worktree_memory_link "${_CWD:-}" 2>/dev/null || true ) &

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
# plugin count: 24h cache で jq fork 削減
_SS_PLUGIN_CACHE="${HOME}/.claude/cache/plugin-count.cache"
_SS_PLUGIN_COUNT=0
_SS_PLUGIN_CACHE_HIT=false
if [[ -f "${_SS_PLUGIN_CACHE}" ]]; then
  _SS_PLUGIN_CACHE_AGE=$(( EPOCHSECONDS - $(stat ${_SS_STAT_FLAG} "${_SS_PLUGIN_CACHE}" 2>/dev/null || echo 0) ))
  if [[ ${_SS_PLUGIN_CACHE_AGE} -lt 86400 ]]; then
    _SS_PLUGIN_COUNT=$(<"${_SS_PLUGIN_CACHE}")
    _SS_PLUGIN_CACHE_HIT=true
  fi
fi
if [[ "${_SS_PLUGIN_CACHE_HIT}" == "false" ]]; then
  _SS_PLUGIN_COUNT=$(jq '.enabledPlugins | length' "${HOME}/.claude/settings.json" 2>/dev/null || echo 0)
  mkdir -p "$(dirname "${_SS_PLUGIN_CACHE}")"
  printf '%s' "${_SS_PLUGIN_COUNT}" > "${_SS_PLUGIN_CACHE}"
fi
TZ=UTC printf -v _SS_TS '%(%Y-%m-%dT%H:%M:%SZ)T' -1
echo "[${_SS_TS}] session_id=${_SS_SESSION_ID} duration_ms=${_SS_DURATION_MS} plugin_count=${_SS_PLUGIN_COUNT}" >> "${_SS_TIMING_LOG}" 2>/dev/null || true
# 直近 1000 行に切り詰め: 1% 確率で実行 (毎回の wc fork 削減)
if (( RANDOM % 100 == 0 )); then
  if [[ -f "${_SS_TIMING_LOG}" ]] && [[ $(wc -l < "${_SS_TIMING_LOG}" 2>/dev/null || echo 0) -gt 1000 ]]; then
    tail -n 1000 "${_SS_TIMING_LOG}" > "${_SS_TIMING_LOG}.tmp" 2>/dev/null \
        && mv "${_SS_TIMING_LOG}.tmp" "${_SS_TIMING_LOG}" 2>/dev/null || true
  fi
  # hook-errors.log は settings.json の 2>> redirect 先で inline rotation 不可のためここで size 回収する
  # shellcheck source=lib/log-rotation.sh
  source "${SCRIPT_DIR}/lib/log-rotation.sh" 2>/dev/null || true
  if declare -f _rotate_log_if_needed &>/dev/null; then
    _rotate_log_if_needed "$HOME/.claude/logs/hook-errors.log" 2
  fi
fi

# /tmp/claude-* marker GC: 1% 確率で 7 日以上古い marker を非同期削除
# 対象: claude-ngdict-* / claude-ng-inject-* / claude-session-scan-* / claude-transcript-decl-*
#       / claude_session_bloat_* / claude-last-prompt-* / claude-deleg-checklist-*
#       / claude-serena-fail-count-* / claude-today-commits-* / claude-fail-prompt-* / claude-wt-*
# 各 hook が期限切れ回収せず溜まる問題への対応 (現 session の marker は mtime 新しいので保護)
if (( RANDOM % 100 == 0 )); then
  (
    for _pat in 'claude-ngdict-*' 'claude-ng-inject-*' 'claude-session-scan-*' \
                'claude-transcript-decl-*' 'claude_session_bloat_*' 'claude-last-prompt-*' \
                'claude-deleg-checklist-*' 'claude-serena-fail-count-*' \
                'claude-today-commits-*' 'claude-fail-prompt-*' 'claude-wt-*'; do
      find /tmp -maxdepth 1 -name "${_pat}" -type f -mtime +7 -delete 2>/dev/null
    done
  ) &
fi

# analytics_start_session はバックグラウンド実行（SQLite append のみ、出力不要）
_SS_LIB_DIR="${SCRIPT_DIR}/../lib"
if [[ -f "${_SS_LIB_DIR}/analytics-writer.sh" ]]; then
    (
      source "${_SS_LIB_DIR}/analytics-writer.sh"
      analytics_start_session "${_SS_SESSION_ID}" "${_SS_PROJECT}" "${_SS_DURATION_MS}" 2>/dev/null || true
    ) &
fi

# --- Directory Color ---
# jq 1回で default + mappings を取得して bash側でマッチング（fork大幅削減）
# mtime cache: dir-colors.json が変わった時のみ jq 再実行
_COLOR_CONFIG="${HOME}/.claude/config/dir-colors.json"
_COLOR_PARSED_CACHE="${HOME}/.claude/cache/dir-colors-parsed.cache"
_SESSION_COLOR="default"
if [[ -f "${_COLOR_CONFIG}" ]]; then
    _COLOR_DATA=""
    _COLOR_CONFIG_MTIME=$(stat ${_SS_STAT_FLAG} "${_COLOR_CONFIG}" 2>/dev/null || echo 0)
    if [[ -f "${_COLOR_PARSED_CACHE}" ]]; then
        _COLOR_CACHE_MTIME=$(stat ${_SS_STAT_FLAG} "${_COLOR_PARSED_CACHE}" 2>/dev/null || echo 0)
        if [[ ${_COLOR_CACHE_MTIME} -ge ${_COLOR_CONFIG_MTIME} ]]; then
            _COLOR_DATA=$(<"${_COLOR_PARSED_CACHE}")
        fi
    fi
    if [[ -z "${_COLOR_DATA}" ]]; then
        # 1行目=default、2行目以降="pattern\tcolor"
        _COLOR_DATA=$(jq -r '.default // "default", (.mappings[]? | "\(.pattern)\t\(.color)")' "${_COLOR_CONFIG}" 2>/dev/null || echo "default")
        mkdir -p "$(dirname "${_COLOR_PARSED_CACHE}")"
        printf '%s' "${_COLOR_DATA}" > "${_COLOR_PARSED_CACHE}"
    fi
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
if [[ ${#_HARNESS_WARNINGS[@]} -gt 0 ]] || [[ -n "${_CWD_GUARD_MSG}" ]] || [[ -n "${_WT_OWNER_MSG}" ]]; then
  _SM_PREFIX="${ICON_WARNING}"
fi

_AC_BASE="**memory 読込 (条件付き、token 節約)**: 実作業 (編集 / 実装 / 調査 / debug) を開始する時のみ \`~/ai-tools/memory/MEMORY.md\` (3 tool 共有 index) を read し、関連 topic の個別 file を必要時に read する。作業対象 repo が \`~/ghq/github.com/<org>/\` 配下 (linked worktree 含む、origin URL で判定) の場合、\`~/ghq/github.com/<org>/memory/MEMORY.md\` (org 作業 memory index) が存在すればそれも read する。質問応答や軽い確認のみの session では読まない。\`mcp__serena__list_memories\` も同条件 (project は --project-from-cwd で自動 activate 済)\n\n**追加推奨**: コーディング作業を開始する場合、最初の編集前に \`/load-guidelines\` を実行"
_AC_PREFIX=""
if [[ -n "${_WT_OWNER_MSG}" ]]; then
    _AC_PREFIX+="${_WT_OWNER_MSG}"
fi
if [[ -n "${_CWD_GUARD_MSG}" ]]; then
    _AC_PREFIX+="${_CWD_GUARD_MSG}"
fi
if [[ -n "${_DIAG_MSG}" ]]; then
    _AC_PREFIX+="${_DIAG_MSG}"
fi

# --- memory promote trigger 提示 (1 日 1 回上限) ---
# trigger A: MEMORY.md 50 行超 / trigger B: 同 prefix 3 file 以上
# 詳細: ~/.claude/references-private/memory-promotion-flow.md §6
_PROMOTE_STATE_DIR="${HOME}/.claude/state"
# memory は 2026-07-09 集約で ~/ai-tools/memory/ に一本化済 (3 tool 共有 SoT、cwd 非依存)。
# 旧実装は ~/.claude/projects/<encoded-cwd>/memory/MEMORY.md を見ていたが、そこに実 file が
# 無く trigger が常に空振りしていた (2026-07-13 修正)。実 SoT path を直接指す。
_MEMORY_INDEX="${MEMORY_SAVE_DIR:-${HOME}/ai-tools/memory}/MEMORY.md"
[[ -f "${_MEMORY_INDEX}" ]] || _MEMORY_INDEX=""
# state file の分離 key は cwd slug を維持 (promote 提示の 1 日 1 回上限は project 単位)
_CWD_SLUG=""
if [[ -n "${_CWD:-}" ]]; then
    _CWD_SLUG="${_CWD//\//-}"
    _CWD_SLUG="${_CWD_SLUG//./-}"
fi
# state file は project 別 (memory も project 別、reminder も project 単位で 1 日 1 回)
_PROMOTE_STATE_FILE="${_PROMOTE_STATE_DIR}/promote-prompted-${_CWD_SLUG:-default}-${_SS_DATE_TODAY}"
if [[ -f "${_MEMORY_INDEX}" ]] && [[ ! -f "${_PROMOTE_STATE_FILE}" ]]; then
    # dirname fork 削減: bash parameter expansion で親ディレクトリを取得
    _MEMORY_DIR="${_MEMORY_INDEX%/*}"
    # wc -l fork 削減: bash builtin read でカウント (先頭51行で打ち切り)
    _MEMORY_LINES=0
    while IFS= read -r _ && (( _MEMORY_LINES < 51 )); do
        _MEMORY_LINES=$(( _MEMORY_LINES + 1 ))
    done < "${_MEMORY_INDEX}" 2>/dev/null || true
    _PROMOTE_HITS=()
    # trigger A
    if (( _MEMORY_LINES > 50 )); then
        _PROMOTE_HITS+=("MEMORY.md ${_MEMORY_LINES}+ 行 (>50, trigger A)")
    fi
    # trigger B: 同 prefix 3 file 以上 (feedback_xxx_*, reference_xxx_*, project_xxx_*, work-context-xxx_*)
    # prefix = 先頭 2 token (例: feedback_design_doc → feedback_design)
    # find|grep|sed|sort|uniq -c|awk の 6-fork chain → bash glob + 連想配列に置換
    declare -A _TOPIC_MAP=()
    for _mf in "${_MEMORY_DIR}"/*.md; do
        [[ -f "${_mf}" ]] || continue
        _bn="${_mf##*/}"          # basename 相当 (fork なし)
        _bn="${_bn%.md}"          # .md 除去
        [[ "${_bn}" == "MEMORY" ]] && continue
        # prefix 抽出: sed -E 's/^([a-z]+([_-][a-z0-9]+)?).*$/\1/' と同等
        # bash regex で先頭 2 token マッチ (lower は sed 前に実施済み相当)
        _bnl="${_bn,,}"
        if [[ "${_bnl}" =~ ^([a-z]+([_-][a-z0-9]+)?) ]]; then
            _pfx="${BASH_REMATCH[1]}"
        else
            _pfx="${_bnl:0:20}"
        fi
        _TOPIC_MAP["${_pfx}"]=$(( ${_TOPIC_MAP["${_pfx}"]:-0} + 1 ))
    done
    _TOPIC_COUNTS=""
    for _pfx in "${!_TOPIC_MAP[@]}"; do
        if (( _TOPIC_MAP["${_pfx}"] >= 3 )); then
            _TOPIC_COUNTS+="${_pfx}(${_TOPIC_MAP["${_pfx}"]}) "
        fi
    done
    unset _TOPIC_MAP _mf _bn _bnl _pfx
    if [[ -n "${_TOPIC_COUNTS}" ]]; then
        _PROMOTE_HITS+=("同 topic 3 file 以上: ${_TOPIC_COUNTS} (trigger B)")
    fi
    if (( ${#_PROMOTE_HITS[@]} > 0 )); then
        _PROMOTE_MSG="${ICON_WARNING} memory 昇格候補あり: $(printf '%s; ' "${_PROMOTE_HITS[@]}")\n  → \`/promote\` で SoT 集約検討 (詳細: ~/.claude/references-private/memory-promotion-flow.md)\n\n"
        _AC_PREFIX+="${_PROMOTE_MSG}"
        # state file 作成 (本日 1 回限り)
        mkdir -p "${_PROMOTE_STATE_DIR}"
        touch "${_PROMOTE_STATE_FILE}"
    fi
fi
if [[ -n "${_AC_PREFIX}" ]]; then
    _AC_FULL="${_AC_PREFIX}\n${_AC_BASE}"
else
    _AC_FULL="${_AC_BASE}"
fi

# ====================================
# sessionTitle (2.1.152 hookSpecificOutput.sessionTitle)
# repo名 + ブランチ名でセッションを識別可能にする
# ====================================
_SESSION_TITLE=""
if [[ -n "${_CWD:-}" && -d "${_CWD:-}" ]]; then
    _REPO_NAME=$(basename "${_CWD}")
    # _SS_IS_GIT / _SS_GIT_BRANCH は冒頭で取得済み（git fork 再実行なし）
    if [[ "${_SS_IS_GIT}" == "true" ]]; then
        if [[ -n "${_SS_GIT_BRANCH}" ]]; then
            _SESSION_TITLE="${_REPO_NAME} @ ${_SS_GIT_BRANCH}"
        else
            _SESSION_TITLE="${_REPO_NAME}"
        fi
    else
        _SESSION_TITLE="${_REPO_NAME}"
    fi
fi

if [[ -n "${_SESSION_TITLE}" ]]; then
    jq -n \
      --arg sm "${_SM_PREFIX} Session初期化完了 [color:${_SESSION_COLOR}]" \
      --arg ac "${_AC_FULL}" \
      --arg color "${_SESSION_COLOR}" \
      --arg title "${_SESSION_TITLE}" \
      '{systemMessage: $sm, additionalContext: $ac, color: $color, hookSpecificOutput: {hookEventName: "SessionStart", sessionTitle: $title}}'
else
    jq -n \
      --arg sm "${_SM_PREFIX} Session初期化完了 [color:${_SESSION_COLOR}]" \
      --arg ac "${_AC_FULL}" \
      --arg color "${_SESSION_COLOR}" \
      '{systemMessage: $sm, additionalContext: $ac, color: $color}'
fi
