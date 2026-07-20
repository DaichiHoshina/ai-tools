#!/usr/bin/env bash
# Usage: sleep-cron-run.sh [--repo <path>] [--days N] [--model M] [--checker-model M]
#                          [--max-cost-usd X] [--max-seconds N] [--dry-run]
# 夜間 1 回の単発 pipeline: harvest → mine (claude -p) → gate → stage/reject。
# exit: 0=staged or skip / 2=env error / 3=no-proposal / 4=gate reject or tracked 変化
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../lib/redact.sh
source "${ROOT}/lib/redact.sh"

REPO="$(cd "${ROOT}/.." && pwd)"
DAYS=7
MODEL="sonnet"
CHECKER_MODEL="haiku"
MAX_COST_USD="2.00"
MAX_SECONDS=900
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --days) DAYS="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --checker-model) CHECKER_MODEL="$2"; shift 2 ;;
    --max-cost-usd) MAX_COST_USD="$2"; shift 2 ;;
    --max-seconds) MAX_SECONDS="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || true)}"
[[ -n "${CLAUDE_BIN}" ]] || { echo "ERROR: claude CLI が見つかりません" >&2; exit 2; }
command -v jq >/dev/null || { echo "ERROR: jq が見つかりません" >&2; exit 2; }
git -C "${REPO}" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: --repo が git repo でない: ${REPO}" >&2; exit 2; }
[[ -d "${REPO}/memory" ]] || { echo "ERROR: ${REPO}/memory がない" >&2; exit 2; }

STATE_DIR="${SLEEP_STATE_DIR:-${HOME}/.claude/sleep}"
LOG_DIR="${HOME}/.claude/logs"
LOG="${LOG_DIR}/sleep-cron.log"
STATE="${STATE_DIR}/state.md"
TEMPLATE="${ROOT}/templates/sleep-mine-prompt.md.template"
DATE="$(date '+%F')"
STAGE_FILE="${REPO}/memory/sleep-proposals-${DATE}.md"
DIGEST_FILE="${STATE_DIR}/digest-${DATE}.md"
WARN_FLAG="${STATE_DIR}/tracked-change-warn"
mkdir -p "${STATE_DIR}" "${LOG_DIR}"

_log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "${LOG}" >&2; }

_init_state() {
  [[ -f "${STATE}" ]] && return 0
  cat > "${STATE}" <<EOF
# sleep pipeline state

- Status: never-run

## Ledger

| date | result | proposals | cost (USD) |
|------|--------|-----------|------------|
EOF
}

_ledger() {
  local row="| ${DATE} | $1 | $2 | $3 |"
  awk -v row="${row}" '{ print; if (!done && /^\|---/) { print row; done = 1 } }' \
    "${STATE}" > "${STATE}.tmp" && mv "${STATE}.tmp" "${STATE}"
}

_mark_done() {
  if grep -q '^- Status: ' "${STATE}"; then
    sed 's|^- Status: .*|- Status: done|' "${STATE}" > "${STATE}.tmp" && mv "${STATE}.tmp" "${STATE}"
  fi
}

_tracked_fingerprint() {
  {
    git -C "${REPO}" rev-parse HEAD 2>/dev/null || echo no-head
    git -C "${REPO}" status --porcelain
    git -C "${REPO}" diff
    git -C "${REPO}" diff --cached
  } | shasum -a 256 | cut -d' ' -f1
}

_reject() {
  local reason="$1"
  printf '\nREJECT (%s): %s\n' "${DATE}" "${reason}" | redact_private_terms >> "${STAGE_FILE}"
  mv "${STAGE_FILE}" "${STAGE_FILE%.md}.rejected.md"
  _ledger "REJECT" "-" "${total_cost:-0}"
  _log "reject: ${reason}"
}

_init_state

if ls "${REPO}/memory/sleep-proposals-${DATE}"*.md >/dev/null 2>&1; then
  _log "当日分が既に存在するため skip (idempotent)"
  exit 0
fi

staged_count=0
for f in "${REPO}"/memory/sleep-proposals-*.md; do
  [[ -f "${f}" ]] || continue
  case "${f}" in
    *.rejected.md|*.adopted.md) continue ;;
  esac
  staged_count=$((staged_count + 1))
done
if [[ "${staged_count}" -ge 3 ]]; then
  _log "staged が ${staged_count} 件滞留している。/sleep-review を先に実行する (新規 mine skip)"
  exit 0
fi

[[ -f "${TEMPLATE}" ]] || { echo "ERROR: template がない: ${TEMPLATE}" >&2; exit 2; }

_log "harvest start (days=${DAYS})"
"${SCRIPT_DIR}/sleep-harvest.sh" --days "${DAYS}" --repo "${REPO}" > "${DIGEST_FILE}"

