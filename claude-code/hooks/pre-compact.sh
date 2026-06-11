#!/usr/bin/env bash
# PreCompact Hook - コンテキスト圧縮前の auto-memory 保存強制
# 【必須】compact 前に Claude Code auto-memory に保存、compact 後に post-compact-reload.sh が読み込み
#
# 設計方針 (2026-06-11 修正):
#   - Serena MCP は使わない (compact-restore-* は ignored_memory_patterns に hit して write 拒否される、実測)
#   - CLAUDE.md 規約「Memory write 先は Claude Code auto-memory のみ」に統一
#   - auto-memory は file system 直書きのため接続 check 不要、常に書ける
#
# 動作 2 段階 (2026-06-11 block + auto-retry 方式追加):
#   1st 起動: marker file (= 直近 5 分以内の compact-restore-*.md) 不在
#     → decision:"block" で compact 中止、AI に「Write tool で save しろ」と指示
#     AI が save 実行 → marker file 生成
#   2nd 起動: marker 存在
#     → 通常進行、state file に "ready:<ts>" 書込
#
# 緊急回避 flag: CLAUDE_FORCE_COMPACT=1 で marker check skip (文脈破棄してでも compact 強行)
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

# --- save marker check (block + auto-retry 方式) ----------------------
# 直近 5 分以内に compact-restore-*.md が作られていれば「save 済」とみなす
# (1st 起動で AI が save → 2nd 起動で通すフロー、user は /compact を 2 回打つ)
SAVE_WINDOW_MIN=5
save_marker_present() {
  [ -d "${MEMORY_DIR}" ] || return 1
  # BSD/GNU find 両対応で -mmin -5 を使う
  local hit
  hit=$(find "${MEMORY_DIR}" -maxdepth 1 -name 'compact-restore-*.md' -type f -mmin "-${SAVE_WINDOW_MIN}" 2>/dev/null | head -1)
  [ -n "${hit}" ]
}

# 緊急回避: 文脈破棄してでも compact したい場合
if [ "${CLAUDE_FORCE_COMPACT:-0}" = "1" ]; then
  echo "ready:${TIMESTAMP}" > "${STATE_FILE}"
  jq -n \
    --arg sm "${ICON_WARN} compact 強行モード (CLAUDE_FORCE_COMPACT=1)" \
    --arg ac "save marker check を skip して compact 進行。文脈復元不可。" \
    '{systemMessage: $sm, additionalContext: $ac}'
  exit 0
fi

if ! save_marker_present; then
  # --- block: 先に save を強制 --------------------------------------
  SM="${ICON_CRITICAL} COMPACT中止 - 先に auto-memory save が必要"

  AC="**最優先・即実行**: Write tool で auto-memory に save、その後 user に \`/compact\` 再実行を促せ${NL}${NL}"
  AC="${AC}- **file_path**: \`${MEMORY_PATH}\`${NL}${NL}"
  AC="${AC}**frontmatter** (必須):${NL}"
  AC="${AC}\`\`\`yaml${NL}---${NL}name: compact-restore-${TIMESTAMP}${NL}description: <one-line summary of current task>${NL}metadata:${NL}  type: project${NL}---${NL}\`\`\`${NL}${NL}"
  AC="${AC}**body 7 field** (全て必須):${NL}"
  AC="${AC}1. 現在のタスク（元の指示文を literal 引用）${NL}"
  AC="${AC}2. 完了済 / 残ステップ（具体的に列挙）${NL}"
  AC="${AC}3. 編集中 file path + 変更要約（diff レベル）${NL}"
  AC="${AC}4. 次アクション（command レベル）${NL}"
  AC="${AC}5. project path + branch 名${NL}"
  AC="${AC}6. 直前 user 発言 3 件要約${NL}"
  AC="${AC}7. 使用中 skill / command 名${NL}${NL}"
  AC="${AC}**save 完了後**: chat に「memory save 完了。\`/compact\` を再実行してください」と user に明示する。${NL}"
  AC="${AC}**save 失敗時**: chat に「save 失敗、compact 中止」と報告し user に手動対応を促す。${NL}${NL}"
  AC="${AC}**緊急回避**: 文脈破棄してでも compact したい場合は \`export CLAUDE_FORCE_COMPACT=1\` 後に再試行。"

  jq -n \
    --arg sm "${SM}" \
    --arg ac "${AC}" \
    --arg reason "auto-memory save required before compact" \
    '{systemMessage: $sm, additionalContext: $ac, decision: "block", reason: $reason}'
  exit 2
fi

# --- 通常経路: save 済確認後の進行 ------------------------------------
echo "ready:${TIMESTAMP}" > "${STATE_FILE}"

SYSTEM_MESSAGE="${ICON_SUCCESS} COMPACT進行 - save 済 marker 検知、context 圧縮開始"
ADDITIONAL_CONTEXT="直近 ${SAVE_WINDOW_MIN} 分以内の compact-restore-*.md を検知。post-compact-reload.sh が圧縮後に自動復元する。"

jq -n \
  --arg sm "${SYSTEM_MESSAGE}" \
  --arg ac "${ADDITIONAL_CONTEXT}" \
  '{systemMessage: $sm, additionalContext: $ac}'
