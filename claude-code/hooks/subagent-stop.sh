#!/usr/bin/env bash
# SubagentStop Hook - サブエージェント終了を検知
# エージェント情報をログ記録し、実行時間を計算

set -euo pipefail

_sas_src="${BASH_SOURCE[0]}"
[[ "${_sas_src}" == /* ]] || _sas_src="${PWD}/${_sas_src}"
SCRIPT_DIR="${_sas_src%/*}"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
# shellcheck source=lib/log-rotation.sh
source "${SCRIPT_DIR}/lib/log-rotation.sh"

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
_rotate_log_by_lines_if_needed "$LOG_FILE"
echo "[${TIMESTAMP}] STOP  | agent_id=${AGENT_ID} | type=${AGENT_TYPE} | cwd=${CWD}" >> "$LOG_FILE"

# --- Analytics記録をバックグラウンドへ ---
(
  _LIB_DIR="${SCRIPT_DIR}/../lib"
  if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    analytics_update_agent_stop "$AGENT_ID" 2>/dev/null || true
  fi
) 2>/dev/null &

# 実行時間計算 + 24h STOP カウントを awk 1 fork で同時取得
DURATION="N/A"
RECENT_COUNT=0
if [ -f "$LOG_FILE" ]; then
  # bash 5.0+ の EPOCHSECONDS builtin で date fork を回避
  _NOW_STOP_EPOCH="${EPOCHSECONDS:-$(date +"%s")}"
  # cutoff epoch を bash 算術で計算し、awk 内で ISO8601 prefix 比較
  # ISO8601 は辞書順 = 時刻順なので先頭 13 文字 (YYYY-MM-DDTHH) 比較で 1h 精度近似
  # 24h 前の時刻を printf -v builtin で生成 (epoch → ISO8601、date fork 不要)
  _CUTOFF_EPOCH=$((_NOW_STOP_EPOCH - 86400))
  TZ=UTC printf -v _CUTOFF_DATE '%(%Y-%m-%dT%H:%M:%SZ)T' "${_CUTOFF_EPOCH}"
  # awk 1 fork: START 文字列取得 + STOP カウントを同時実行
  # start_ts は文字列のまま返し、epoch 変換は _iso8601_to_epoch (BSD/GNU 両対応) で行う
  read -r _START_TIME RECENT_COUNT < <(
    awk -F'[][]' \
      -v aid="agent_id=${AGENT_ID}" \
      -v cutoff="${_CUTOFF_DATE}" \
      '
      /START/ && index($0, aid) { start_ts = $2 }
      /STOP/  {
        if (cutoff == "" || $2 >= cutoff) cnt++
      }
      END { print (start_ts ? start_ts : ""), cnt+0 }
      ' "$LOG_FILE" || echo " 0"
  )
  if [ -n "$_START_TIME" ] && [ "$AGENT_ID" != "unknown" ]; then
    START_EPOCH=$(_iso8601_to_epoch "$_START_TIME" || echo "0")
    if [ "$START_EPOCH" -gt 0 ]; then
      DURATION_SEC=$((_NOW_STOP_EPOCH - START_EPOCH))
      if [ $DURATION_SEC -ge 60 ]; then
        DURATION="${DURATION_SEC}s ($((DURATION_SEC / 60))m $((DURATION_SEC % 60))s)"
      else
        DURATION="${DURATION_SEC}s"
      fi
    fi
  fi
fi

# 結果を返す（jqで安全にJSON生成）
# AC は 1 行に圧縮（busy session で cumulative token 削減、詳細はログファイル参照）
AC_MSG="${AGENT_TYPE} | ${DURATION} | 24h:${RECENT_COUNT} | logs: ~/.claude/logs/subagent-events.log"

jq -n \
  --arg ac "$AC_MSG" \
  '{additionalContext: $ac}'
