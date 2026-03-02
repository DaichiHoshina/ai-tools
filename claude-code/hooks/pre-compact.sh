#!/usr/bin/env bash
# PreCompact Hook - コンテキスト圧縮前の自動Serena memory保存
# 【必須】compact前にSerena memoryへ保存、compact後に読み込み
# NOTE: Serena有無はチェックしない（常にSerena前提で指示を出す）

set -euo pipefail

# Nerd Fonts icons
ICON_CRITICAL=$'\u25c9'  # exclamation-circle

# JSON入力を消費（未使用だが読み捨て必要）
cat > /dev/null

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

NL=$'\n'
SYSTEM_MESSAGE="${ICON_CRITICAL} COMPACT検出 - 即座にSerena memoryへ保存せよ（他の操作より優先）"
ADDITIONAL_CONTEXT="**最優先・即実行**: \`mcp__serena__write_memory\` で \`compact-restore-${TIMESTAMP}\` に保存${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}保存内容（以下を全て含めること）:${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. 現在のタスク（何を依頼されたか・元の指示文）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 完了済みステップと残ステップ（具体的に）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 編集中のファイルパスと変更内容の要約${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. 次に実行すべきアクション（コマンドレベルで）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}5. 現在のプロジェクトパスとブランチ名${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**注意**: この保存は他の全操作に優先する。保存完了をユーザーに報告した上でcompactを進めること。${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**復元**: compact後にpost-compact-reload hookが自動復元を実行する。"

# JSON出力（jqで安全にエスケープ）
jq -n \
  --arg sm "$SYSTEM_MESSAGE" \
  --arg ac "$ADDITIONAL_CONTEXT" \
  '{systemMessage: $sm, additionalContext: $ac}'