_build_prompt() {
  sed -e "s|{{DATE}}|${DATE}|g" -e "s|{{TARGET_FILE}}|${STAGE_FILE}|g" "${TEMPLATE}"
  printf '\n---\n\n## Harvest digest\n\n'
  cat "${DIGEST_FILE}"
}

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "=== sleep plan (dry-run) ==="
  echo "repo=${REPO} model=${MODEL} checker=${CHECKER_MODEL} stage=${STAGE_FILE}"
  echo ""
  _build_prompt
  exit 0
fi

printf '# sleep proposals %s\n\n(この file を Edit tool で埋める)\n' "${DATE}" > "${STAGE_FILE}"

before_fp="$(_tracked_fingerprint)"
_log "mine start (model=${MODEL})"

maker_out="${STATE_DIR}/.maker-out"
: > "${maker_out}"
( _build_prompt | (cd "${REPO}" && "${CLAUDE_BIN}" -p --model "${MODEL}" --fallback-model sonnet \
    --output-format json --permission-mode acceptEdits) > "${maker_out}" 2>>"${LOG}" ) &
maker_pid=$!
waited=0
while kill -0 "${maker_pid}" 2>/dev/null; do
  sleep 5
  waited=$((waited + 5))
  if [[ "${waited}" -ge "${MAX_SECONDS}" ]]; then
    kill "${maker_pid}" 2>/dev/null || true
    wait "${maker_pid}" 2>/dev/null || true
    _reject "mine が ${MAX_SECONDS}s を超過 (watchdog kill)"
    exit 4
  fi
done
wait "${maker_pid}" || true

total_cost=$(jq -r 'if type=="array" then (.[-1].total_cost_usd // 0) else (.total_cost_usd // 0) end' \
  "${maker_out}" 2>/dev/null || echo 0)
if awk -v a="${total_cost}" -v b="${MAX_COST_USD}" 'BEGIN { exit !(a >= b) }'; then
  _log "WARN: mine cost \$${total_cost} が上限 \$${MAX_COST_USD} に達した"
fi

after_fp="$(_tracked_fingerprint)"
if [[ "${before_fp}" != "${after_fp}" ]]; then
  git -C "${REPO}" restore . 2>/dev/null || git -C "${REPO}" checkout -- . 2>/dev/null || true
  touch "${WARN_FLAG}"
  _reject "maker が tracked file を変更した (restore 済、要確認)"
  exit 4
fi

_log "gate A: schema check"
set +e
"${SCRIPT_DIR}/sleep-proposal-check.sh" "${STAGE_FILE}" --repo "${REPO}" >> "${LOG}" 2>&1
gate_a=$?
set -e
if [[ "${gate_a}" -eq 3 ]]; then
  mv "${STAGE_FILE}" "${STAGE_FILE%.md}.rejected.md"
  _ledger "NO-PROPOSAL" "0" "${total_cost}"
  _mark_done
  _log "no-proposal で終了 (正常)"
  exit 3
elif [[ "${gate_a}" -ne 0 ]]; then
  _reject "schema check fail (詳細: ${LOG})"
  exit 4
fi

_log "gate B: checker verdict (model=${CHECKER_MODEL})"
checker_prompt=$(printf 'You are an independent reviewer. Answer from the digest and proposals only.\nChecklist: (1) each Evidence cites data that exists in the digest (2) each Change stays within its Target scope (3) no proposal performs config self-modification, merge, push, or deploy (proposing a removal/archive for human review is allowed; Type: remove needs only zero-usage evidence).\nIf all pass respond exactly "VERDICT: APPROVE", otherwise "VERDICT: REJECT <reason>".\n\n## Digest\n\n%s\n\n## Proposals\n\n%s\n' \
  "$(cat "${DIGEST_FILE}")" "$(cat "${STAGE_FILE}")")
checker_out=$(printf '%s' "${checker_prompt}" | "${CLAUDE_BIN}" -p --model "${CHECKER_MODEL}" \
  --fallback-model haiku --output-format json 2>>"${LOG}" \
  | jq -r 'if type=="array" then (.[-1].result // empty) else (.result // empty) end' || true)
if ! grep -q 'VERDICT: APPROVE' <<< "${checker_out}"; then
  reason=$(grep -o 'VERDICT: REJECT.*' <<< "${checker_out}" | head -1)
  [[ -n "${reason}" ]] || reason="VERDICT: REJECT (checker 出力が parse 不能)"
  _reject "${reason}"
  exit 4
fi

proposals=$(grep -c '^### P[0-9]*:' "${STAGE_FILE}" || echo 0)
_ledger "STAGED" "${proposals}" "${total_cost}"
_mark_done
_log "staged: ${STAGE_FILE} (${proposals} proposals, cost \$${total_cost})"
echo "staged: ${STAGE_FILE}"
