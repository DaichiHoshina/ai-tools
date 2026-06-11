#!/usr/bin/env bash
# PreCompact Hook - コンテキスト圧縮前の auto-memory 保存指示
# 【必須】compact 前に Claude Code auto-memory に保存、compact 後に post-compact-reload.sh が読み込み
#
# 設計方針 (2026-06-11 修正):
#   - Serena MCP は使わない (compact-restore-* は ignored_memory_patterns に hit して write 拒否される、実測)
#   - CLAUDE.md 規約「Memory write 先は Claude Code auto-memory のみ」に統一
#   - auto-memory は file system 直書きのため接続 check 不要、常に書ける
#
# 状態 file: ${HOME}/.claude/.compact-memory-state
#   "ready:<timestamp>" を書き込み、post-compact-reload.sh が読む。読んだら削除する契約。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/hook-utils.sh
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

require_jq

# JSON 入力消費 (未使用)
cat > /dev/null

NL=$'\n'
STATE_FILE="${HOME}/.claude/.compact-memory-state"
mkdir -p "$(dirname "${STATE_FILE}")"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
MEMORY_DIR="${HOME}/.claude/projects/-Users-daichi-hoshina-ai-tools/memory"
MEMORY_PATH="${MEMORY_DIR}/compact-restore-${TIMESTAMP}.md"

# 状態 file 書込 (post-compact 側で参照)
echo "ready:${TIMESTAMP}" > "${STATE_FILE}"

SYSTEM_MESSAGE="${ICON_CRITICAL} COMPACT検出 - auto-memory へ即保存せよ（他の操作より優先）"

ADDITIONAL_CONTEXT="**最優先・即実行**: Write tool で以下に保存${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **file_path**: \`${MEMORY_PATH}\`${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**frontmatter** (必須):${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}\`\`\`yaml${NL}---${NL}name: compact-restore-${TIMESTAMP}${NL}description: <one-line summary of current task>${NL}metadata:${NL}  type: project${NL}---${NL}\`\`\`${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**body 7 field** (全て必須):${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. 現在のタスク（元の指示文を literal 引用）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 完了済 / 残ステップ（具体的に列挙）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 編集中 file path + 変更要約（diff レベル）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. 次アクション（command レベル）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}5. project path + branch 名${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}6. 直前 user 発言 3 件要約${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}7. 使用中 skill / command 名${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**保存失敗時**: Write が error を返したら compact を中止し user に報告（復元不可能になるため）。${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**復元**: compact 後に post-compact-reload.sh hook が自動 trigger する。"

jq -n \
  --arg sm "${SYSTEM_MESSAGE}" \
  --arg ac "${ADDITIONAL_CONTEXT}" \
  '{systemMessage: $sm, additionalContext: $ac}'
