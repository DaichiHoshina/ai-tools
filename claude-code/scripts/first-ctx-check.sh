#!/usr/bin/env bash
# first-ctx-check: session 初回 API call の固定 context 量を計測する
#
# 各 session jsonl の最初の .message.usage から
# input + cache_creation + cache_read を合算した値 (= system prompt + CLAUDE.md +
# rules + plugin/MCP schema の床値) を集計し、閾値超過を warn する。
# 床値は全 message に掛かる cache_read の主成分のため、regression 検知が token 削減の要になる。
#
# usage: first-ctx-check.sh [--days N] [--threshold TOKENS] [--log]
#   --days N          集計対象の jsonl mtime 範囲 (default: 7)
#   --threshold N     warn 閾値 tokens (default: 60000)
#   --log             結果を ~/.claude/logs/first-ctx-<ts>.log に保存する
set -euo pipefail

PROJECTS_DIR="${CLAUDE_PROJECTS_DIR:-${HOME}/.claude/projects}"
LOG_DIR="${HOME}/.claude/logs"
DAYS=7
THRESHOLD=60000
DO_LOG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)      DAYS="${2:?--days requires a value}"; shift 2 ;;
    --threshold) THRESHOLD="${2:?--threshold requires a value}"; shift 2 ;;
    --log)       DO_LOG=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq が見つかりません" >&2
  exit 2
fi

# 各 session の first_ctx を "tokens<TAB>project/session" で列挙する
_collect() {
  local dir jsonl first_ctx slug sid
  while IFS= read -r jsonl; do
    [[ -f "${jsonl}" ]] || continue
    # 最初の usage 行のみ読む (jsonl 全体は巨大なため head 打ち切り必須)
    first_ctx=$(head -c 2097152 "${jsonl}" | jq -r '
      select(.message.usage) | .message.usage |
      ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null | head -1) || first_ctx=""
    [[ -n "${first_ctx}" && "${first_ctx}" != "null" ]] || continue
    dir=$(dirname "${jsonl}")
    slug=$(basename "${dir}")
    sid=$(basename "${jsonl}" .jsonl)
    printf '%s\t%s/%s\n' "${first_ctx}" "${slug}" "${sid:0:8}"
  done < <(find "${PROJECTS_DIR}" -maxdepth 2 -name '*.jsonl' -mtime "-${DAYS}" 2>/dev/null)
}

RESULTS=$(_collect | sort -rn)

if [[ -z "${RESULTS}" ]]; then
  echo "対象 session がない (${PROJECTS_DIR}, mtime -${DAYS}d)"
  exit 0
fi

COUNT=$(wc -l <<< "${RESULTS}" | tr -d ' ')
MAX=$(head -1 <<< "${RESULTS}" | cut -f1)
MEDIAN=$(awk -F'\t' '{a[NR]=$1} END{print a[int((NR+1)/2)]}' <<< "${RESULTS}")
OVER=$(awk -F'\t' -v th="${THRESHOLD}" '$1 > th' <<< "${RESULTS}" | wc -l | tr -d ' ')

OUTPUT=$(
  printf 'first-ctx check (直近 %sd / %s sessions)\n' "${DAYS}" "${COUNT}"
  printf 'max=%s median=%s threshold=%s over=%s\n' "${MAX}" "${MEDIAN}" "${THRESHOLD}" "${OVER}"
  printf -- '--- top 10 ---\n'
  head -10 <<< "${RESULTS}"
  if (( OVER > 0 )); then
    printf 'WARN: %s sessions が閾値 %s tokens を超過。plugin / MCP / CLAUDE.md / rules の常駐肥大を疑う\n' "${OVER}" "${THRESHOLD}"
  fi
)

printf '%s\n' "${OUTPUT}"

if (( DO_LOG )); then
  mkdir -p "${LOG_DIR}"
  ts="$(date +%Y%m%d-%H%M%S)"
  printf '%s\n' "${OUTPUT}" > "${LOG_DIR}/first-ctx-${ts}.log"
  echo "saved: ${LOG_DIR}/first-ctx-${ts}.log"
fi

# warn は exit 1 (cron log で検知可能に)。session なし / 正常は exit 0
(( OVER == 0 )) || exit 1
