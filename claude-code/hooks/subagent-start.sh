#!/usr/bin/env bash
# SubagentStart Hook - サブエージェント起動を検知
# エージェント情報をログ記録し、統計情報を表示

set -euo pipefail

# dirname + cd + pwd の 2 fork → bash parameter expansion に削減
_sa_src="${BASH_SOURCE[0]}"
[[ "${_sa_src}" == /* ]] || _sa_src="${PWD}/${_sa_src}"
SCRIPT_DIR="${_sa_src%/*}"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
# shellcheck source=lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/lib/thresholds.sh"

# jq前提条件チェック
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# エージェント情報を抽出（jq 1回で複数フィールド取得）
IFS=$'\t' read -r AGENT_ID AGENT_TYPE CWD < <(
  extract_json_fields "$INPUT" \
    '.agent_id // "unknown"' \
    '.agent_type // "unknown"' \
    '.cwd // "."'
)
TZ=UTC printf -v TIMESTAMP '%(%Y-%m-%dT%H:%M:%SZ)T' -1

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録（_TH_LOG_ROTATION_LINES 超でローテーション）
LOG_FILE="${LOG_DIR}/subagent-events.log"
# wc -l fork 削減: bash builtin で行数カウント (rotation 閾値 +1 行で打ち切り)
if [[ -f "$LOG_FILE" ]]; then
  _LOG_LINES=0
  _LOG_LIMIT=$(( _TH_LOG_ROTATION_LINES + 1 ))
  while IFS= read -r _ && (( _LOG_LINES < _LOG_LIMIT )); do
    _LOG_LINES=$(( _LOG_LINES + 1 ))
  done < "$LOG_FILE" 2>/dev/null || true
  if (( _LOG_LINES > _TH_LOG_ROTATION_LINES )); then
    tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
  fi
fi

# 重複起動検知: 直近60秒以内に同一 agent_type が起動済みなら警告
_DUP_WARN=""
_NOW_EPOCH="${EPOCHSECONDS:-$(date +%s)}"
if [[ -f "$LOG_FILE" ]]; then
  # awk 1 fork で「最終マッチ行のタイムスタンプ + 24h START カウント」を同時取得
  # index() は固定文字列検索（AGENT_TYPE に正規表現メタ文字が含まれても誤マッチしない）
  # Field 2: -F'[][]' で各角括弧を区切りとし、`[2026-... ]` の中身を取得
  # cutoff: 24h 前を printf -v builtin で生成 (date fork 不要・クロスプラットフォーム)
  _CUTOFF_EPOCH=$(( _NOW_EPOCH - 86400 ))
  TZ=UTC printf -v _CUTOFF_DATE '%(%Y-%m-%dT%H:%M:%SZ)T' "${_CUTOFF_EPOCH}"
  read -r _LAST_SAME RECENT_COUNT < <(
    awk -F'[][]' \
      -v t="type=${AGENT_TYPE} " \
      -v cutoff="${_CUTOFF_DATE}" \
      '
      /START/ {
        if (index($0, t)) last_ts = $2
        if (cutoff == "" || $2 >= cutoff) cnt++
      }
      END { print (last_ts ? last_ts : ""), cnt+0 }
      ' "$LOG_FILE" || echo " 0"
  )
  if [[ -n "$_LAST_SAME" ]]; then
    _LAST_EPOCH=$(_iso8601_to_epoch "$_LAST_SAME" || echo 0)
    if [[ "$_LAST_EPOCH" -gt 0 ]]; then
      _DIFF=$((_NOW_EPOCH - _LAST_EPOCH))
      if [[ "$_DIFF" -lt 60 ]]; then
        _DUP_WARN="⚠️ ${AGENT_TYPE} を${_DIFF}秒前に起動済み。重複起動の可能性あり（同一作業を二重実行していないか確認）。"
      fi
    fi
  fi
else
  RECENT_COUNT=0
fi

echo "[${TIMESTAMP}] START | agent_id=${AGENT_ID} | type=${AGENT_TYPE} | cwd=${CWD}" >> "$LOG_FILE"

# --- Analytics記録をバックグラウンドへ ---
(
  _LIB_DIR="${SCRIPT_DIR}/../lib"
  if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    _PROJECT=$(basename "$CWD")
    analytics_insert_agent_start "$AGENT_ID" "$AGENT_TYPE" "$_PROJECT" 2>/dev/null || true
  fi
) 2>/dev/null &

# 結果を返す（jqで安全にJSON生成）
AC_MSG="**Agent ID**: ${AGENT_ID}
**Type**: ${AGENT_TYPE}
**Working Directory**: ${CWD}
**Recent Activity**: ${RECENT_COUNT} subagents started in last 24h"
if [[ -n "$_DUP_WARN" ]]; then
  AC_MSG="${AC_MSG}

${_DUP_WARN}"
fi

_SM="🚀 Subagent started: ${AGENT_TYPE}"
if [[ -n "$_DUP_WARN" ]]; then
  _SM="⚠️ Subagent重複疑い: ${AGENT_TYPE}"
fi

jq -n \
  --arg sm "$_SM" \
  --arg ac "$AC_MSG" \
  '{systemMessage: $sm, additionalContext: $ac}'
