#!/usr/bin/env bash
# Stop Hook - タスク完了時の通知（macOSバナー + ntfy.sh）

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

_stop_src="${BASH_SOURCE[0]}"
[[ "${_stop_src}" == /* ]] || _stop_src="${PWD}/${_stop_src}"
SCRIPT_DIR="${_stop_src%/*}"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
# shellcheck source=lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/lib/thresholds.sh"
require_jq

INPUT=$(cat)
# 通知は「user の入力待ちになった時」だけ鳴らす。send_stop_notification 側で
# (1) background task (agent / shell) 実行中の Stop、(2) session_id なし (test fixture /
# 手動 smoke)、(3) cursor_version あり (Claude Code 以外の caller) を skip し、
# 一言 message は short-message skip (CLAUDE_STOP_NOTIFY_MIN_LEN, default 8) で吸収する。
# 明示的に off にしたい時は CLAUDE_STOP_NOTIFY=0 を export する。
if [[ "${CLAUDE_STOP_NOTIFY:-1}" != "0" ]]; then
  send_stop_notification "$INPUT" "" "" "robot" "default"
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
PROJECT_NAME=$(basename "${CWD:-unknown}")
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "Done"')
TERM_SEQ=$(build_terminal_sequence "Claude Code [${PROJECT_NAME}] ${ICON_SUCCESS} Done" "" "false")

# === raw tool-call XML guard: 応答本文に生のツール呼び出し痕跡があれば block して正規 function-call をやり直させる ===
# harness 内部記法 (<invoke name= / <parameter name= / antml:invoke / antml:parameter) は
# ユーザ向け prose に正当に出ない。検出時のみ block するので、直したターンは素通り = 無限ループしない。
# 再注入を避けるため、JP 注意書き自体に該当 literal を含めない (pattern は変数で分割保持)。
_RAW_TC_HIT=""
if printf '%s' "$LAST_MSG" | grep -qE '<(antml:)?(invoke|parameter)[[:space:]]+name=|^[[:space:]]*<(antml:)?function_calls'; then
  _RAW_TC_HIT="1"
fi
if [[ -n "${_RAW_TC_HIT}" ]]; then
  jq -n --arg reason '応答本文に生のツール呼び出し XML (invoke/parameter タグ) がテキストとして出力された。これは実行されず malformed になる。該当 XML テキストを本文から削除し、正規の function-call 機構でツールを呼び直すこと。本文はユーザ向け説明 (日本語 prose) のみにする。' \
    '{decision: "block", reason: $reason}'
  exit 0
fi

# === chat 応答 JP 文体検査: 高精度 NG 語は block で自己修正させ、低精度 + 構造系は warn 通知 ===
# loop 防止 2 重化: (1) stop_hook_active=true (block 起因の再 Stop) は検査 skip で 1 stop 1 回を構造保証、
# (2) 同 session の block 5 回到達で log-only へ降格 (辞書と chat 内容が構造的に衝突する session への保険)。
# 誤爆時の脱出口: export JP_QUALITY_STOP_CHECK=0
_STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
_STOP_SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
_JPQ_WARN_MSG=""
if [[ "${JP_QUALITY_STOP_CHECK:-1}" == "1" && "${_STOP_HOOK_ACTIVE}" != "true" && "${LAST_MSG}" != "Done" ]]; then
  # shellcheck source=../lib/jp-quality-check.sh
  source "${SCRIPT_DIR}/../lib/jp-quality-check.sh"
  _chat_quality_check "$LAST_MSG"
  if [[ -n "${_CHAT_BLOCK_REASON}" && "${JP_QUALITY_BLOCK_OFF:-0}" == "1" ]]; then
    _append_jp_quality_log "chat" "${_CHAT_BLOCK_REASON}" "log-only-downgrade"
    _JPQ_WARN_MSG="${ICON_WARNING:-▲} chat NG 語 (JP_QUALITY_BLOCK_OFF=1 で warn 降格): ${_CHAT_BLOCK_REASON}"
  elif [[ -n "${_CHAT_BLOCK_REASON}" ]]; then
    printf -v _JPQ_DATE '%(%Y%m%d)T' -1
    _JPQ_COUNT_FILE="/tmp/claude-stop-jpq-count-${_STOP_SESSION_ID:-$$}-${_JPQ_DATE}"
    _JPQ_COUNT=$(cat "${_JPQ_COUNT_FILE}" 2>/dev/null || echo 0)
    [[ "${_JPQ_COUNT}" =~ ^[0-9]+$ ]] || _JPQ_COUNT=0
    if (( _JPQ_COUNT < 5 )); then
      printf '%s' "$(( _JPQ_COUNT + 1 ))" > "${_JPQ_COUNT_FILE}" 2>/dev/null || true
      jq -n --arg reason "${_CHAT_BLOCK_REASON}" '{decision: "block", reason: $reason}'
      exit 0
    fi
    _append_jp_quality_log "chat" "${_CHAT_BLOCK_REASON}" "log-only-downgrade"
    _JPQ_WARN_MSG="${ICON_WARNING:-▲} chat NG 語 (block ${_JPQ_COUNT} 回到達で log-only 降格): ${_CHAT_BLOCK_REASON}"
  elif [[ -n "${_CHAT_WARN_MSG}" ]]; then
    _JPQ_WARN_MSG="${_CHAT_WARN_MSG}"
  fi
  # warn は systemMessage だけだと AI に矯正が働かないため、state file 経由で
  # 次 turn の UserPromptSubmit (additionalContext) に還流する (read-and-delete)。
  if [[ -n "${_JPQ_WARN_MSG}" ]]; then
    printf -v _JPQ_WARN_DATE '%(%Y%m%d)T' -1
    printf '%s' "${_JPQ_WARN_MSG}" > "/tmp/claude-stop-jpq-warn-${_STOP_SESSION_ID:-$$}-${_JPQ_WARN_DATE}" 2>/dev/null || true
  fi
fi

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
printf -v _STOP_DATE '%(%Y%m%d)T' -1
_TODAY_TSV="$HOME/.claude/logs/flow-baseline-${_STOP_DATE}.tsv"
if [[ -x "${_FLOW_BASELINE}" ]] && [[ ! -f "${_TODAY_TSV}" ]]; then
  bash "${_FLOW_BASELINE}" --since 7d >>"$HOME/.claude/logs/hook-info.log" 2>&1 &
fi

# === 出力: SQL notice / memory notice / JP 文体 warn を連結 ===
_SYSTEM_MSG=""
for _part in "${_SQL_NOTICE}" "${_MEMORY_NOTICE}" "${_JPQ_WARN_MSG}"; do
  [[ -z "${_part}" ]] && continue
  _SYSTEM_MSG="${_SYSTEM_MSG:+${_SYSTEM_MSG}
}${_part}"
done

if [[ -n "${_SYSTEM_MSG}" ]]; then
  jq -n --arg ts "$TERM_SEQ" --arg msg "$_SYSTEM_MSG" '{terminalSequence: $ts, systemMessage: $msg}'
else
  jq -n --arg ts "$TERM_SEQ" '{terminalSequence: $ts}'
fi
