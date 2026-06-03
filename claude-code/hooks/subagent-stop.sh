#!/usr/bin/env bash
# SubagentStop Hook - サブエージェント終了を検知
# エージェント情報をログ記録し、実行時間を計算

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

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
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録（1000行超でローテーション）
LOG_FILE="${LOG_DIR}/subagent-events.log"
if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
  tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
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
  # 24h 前の時刻を printf で生成（date fork 不要）
  _CUTOFF_EPOCH=$((_NOW_STOP_EPOCH - 86400))
  # epoch → ISO8601 は bash 単体では困難なため date fork 1 本だけ維持
  _CUTOFF_DATE=$(date -u -r "${_CUTOFF_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || date -u -d "@${_CUTOFF_EPOCH}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
    || echo "")
  # awk 1 fork: START epoch 変換 + STOP カウントを同時実行（date -j fork を排除）
  # mktime() は gawk 拡張。macOS の awk は mawk 相当で mktime 非対応のため
  # ISO8601 を文字列分解して epoch 秒を手計算するのは複雑すぎるため
  # start_ts は文字列のまま返し、後続の date -j fork 1 本のみ維持
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
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$_START_TIME" +"%s" 2>/dev/null || echo "0")
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
