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
if [[ -f "$LOG_FILE" ]] && [[ $(wc -l < "$LOG_FILE" | tr -d ' ') -gt 1000 ]]; then
  tail -500 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi
echo "[${TIMESTAMP}] STOP  | agent_id=${AGENT_ID} | type=${AGENT_TYPE} | cwd=${CWD}" >> "$LOG_FILE"

# --- Analytics記録 ---
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="${_HOOK_DIR}/../lib"
if [[ -f "${_LIB_DIR}/analytics-writer.sh" ]]; then
    source "${_LIB_DIR}/analytics-writer.sh"
    analytics_update_agent_stop "$AGENT_ID" 2>/dev/null || true
fi

# 実行時間計算（同じagent_idのSTARTとSTOPの差分）
DURATION="N/A"
if [ -f "$LOG_FILE" ] && [ "$AGENT_ID" != "unknown" ]; then
  # awk 1 fork で「START 行で agent_id 一致の最終行のタイムスタンプ」抽出
  # /START/ で START 行に絞り、index() で固定文字列マッチ（AGENT_ID にメタ文字含むケースで誤マッチ防止）
  # Field 2: -F'[][]' で各角括弧を区切りとし、`[2026-... ]` の中身を取得
  START_TIME=$(awk -F'[][]' -v aid="agent_id=${AGENT_ID}" '/START/ && index($0, aid) {ts=$2} END{print ts}' "$LOG_FILE" || echo "")
  if [ -n "$START_TIME" ]; then
    # 簡易的な秒数計算（dateコマンドで変換）
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +"%s" 2>/dev/null || echo "0")
    STOP_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TIMESTAMP" +"%s" 2>/dev/null || date +"%s")
    if [ "$START_EPOCH" -gt 0 ]; then
      DURATION_SEC=$((STOP_EPOCH - START_EPOCH))
      if [ $DURATION_SEC -ge 60 ]; then
        DURATION="${DURATION_SEC}s ($((DURATION_SEC / 60))m $((DURATION_SEC % 60))s)"
      else
        DURATION="${DURATION_SEC}s"
      fi
    fi
  fi
fi

# 統計情報計算（過去24時間の完了したサブエージェント数）
if [ -f "$LOG_FILE" ]; then
  CUTOFF=$(date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  if [ -n "$CUTOFF" ]; then
    RECENT_COUNT=$(grep "STOP" "$LOG_FILE" | awk -v cutoff="$CUTOFF" -F'[][]' '{if ($2 >= cutoff) count++} END {print count+0}')
  else
    RECENT_COUNT=$(grep -c "STOP" "$LOG_FILE" || echo "0")
  fi
else
  RECENT_COUNT=0
fi

# 結果を返す（jqで安全にJSON生成）
AC_MSG="**Agent ID**: ${AGENT_ID}
**Type**: ${AGENT_TYPE}
**Duration**: ${DURATION}
**Recent Activity**: ${RECENT_COUNT} subagents completed in last 24h

Subagent logs: ~/.claude/logs/subagent-events.log"

jq -n \
  --arg sm "✅ Subagent completed: ${AGENT_TYPE}" \
  --arg ac "$AC_MSG" \
  '{systemMessage: $sm, additionalContext: $ac}'
