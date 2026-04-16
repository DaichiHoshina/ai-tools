#!/usr/bin/env bash
# PostCompact Reload Hook - compact後の自動コンテキスト復元
# PostCompact イベントで発火（v2.1.76+公式フック）
# compact後に /reload 相当の処理を自動実行するよう指示
# 改善: git/ファイル情報を直接埋め込み、Serena MCP不要でも最低限の復元が可能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icons
ICON_SUCCESS=$'\u2713'    # check-circle

# jq前提条件チェック
require_jq

# JSON入力を消費（未使用だが読み捨て必要）
cat > /dev/null

NL=$'\n'

# --- 静的コンテキスト収集（MCP不要） ---
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GIT_STATUS=$(git status --short 2>/dev/null | head -20 || echo "")
GIT_LOG=$(git log --oneline -5 2>/dev/null || echo "")
PROJECT_DIR=$(pwd)
RECENT_FILES=$(git diff --name-only HEAD~3..HEAD 2>/dev/null | head -15 || echo "")

SYSTEM_MESSAGE="${ICON_SUCCESS} COMPACT完了 - コンテキスト自動復元"
ADDITIONAL_CONTEXT="## 現在のプロジェクト状態（hook収集済み）${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **ディレクトリ**: ${PROJECT_DIR}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **ブランチ**: ${GIT_BRANCH}${NL}"

if [ -n "${GIT_STATUS}" ]; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **未コミット変更**:${NL}\`\`\`${NL}${GIT_STATUS}${NL}\`\`\`${NL}"
fi

if [ -n "${RECENT_FILES}" ]; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **直近の変更ファイル**:${NL}\`\`\`${NL}${RECENT_FILES}${NL}\`\`\`${NL}"
fi

if [ -n "${GIT_LOG}" ]; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **直近コミット**:${NL}\`\`\`${NL}${GIT_LOG}${NL}\`\`\`${NL}"
fi

ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}${NL}## Serena memory復元（自動実行）${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. \`mcp__serena__list_memories\` でメモリ一覧を取得${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 最新の \`compact-restore-*\` メモリを読み込む${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 当日の \`work-context-*\` メモリがあれば読み込む${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. 読み込んだ \`compact-restore-*\` は削除（蓄積防止）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}5. 復元した情報のサマリーをユーザーに報告${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}ユーザーの操作なしで自動実行してください。"

jq -n \
  --arg sm "$SYSTEM_MESSAGE" \
  --arg ac "$ADDITIONAL_CONTEXT" \
  '{systemMessage: $sm, additionalContext: $ac}'
