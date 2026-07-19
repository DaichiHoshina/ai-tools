#!/usr/bin/env bash
# Usage: sleep-harvest.sh [--days N] [--repo <path>]
# 利用ログを bash だけで集計し、Mine 用の要約を stdout へ出す。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/redact.sh
source "${ROOT}/lib/redact.sh"

DAYS=7
REPO="$(cd "${ROOT}/.." && pwd)"
MAX_BYTES=40000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days) DAYS="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ "${DAYS}" =~ ^[0-9]+$ ]] || { echo "ERROR: --days は数値のみ受ける" >&2; exit 2; }

ANALYTICS_DB="${SLEEP_ANALYTICS_DB:-${HOME}/.claude/analytics/analytics.db}"
HISTORY_JSONL="${SLEEP_HISTORY_JSONL:-${HOME}/.claude/history.jsonl}"
LOG_DIR="${SLEEP_LOG_DIR:-${HOME}/.claude/logs}"
SKILL_EVAL="${SLEEP_SKILL_EVAL:-${SCRIPT_DIR}/skill-eval.sh}"
PENDING_FILE="${REPO}/memory/pending-improvements.md"
CUTOFF_SQL="strftime('%Y-%m-%dT%H:%M:%SZ','now','-${DAYS} days')"

_section() { printf '\n## %s\n\n' "$1"; }
_skip() { printf '(skip: %s)\n' "$1"; }

_sql() {
  if [[ -f "${ANALYTICS_DB}" ]] && command -v sqlite3 >/dev/null; then
    sqlite3 -readonly -separator ' | ' "${ANALYTICS_DB}" "$1" 2>/dev/null || _skip "sqlite query fail"
  else
    _skip "analytics.db or sqlite3 なし"
  fi
}

_digest() {
  printf '# sleep harvest digest (%s, last %sd)\n' "$(date '+%F')" "${DAYS}"

  _section "analytics.db: tool 別 count / error (${DAYS}d)"
  _sql "SELECT tool_name, COUNT(*), SUM(CASE WHEN exit_code IS NOT NULL AND exit_code != 0 THEN 1 ELSE 0 END)
        FROM tool_events WHERE timestamp >= ${CUTOFF_SQL}
        GROUP BY tool_name ORDER BY COUNT(*) DESC LIMIT 15;"

  _section "analytics.db: 失敗の多い tool input (${DAYS}d)"
  _sql "SELECT tool_name, substr(tool_input_summary, 1, 80), COUNT(*)
        FROM tool_events WHERE timestamp >= ${CUTOFF_SQL}
          AND exit_code IS NOT NULL AND exit_code != 0
        GROUP BY tool_name, substr(tool_input_summary, 1, 80)
        ORDER BY COUNT(*) DESC LIMIT 10;"

  _section "analytics.db: project 別 session / agent 別実行 (${DAYS}d)"
  _sql "SELECT project, COUNT(*) FROM sessions WHERE start_time >= ${CUTOFF_SQL}
        GROUP BY project ORDER BY COUNT(*) DESC LIMIT 10;
        SELECT agent_type, COUNT(*) FROM agent_events WHERE start_time >= ${CUTOFF_SQL}
        GROUP BY agent_type ORDER BY COUNT(*) DESC LIMIT 10;"

  _section "history.jsonl: churn signal (${DAYS}d, tail 40)"
  if [[ -f "${HISTORY_JSONL}" ]] && command -v jq >/dev/null; then
    jq -c --argjson sec "$((DAYS * 86400))" \
      'select(.timestamp > ((now - $sec) * 1000)) | .display' "${HISTORY_JSONL}" 2>/dev/null \
      | grep -E '再度|もう一度|やり直|違う|stop|cancel|wrong' \
      | cut -c1-300 | tail -n 40 || _skip "churn hit 0 件"
  else
    _skip "history.jsonl or jq なし"
  fi

  _section "skill-eval (${DAYS}d)"
  if [[ -x "${SKILL_EVAL}" ]]; then
    bash "${SKILL_EVAL}" --days "${DAYS}" --top 15 2>/dev/null | head -n 60 || _skip "skill-eval fail"
  else
    _skip "skill-eval.sh なし"
  fi

  _section "quality block logs (tail)"
  if [[ -f "${LOG_DIR}/jp-quality-block.log" ]]; then
    tail -n 20 "${LOG_DIR}/jp-quality-block.log"
  else
    _skip "jp-quality-block.log なし"
  fi
  if [[ -f "${LOG_DIR}/session-split-warn.log" ]]; then
    tail -n 10 "${LOG_DIR}/session-split-warn.log"
  else
    _skip "session-split-warn.log なし"
  fi

  _section "review-history (tail 20)"
  if [[ -f "${REPO}/.claude/review-history.jsonl" ]]; then
    tail -n 20 "${REPO}/.claude/review-history.jsonl" | cut -c1-200
  else
    _skip "review-history.jsonl なし"
  fi

  _section "pending improvements (dedup 用、head 60)"
  if [[ -f "${PENDING_FILE}" ]]; then
    head -n 60 "${PENDING_FILE}"
  else
    _skip "pending-improvements.md なし"
  fi

  _section "過去の rejected proposals (再生成防止)"
  local f found=0
  for f in "${REPO}"/memory/sleep-proposals-*.rejected.md; do
    [[ -f "${f}" ]] || continue
    found=1
    printf -- '--- %s ---\n' "${f##*/}"
    grep -E '^### |^REJECT|^NO-PROPOSAL' "${f}" | head -n 10 || true
  done
  [[ "${found}" -eq 1 ]] || _skip "rejected なし"
}

_digest | redact_private_terms | head -c "${MAX_BYTES}"
