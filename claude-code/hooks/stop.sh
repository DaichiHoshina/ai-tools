#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知（macOSバナー + ntfy.sh）

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
# shellcheck source=lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/lib/thresholds.sh"
require_jq

INPUT=$(cat)
send_stop_notification "$INPUT" "" "" "robot" "default"

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "${CWD:-unknown}")
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "Done"')
NOTIFY_BODY="${LAST_MSG:0:80}"
TERM_SEQ=$(build_terminal_sequence "Claude Code [${PROJECT_NAME}] ${ICON_SUCCESS} Done" "${NOTIFY_BODY}" "false")

# === SQL auto-pbcopy: 最終応答中の最後の ```sql ブロックを clipboard へ ===
# 末尾改行は bash $() の auto-strip で 1 個消費、pbcopy 不在環境 (Linux/CI) は silent skip
_SQL_NOTICE=""
if command -v pbcopy >/dev/null 2>&1; then
  LAST_SQL=$(printf '%s' "$LAST_MSG" | awk '
    BEGIN { in_block = 0; buf = ""; last = "" }
    /^```([sS][qQ][lL])$/ && !in_block { in_block = 1; buf = ""; next }
    /^```$/ && in_block { in_block = 0; last = buf; next }
    in_block { buf = buf $0 "\n" }
    END { if (last != "") printf "%s", last }
  ')
  if [[ -n "${LAST_SQL}" ]]; then
    if printf '%s' "${LAST_SQL}" | pbcopy 2>/dev/null; then
      _SQL_NOTICE="📋 最後の SQL ブロック (${#LAST_SQL} chars) を clipboard へコピー"
    else
      echo "[stop.sh] pbcopy failed (sql ${#LAST_SQL} chars), clipboard 未更新" >&2
    fi
  fi
fi

# === memory-save 候補検出: 直近 30 分の commit を走査 ===
_MEMORY_NOTICE=""
if [[ -n "${CWD}" ]] && git -C "${CWD}" rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r _HASH; do
    [[ -z "${_HASH}" ]] && continue
    _SHORT_HASH="${_HASH:0:7}"
    # commit message の 1 行目を取得
    _MSG=$(git -C "${CWD}" log -1 --format='%s' "${_HASH}" 2>/dev/null || true)
    # refactor / feat / fix で始まる commit のみ対象
    if [[ "${_MSG}" =~ ^(refactor|feat|fix) ]]; then
      # 変更 file 数を stat の summary 行から抽出
      _STAT=$(git -C "${CWD}" show --stat "${_HASH}" 2>/dev/null | tail -1 || true)
      # "N files changed" / "1 file changed" の N を抽出
      _FILE_COUNT=$(printf '%s' "${_STAT}" | grep -oE '^[[:space:]]*[0-9]+' | tr -d '[:space:]' || true)
      if [[ -n "${_FILE_COUNT}" ]] && [[ "${_FILE_COUNT}" -ge "${_TH_STOP_MEMORY_FILES}" ]]; then
        _MEMORY_NOTICE="💾 memory-save 候補 (commit ${_SHORT_HASH}: ${_FILE_COUNT} files)、/memory-save 検討"
        break
      fi
    fi
  done < <(git -C "${CWD}" log --since='30 minutes ago' --pretty='%H' 2>/dev/null || true)
fi

# === flow-baseline TSV 自動生成: 当日分が未生成の場合のみ async 実行 ===
_FLOW_BASELINE="$HOME/.claude/scripts/flow-baseline.sh"
_TODAY_TSV="$HOME/.claude/logs/flow-baseline-$(date +%Y%m%d).tsv"
if [[ -x "${_FLOW_BASELINE}" ]] && [[ ! -f "${_TODAY_TSV}" ]]; then
  bash "${_FLOW_BASELINE}" --since 7d >>"$HOME/.claude/logs/hook-errors.log" 2>&1 &
fi

# === 出力: SQL notice と memory notice を連結 ===
_SYSTEM_MSG=""
if [[ -n "${_SQL_NOTICE}" ]] && [[ -n "${_MEMORY_NOTICE}" ]]; then
  _SYSTEM_MSG="${_SQL_NOTICE}
${_MEMORY_NOTICE}"
elif [[ -n "${_SQL_NOTICE}" ]]; then
  _SYSTEM_MSG="${_SQL_NOTICE}"
elif [[ -n "${_MEMORY_NOTICE}" ]]; then
  _SYSTEM_MSG="${_MEMORY_NOTICE}"
fi

if [[ -n "${_SYSTEM_MSG}" ]]; then
  jq -n --arg ts "$TERM_SEQ" --arg msg "$_SYSTEM_MSG" '{terminalSequence: $ts, systemMessage: $msg}'
else
  jq -n --arg ts "$TERM_SEQ" '{terminalSequence: $ts}'
fi
