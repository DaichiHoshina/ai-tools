#!/usr/bin/env bash
# TaskCompleted Hook - Agent Teamsでタスクが完了したことを検知
# v2.1.33で追加されたフックイベント

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icon
# ICON_* は hook-utils.sh で定義済み

# jq前提条件チェック
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# タスク情報を抽出（jq 1回で全フィールド取得）
IFS=$'\t' read -r TASK_ID TASK_SUBJECT TEAMMATE_NAME TEAM_NAME CWD SESSION_ID < <(
  extract_json_fields "$INPUT" \
    '.task_id // "unknown"' \
    '.task_subject // "unknown"' \
    '.teammate_name // "unknown"' \
    '.team_name // "unknown"' \
    '.cwd // ""' \
    '.session_id // "unknown"'
)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# cwd フォールバック（JSONになければ環境から取得）
if [ -z "${CWD}" ]; then
  CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"
fi
PROJECT_NAME=$(basename "${CWD}")

# Agent Teams 経由でない場合のフォールバック
# - teammate=unknown → "user"（ユーザー直接実行）
# - team=unknown → プロジェクト名（cwdのbasename）
if [ "${TEAMMATE_NAME}" = "unknown" ]; then
  TEAMMATE_NAME="user"
fi
if [ "${TEAM_NAME}" = "unknown" ]; then
  TEAM_NAME="local:${PROJECT_NAME}"
fi

# ログディレクトリ作成
LOG_DIR="${HOME}/.claude/logs"
mkdir -p "$LOG_DIR"

# ログファイルに記録
LOG_FILE="${LOG_DIR}/agent-team-events.log"
echo "[${TIMESTAMP}] COMPLETED | task_id=${TASK_ID} | subject=${TASK_SUBJECT} | teammate=${TEAMMATE_NAME} | team=${TEAM_NAME} | cwd=${CWD}" >> "$LOG_FILE"

# Task Diary記録（セッション間知識蓄積用）
DIARY_FILE="${LOG_DIR}/task-diary.log"
echo "[${TIMESTAMP}] ${TASK_SUBJECT} | by=${TEAMMATE_NAME} team=${TEAM_NAME} cwd=${PROJECT_NAME}" >> "$DIARY_FILE"

# 統計情報計算（今日の完了タスク数）
TODAY=$(date -u +"%Y-%m-%d")
COMPLETED_TODAY=$(grep -c "${TODAY}.*COMPLETED" "$LOG_FILE" 2>/dev/null || echo "0")

# 1 task = 1 session 原則: セッション内累計タスク数をカウント
# /tmp flag: session_id + YYYYMMDD で stale / 混線回避
_TODAY_YYYYMMDD=$(date -u +"%Y%m%d")
_SESSION_TASK_FLAG="/tmp/claude_task_count_${SESSION_ID}_${_TODAY_YYYYMMDD}.flag"
# 現在カウント読込（ファイル未存在時は 0）
if [[ -f "${_SESSION_TASK_FLAG}" ]]; then
  _TASK_COUNT=$(< "${_SESSION_TASK_FLAG}")
  # 数値以外が入り込んでいる場合は 0 にリセット
  [[ "${_TASK_COUNT}" =~ ^[0-9]+$ ]] || _TASK_COUNT=0
else
  _TASK_COUNT=0
fi
# インクリメント（((n++)) 禁止 → $((...)) 形式）
_TASK_COUNT=$((_TASK_COUNT + 1))
printf '%s' "${_TASK_COUNT}" > "${_SESSION_TASK_FLAG}"

# 累計 2 task 以上で /clear 推奨 notify
if [[ "${_TASK_COUNT}" -ge 2 ]]; then
  echo "[task-done] 累計 ${_TASK_COUNT} tasks 完了、1 task = 1 session 原則で /clear 推奨" >&2
fi

# 結果を返す
# systemMessage のみ。additionalContext の boilerplate は CLAUDE.md の /memory-save ガイドと重複のため削除
jq -n \
  --arg sm "${ICON_SUCCESS} Task completed: ${TASK_SUBJECT} (${TASK_ID}) by ${TEAMMATE_NAME} | Today: ${COMPLETED_TODAY}" \
  '{systemMessage: $sm}'
