#!/usr/bin/env bash
# PostCompact Reload Hook - compact 後の自動コンテキスト復元
# PostCompact イベントで発火 (v2.1.76+ 公式 hook)
# compact 後に /reload 相当の処理を自動実行するよう AI に指示
# git / file 情報を直接埋め込み、auto-memory 不在でも最低限の復元が可能
#
# 設計方針 (2026-06-11 修正):
#   - Serena MCP は使わない (pre-compact 側で auto-memory に統一済)
#   - 復元元: ~/.claude/projects/.../memory/compact-restore-*.md (Read tool で AI が読む)
#
# 状態 file: ${HOME}/.claude/.compact-memory-state
#   pre-compact.sh が "ready:<timestamp>" を書く。読んだら削除する契約。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/hook-utils.sh
source "${SCRIPT_DIR}/../lib/hook-utils.sh"

require_jq

cat > /dev/null

NL=$'\n'
MEMORY_DIR="${HOME}/.claude/projects/-Users-daichi-hoshina-ai-tools/memory"

# --- pre-compact から状態引継ぎ ----------------------------------------
STATE_FILE="${HOME}/.claude/.compact-memory-state"
MEMORY_STATE="unknown"
TIMESTAMP=""
if [ -f "${STATE_FILE}" ]; then
  STATE_RAW=$(cat "${STATE_FILE}" 2>/dev/null || echo "unknown")
  rm -f "${STATE_FILE}"
  MEMORY_STATE="${STATE_RAW%%:*}"
  TIMESTAMP="${STATE_RAW#*:}"
  [ "${TIMESTAMP}" = "${STATE_RAW}" ] && TIMESTAMP=""
fi

# --- 静的 context 収集 (file system のみ、MCP 不要) -------------------
# git diff --name-only は HEAD~3..HEAD 分析コストが高いため省略 (latency 最適化)
_TMP_DIR=$(mktemp -d)
PROJECT_DIR=$(pwd)
git branch --show-current >"${_TMP_DIR}/branch" 2>/dev/null &
git status --short        >"${_TMP_DIR}/status" 2>/dev/null &
git log --oneline -5      >"${_TMP_DIR}/log"    2>/dev/null &
wait
GIT_BRANCH=$(cat "${_TMP_DIR}/branch"  2>/dev/null || echo "unknown")
GIT_STATUS=$(head -20 "${_TMP_DIR}/status" 2>/dev/null || echo "")
GIT_LOG=$(cat "${_TMP_DIR}/log"    2>/dev/null || echo "")
rm -rf "${_TMP_DIR}"

# --- compact-restore-* の最新 file 探索 -------------------------------
RESTORE_FILE=""
if [ -d "${MEMORY_DIR}" ]; then
  # ready 状態かつ timestamp あれば exact path、なければ最新 mtime
  if [ "${MEMORY_STATE}" = "ready" ] && [ -n "${TIMESTAMP}" ]; then
    CANDIDATE="${MEMORY_DIR}/compact-restore-${TIMESTAMP}.md"
    [ -f "${CANDIDATE}" ] && RESTORE_FILE="${CANDIDATE}"
  fi
  if [ -z "${RESTORE_FILE}" ]; then
    # bash glob で最新 compact-restore-*.md を取得 (find fork 削減)
    local_files=("${MEMORY_DIR}"/compact-restore-*.md)
    if [[ -e "${local_files[0]}" ]]; then
      RESTORE_FILE=$(printf '%s\n' "${local_files[@]}" | sort -r | head -1)
    fi
  fi
fi

case "${MEMORY_STATE}" in
  ready)
    if [ -n "${RESTORE_FILE}" ]; then
      SYSTEM_MESSAGE="${ICON_SUCCESS} COMPACT完了 - auto-memory 自動復元"
    else
      SYSTEM_MESSAGE="${ICON_WARN} COMPACT完了 - 保存指示は出たが file 不在、git 情報のみ"
    fi
    ;;
  *)
    SYSTEM_MESSAGE="${ICON_WARN} COMPACT完了 - 状態不明、git 情報のみ復元"
    ;;
esac

ADDITIONAL_CONTEXT="## 現在のプロジェクト状態（hook 収集済）${NL}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **ディレクトリ**: ${PROJECT_DIR}${NL}"
ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **ブランチ**: ${GIT_BRANCH}${NL}"

if [ -n "${GIT_STATUS}" ]; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **未コミット変更**:${NL}\`\`\`${NL}${GIT_STATUS}${NL}\`\`\`${NL}"
fi

if [ -n "${GIT_LOG}" ]; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}- **直近 commit**:${NL}\`\`\`${NL}${GIT_LOG}${NL}\`\`\`${NL}"
fi

if [ -n "${RESTORE_FILE}" ]; then
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}${NL}## auto-memory 復元（自動実行、/reload Step 2 と同期）${NL}${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}1. **Read tool** で compact-restore を読込:${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}   - \`${RESTORE_FILE}\`${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}2. \`~/ai-tools/memory/MEMORY.md\` を Read (先頭 1-3 行で当日 [clear] entry 確認)${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}3. 当日 \`work-context-YYYYMMDD-*.md\` 全件 Read、無ければ直近 1 件まで遡る${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}4. \`~/ai-tools/memory/pending-improvements.md\` を Read (未消化 item surface)${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}5. 読込後、Loaded / 直近 state / 未消化 item / Next action の 4 block で summary 報告${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}6. 読込済 \`compact-restore-*\` file を削除（蓄積防止、\`rm\` via Bash）${NL}${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}user の操作なしで自動実行する。canonical: \`commands/reload.md\`。"
else
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}${NL}## ${ICON_WARN} compact-restore file 不在${NL}${NL}"
  ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}pre-compact の保存指示が失敗した可能性あり。git 情報のみで作業継続し、失われた文脈は user に確認する。"
fi

jq -n \
  --arg sm "${SYSTEM_MESSAGE}" \
  --arg ac "${ADDITIONAL_CONTEXT}" \
  '{systemMessage: $sm, additionalContext: $ac}'
