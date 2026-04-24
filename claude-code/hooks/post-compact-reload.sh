#!/usr/bin/env bash
# PostCompact Reload Hook - compact後の自動コンテキスト復元
# PostCompact イベントで発火（v2.1.76+公式フック）
# compact後に /reload 相当の処理を自動実行するよう指示
# git/ファイル情報を直接埋め込み、Serena MCP不要でも最低限の復元が可能
#
# 状態ファイル: ${HOME}/.claude/.compact-serena-state
#   pre-compact.sh が書いた "connected"/"skipped" を読み取り、
#   post 側の二重 health check を回避する。読んだら削除する契約。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/hook-utils.sh
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# Nerd Fonts icons
ICON_SUCCESS=$'✓'
ICON_WARN=$'⚠'

require_jq

# JSON入力を消費（未使用だが読み捨て必要）
cat > /dev/null

NL=$'\n'

# --- Serena 状態読み取り（pre-compact.sh から引き継ぎ） ---------------
STATE_FILE="${HOME}/.claude/.compact-serena-state"
SERENA_STATE="unknown"
if [ -f "${STATE_FILE}" ]; then
  SERENA_STATE=$(cat "${STATE_FILE}" 2>/dev/null || echo "unknown")
  rm -f "${STATE_FILE}"
fi

# --- 静的コンテキスト収集（MCP不要） ---
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GIT_STATUS=$(git status --short 2>/dev/null | head -20 || echo "")
GIT_LOG=$(git log --oneline -5 2>/dev/null || echo "")
PROJECT_DIR=$(pwd)
RECENT_FILES=$(git diff --name-only HEAD~3..HEAD 2>/dev/null | head -15 || echo "")

case "${SERENA_STATE}" in
  connected)
    SYSTEM_MESSAGE="${ICON_SUCCESS} COMPACT完了 - コンテキスト自動復元"
    ;;
  skipped)
    SYSTEM_MESSAGE="${ICON_WARN} COMPACT完了（強行モード） - Serena 復元スキップ"
    ;;
  *)
    SYSTEM_MESSAGE="${ICON_WARN} COMPACT完了 - 状態不明のため git 情報のみ復元"
    ;;
esac

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

case "${SERENA_STATE}" in
  connected)
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}${NL}## Serena memory復元（自動実行）${NL}${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. \`mcp__serena__list_memories\` でメモリ一覧を取得${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 最新の \`compact-restore-*\` メモリを読み込む${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 当日の \`work-context-*\` メモリがあれば読み込む${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. 読み込んだ \`compact-restore-*\` は削除（蓄積防止）${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}5. 復元した情報のサマリーをユーザーに報告${NL}${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}ユーザーの操作なしで自動実行してください。"
    ;;
  skipped)
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}${NL}## ${ICON_WARN} 強行モードで compact 実行${NL}${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}CLAUDE_SKIP_COMPACT_SERENA_CHECK=1 のため Serena 保存をスキップして compact を実行。${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}上記 git 情報のみで作業継続し、失われた文脈はユーザーに確認すること。"
    ;;
  *)
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}${NL}## ${ICON_WARN} pre-compact hook 状態不明${NL}${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}pre-compact.sh の状態ファイルが存在しない。hook 連携失敗の可能性あり。${NL}"
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}git 情報のみで作業継続し、失われた文脈はユーザーに確認すること。"
    ;;
esac

jq -n \
  --arg sm "${SYSTEM_MESSAGE}" \
  --arg ac "${ADDITIONAL_CONTEXT}" \
  '{systemMessage: $sm, additionalContext: $ac}'
