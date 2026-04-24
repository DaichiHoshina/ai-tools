#!/usr/bin/env bash
# PreCompact Hook - コンテキスト圧縮前の自動Serena memory保存
# 【必須】compact前にSerena memoryへ保存、compact後に読み込み
# Serena MCP 未接続時は compact を中止（コンテキスト消失防止）
#
# 状態ファイル: ${HOME}/.claude/.compact-serena-state
#   "connected" / "skipped" を書き込み、post-compact-reload.sh が読む。
#   二重 health check を避けるため。post 側で読んだら削除する契約。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/hook-utils.sh
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

# ICON_* は hook-utils.sh で定義済み（source 経由で参照）

require_jq

# JSON入力を消費（未使用だが読み捨て必要）
cat > /dev/null

NL=$'\n'
STATE_FILE="${HOME}/.claude/.compact-serena-state"
mkdir -p "$(dirname "${STATE_FILE}")"

# --- 緊急回避フラグ（チェックスキップ、最優先） -----------------------
# コンテキスト破棄してでも compact したい場合のみ使用
if [ "${CLAUDE_SKIP_COMPACT_SERENA_CHECK:-0}" = "1" ]; then
  echo "skipped" > "${STATE_FILE}"
  jq -n \
    --arg sm "${ICON_CRITICAL} compact 強行モード（Serena チェックスキップ）" \
    --arg ac "CLAUDE_SKIP_COMPACT_SERENA_CHECK=1 のため Serena 保存なしで compact 進行。コンテキスト復元不可。" \
    '{systemMessage: $sm, additionalContext: $ac}'
  exit 0
fi

# --- Serena MCP 接続確認 -----------------------------------------------
# claude mcp list が "serena: ... ✓ Connected" を返すかで判定。
# 5秒 timeout（health check の実用上限）。長引くと compact 体感を悪化させるため短め。
check_serena_connected() {
  local output
  if ! output=$(timeout 5 claude mcp list 2>&1); then
    return 1
  fi
  echo "${output}" | grep -E "^serena:.*✓ Connected" >/dev/null 2>&1
}

if ! check_serena_connected; then
  # 状態ファイルは書かない（post 側は unknown 扱い）
  SM="${ICON_ERROR} Serena MCP 未接続 - compact 中止"
  AC="Serena への保存に失敗するとコンテキストが消失するため、compact を中止しました。${NL}${NL}"
  AC="${AC}**対処**:${NL}"
  AC="${AC}1. \`/mcp\` で Serena を再接続${NL}"
  AC="${AC}2. または Claude Code を再起動（既存セッションは \`claude --resume\` で再開）${NL}"
  AC="${AC}3. 復旧確認後に \`/compact\` を再実行${NL}${NL}"
  AC="${AC}**緊急回避**（コンテキスト破棄してでも compact したい場合）:${NL}"
  AC="${AC}- \`export CLAUDE_SKIP_COMPACT_SERENA_CHECK=1\` 後に再試行"

  jq -n \
    --arg sm "${SM}" \
    --arg ac "${AC}" \
    --arg reason "Serena MCP not connected" \
    '{systemMessage: $sm, additionalContext: $ac, decision: "block", reason: $reason}'
  exit 2
fi

# --- 通常経路: Serena 保存指示 ----------------------------------------
echo "connected" > "${STATE_FILE}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

SYSTEM_MESSAGE="${ICON_CRITICAL} COMPACT検出 - 即座にSerena memoryへ保存せよ（他の操作より優先）"
ADDITIONAL_CONTEXT="**最優先・即実行**: \`mcp__serena__write_memory\` で \`compact-restore-${TIMESTAMP}\` に保存${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}保存内容（以下を全て含めること）:${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. 現在のタスク（何を依頼されたか・元の指示文をそのまま引用）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. 完了済みステップと残ステップ（具体的に列挙）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 編集中のファイルパスと変更内容の要約（diffレベルで）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. 次に実行すべきアクション（コマンドレベルで）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}5. 現在のプロジェクトパスとブランチ名${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}6. 直前のユーザー発言（最後の3メッセージ要約）${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}7. 使用中のスキル/コマンド名（/flow, /dev等）${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**保存失敗時**: \`mcp__serena__write_memory\` がエラーを返した場合は compact を中止し、ユーザーに報告すること（復元不可能になるため）。${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}**復元**: compact後にpost-compact-reload hookが自動復元を指示する。"

jq -n \
  --arg sm "${SYSTEM_MESSAGE}" \
  --arg ac "${ADDITIONAL_CONTEXT}" \
  '{systemMessage: $sm, additionalContext: $ac}'
