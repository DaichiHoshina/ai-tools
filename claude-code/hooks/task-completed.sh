#!/usr/bin/env bash
# TaskCompleted Hook - Agent Teamsでタスクが完了したことを検知
# v2.1.33で追加されたフックイベント

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icon
ICON_SUCCESS=$'\u2713'  # check-circle

# jq前提条件チェック
require_jq

# JSON入力を読み込む
INPUT=$(cat)

# タスク情報を抽出（公式スキーマ準拠）
TASK_ID=$(echo "$INPUT" | jq -r '.task_id // "unknown"')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // "unknown"')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // "unknown"')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
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
  TEAM_NAME="${PROJECT_NAME}"
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

# 結果を返す
jq -n \
  --arg sm "${ICON_SUCCESS} Task completed: ${TASK_SUBJECT} (${TASK_ID}) by ${TEAMMATE_NAME} | Today: ${COMPLETED_TODAY} tasks done" \
  --arg ctx "タスク完了をtask-diary.logに記録済み。重要な学びがあれば /memory-save でSerena memoryにも保存を検討。" \
  '{systemMessage: $sm, additionalContext: $ctx}'
