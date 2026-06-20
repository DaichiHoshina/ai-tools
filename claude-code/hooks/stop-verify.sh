#!/usr/bin/env bash
# stop-verify.sh - opt-in smoke test gate (Stop hook)
# Enabled only when STOP_VERIFY_ENFORCE=1.
# On bats failure: outputs decision:block JSON (exit 0 per hook spec).

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
require_jq

LOG_FILE="$HOME/.claude/logs/stop-verify.log"
STOP_VERIFY_ENFORCE="${STOP_VERIFY_ENFORCE:-0}"

# opt-in guard: default OFF
if [[ "${STOP_VERIFY_ENFORCE}" != "1" ]]; then
  exit 0
fi

INPUT=$(cat)
CWD=$(printf '%s' "${INPUT}" | jq -r '.cwd // ""')

# graceful exit when cwd is absent or not a git repo
if [[ -z "${CWD}" ]] || ! git -C "${CWD}" rev-parse --git-dir >/dev/null 2>&1; then
  printf '%s stop-verify skipped: no cwd or not a git repo\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" >> "${LOG_FILE}"
  exit 0
fi

# --- changed file detection ---
# Try HEAD~1..HEAD first; fall back to staged files when history is shallow
CHANGED_FILES=""
if git -C "${CWD}" rev-parse HEAD~1 >/dev/null 2>&1; then
  CHANGED_FILES=$(git -C "${CWD}" diff --name-only HEAD~1 HEAD 2>/dev/null || true)
else
  CHANGED_FILES=$(git -C "${CWD}" diff --cached --name-only 2>/dev/null || true)
fi

FILE_COUNT=$(printf '%s' "${CHANGED_FILES}" | grep -c . || true)

# skip when no files changed
if [[ "${FILE_COUNT}" -eq 0 ]]; then
  printf '%s stop-verify skipped: doc-only (0 files)\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" >> "${LOG_FILE}"
  exit 0
fi

# skip when all changes are doc/config only (no code files)
DOC_EXTS_RE='\.(md|txt|json|yml|yaml|toml)$'
NON_DOC=$(printf '%s' "${CHANGED_FILES}" | grep -vE "${DOC_EXTS_RE}" || true)
if [[ -z "${NON_DOC}" ]]; then
  printf '%s stop-verify skipped: doc-only (%d files)\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "${FILE_COUNT}" >> "${LOG_FILE}"
  exit 0
fi

# --- language routing ---
SH_FILES=$(printf '%s' "${CHANGED_FILES}" | grep -E '\.sh$' || true)

if [[ -n "${SH_FILES}" ]]; then
  # bats availability check
  if ! command -v bats >/dev/null 2>&1; then
    printf '%s stop-verify skipped: bats not found (warn)\n' \
      "$(date '+%Y-%m-%dT%H:%M:%S')" >> "${LOG_FILE}"
    exit 0
  fi

  # STOP_VERIFY_TEST_DIRS allows test injection; default to project-relative paths
  if [[ -n "${STOP_VERIFY_TEST_DIRS:-}" ]]; then
    read -ra EXISTING_DIRS <<< "${STOP_VERIFY_TEST_DIRS}"
  else
    BATS_DIRS=("${CWD}/claude-code/tests/unit/lib/" "${CWD}/claude-code/tests/unit/hooks/")
    EXISTING_DIRS=()
    for d in "${BATS_DIRS[@]}"; do
      [[ -d "${d}" ]] && EXISTING_DIRS+=("${d}")
    done
  fi

  if [[ ${#EXISTING_DIRS[@]} -eq 0 ]]; then
    printf '%s stop-verify skipped: no bats test dirs found\n' \
      "$(date '+%Y-%m-%dT%H:%M:%S')" >> "${LOG_FILE}"
    exit 0
  fi

  BATS_OUT=""
  BATS_RC=0
  BATS_OUT=$(bats -j 10 "${EXISTING_DIRS[@]}" 2>&1) || BATS_RC=$?

  if [[ "${BATS_RC}" -ne 0 ]]; then
    # extract first failing test name from bats TAP output
    FIRST_FAIL=$(printf '%s' "${BATS_OUT}" | grep -E '^not ok' | head -1 | sed 's/^not ok [0-9]* //' || true)
    [[ -z "${FIRST_FAIL}" ]] && FIRST_FAIL="(unknown test)"

    printf '%s stop-verify BLOCK: bats rc=%d first_fail=%s files=%d\n' \
      "$(date '+%Y-%m-%dT%H:%M:%S')" "${BATS_RC}" "${FIRST_FAIL}" "${FILE_COUNT}" >> "${LOG_FILE}"

    jq -n --arg reason "smoke test failed: ${FIRST_FAIL}" \
      '{decision: "block", reason: $reason, suppressOutput: false}'
    exit 0
  fi

  printf '%s stop-verify pass: bats ok files=%d\n' \
    "$(date '+%Y-%m-%dT%H:%M:%S')" "${FILE_COUNT}" >> "${LOG_FILE}"
  exit 0
fi

# TODO: add language-specific hooks here (e.g., jest for .ts, pytest for .py)
# For now, non-.sh code changes are a no-op.
printf '%s stop-verify skipped: no .sh in changed files (no-op)\n' \
  "$(date '+%Y-%m-%dT%H:%M:%S')" >> "${LOG_FILE}"
exit 0
