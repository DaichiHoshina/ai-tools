#!/usr/bin/env bash
# stop-verify.sh - opt-in smoke test gate (Stop hook)
# Enabled only when STOP_VERIFY_ENFORCE=1.
# On test failure: outputs decision:block JSON (exit 0 per hook spec).

set -euo pipefail

exec 2>>"$HOME/.claude/logs/hook-errors.log"

_sv_src="${BASH_SOURCE[0]}"
[[ "${_sv_src}" == /* ]] || _sv_src="${PWD}/${_sv_src}"
SCRIPT_DIR="${_sv_src%/*}"
source "${SCRIPT_DIR}/../lib/hook-utils.sh"
# shellcheck source=lib/log-rotation.sh
source "${SCRIPT_DIR}/lib/log-rotation.sh"
require_jq

LOG_FILE="$HOME/.claude/logs/stop-verify.log"
_rotate_log_if_needed "$LOG_FILE"
STOP_VERIFY_ENFORCE="${STOP_VERIFY_ENFORCE:-0}"

# opt-in guard: default OFF
if [[ "${STOP_VERIFY_ENFORCE}" != "1" ]]; then
  exit 0
fi

INPUT=$(cat)
CWD=$(printf '%s' "${INPUT}" | jq -r '.cwd // ""')

# graceful exit when cwd is absent or not a git repo
if [[ -z "${CWD}" ]] || ! git -C "${CWD}" rev-parse --git-dir >/dev/null 2>&1; then
  printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
  printf '%s stop-verify skipped: no cwd or not a git repo\n' \
    "${_TS}" >> "${LOG_FILE}"
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
  printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
  printf '%s stop-verify skipped: doc-only (0 files)\n' \
    "${_TS}" >> "${LOG_FILE}"
  exit 0
fi

# skip when all changes are doc/config only (no code files)
DOC_EXTS_RE='\.(md|txt|json|yml|yaml|toml)$'
NON_DOC=$(printf '%s' "${CHANGED_FILES}" | grep -vE "${DOC_EXTS_RE}" || true)
if [[ -z "${NON_DOC}" ]]; then
  printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
  printf '%s stop-verify skipped: doc-only (%d files)\n' \
    "${_TS}" "${FILE_COUNT}" >> "${LOG_FILE}"
  exit 0
fi

# --- runner override helper ---
# STOP_VERIFY_LANG_RUNNERS="go=/path/to/go,tsc=/path/to/tsc,pytest=/path/to/pytest"
# Returns runner path via stdout; empty string if not overridden.
_get_runner_override() {
  local lang="$1"
  local overrides="${STOP_VERIFY_LANG_RUNNERS:-}"
  if [[ -z "${overrides}" ]]; then
    printf ''
    return
  fi
  # iterate comma-separated pairs
  local pair
  while IFS= read -r pair; do
    if [[ "${pair}" == "${lang}="* ]]; then
      printf '%s' "${pair#"${lang}="}"
      return
    fi
  done < <(printf '%s\n' "${overrides}" | tr ',' '\n')
  printf ''
}

# --- language routing ---
SH_FILES=$(printf '%s' "${CHANGED_FILES}" | grep -E '\.sh$' || true)
GO_FILES=$(printf '%s' "${CHANGED_FILES}" | grep -E '\.go$' || true)
TS_FILES=$(printf '%s' "${CHANGED_FILES}" | grep -E '\.(ts|tsx)$' || true)
PY_FILES=$(printf '%s' "${CHANGED_FILES}" | grep -E '\.py$' || true)

# --- Phase: .sh → bats ---
if [[ -n "${SH_FILES}" ]]; then
  # bats availability check
  if ! command -v bats >/dev/null 2>&1; then
    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify skipped: bats not found (warn)\n' \
      "${_TS}" >> "${LOG_FILE}"
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
    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify skipped: no bats test dirs found\n' \
      "${_TS}" >> "${LOG_FILE}"
    exit 0
  fi

  BATS_OUT=""
  BATS_RC=0
  BATS_OUT=$(bats -j 10 "${EXISTING_DIRS[@]}" 2>&1) || BATS_RC=$?

  if [[ "${BATS_RC}" -ne 0 ]]; then
    # extract first failing test name from bats TAP output
    FIRST_FAIL=$(printf '%s' "${BATS_OUT}" | grep -E '^not ok' | head -1 | sed 's/^not ok [0-9]* //' || true)
    [[ -z "${FIRST_FAIL}" ]] && FIRST_FAIL="(unknown test)"

    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify BLOCK: bats rc=%d first_fail=%s files=%d\n' \
      "${_TS}" "${BATS_RC}" "${FIRST_FAIL}" "${FILE_COUNT}" >> "${LOG_FILE}"

    jq -n --arg reason "smoke test failed: ${FIRST_FAIL}" \
      '{decision: "block", reason: $reason, suppressOutput: false}'
    exit 0
  fi

  printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
  printf '%s stop-verify pass: bats ok files=%d\n' \
    "${_TS}" "${FILE_COUNT}" >> "${LOG_FILE}"
  exit 0
fi

# --- runner resolve helper ---
# Resolves runner for a given lang.
# Priority: STOP_VERIFY_LANG_RUNNERS override (must be executable) → command -v fallback.
# Prints resolved path; prints nothing if runner is unavailable (caller should skip).
_resolve_runner() {
  local lang="$1"
  local override
  override=$(_get_runner_override "${lang}")
  if [[ -n "${override}" ]]; then
    if [[ -x "${override}" ]]; then
      printf '%s' "${override}"
    fi
    # non-executable override → treat as absent (graceful skip)
    return
  fi
  # fallback: system PATH lookup
  local found
  found=$(command -v "${lang}" 2>/dev/null || true)
  printf '%s' "${found}"
}

# --- Phase: .go → go test ---
if [[ -n "${GO_FILES}" ]]; then
  GO_FILE_COUNT=$(printf '%s' "${GO_FILES}" | grep -c . || true)
  GO_RUNNER=$(_resolve_runner "go")

  if [[ -z "${GO_RUNNER}" ]]; then
    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify skipped: lang=go runner-not-found\n' \
      "${_TS}" >> "${LOG_FILE}"
  else
    GO_OUT=""
    GO_RC=0
    GO_OUT=$("${GO_RUNNER}" test ./... 2>&1) || GO_RC=$?

    if [[ "${GO_RC}" -ne 0 ]]; then
      FIRST_FAIL=$(printf '%s' "${GO_OUT}" | grep -E '^--- FAIL: |^FAIL\t' | head -1 \
        | sed 's/^--- FAIL: //;s/^FAIL	//' || true)
      [[ -z "${FIRST_FAIL}" ]] && FIRST_FAIL="(unknown go test)"

      printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
      printf '%s stop-verify BLOCK: lang=go rc=%d first_fail=%s files=%d\n' \
        "${_TS}" "${GO_RC}" "${FIRST_FAIL}" "${GO_FILE_COUNT}" >> "${LOG_FILE}"

      jq -n --arg reason "smoke test failed (go): ${FIRST_FAIL}" \
        '{decision: "block", reason: $reason, suppressOutput: false}'
      exit 0
    fi

    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify pass: lang=go files=%d\n' \
      "${_TS}" "${GO_FILE_COUNT}" >> "${LOG_FILE}"
  fi
fi

# --- Phase: .ts/.tsx → tsc --noEmit ---
if [[ -n "${TS_FILES}" ]]; then
  TS_FILE_COUNT=$(printf '%s' "${TS_FILES}" | grep -c . || true)
  TSC_RUNNER=$(_resolve_runner "tsc")

  if [[ -z "${TSC_RUNNER}" ]]; then
    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify skipped: lang=ts runner-not-found\n' \
      "${_TS}" >> "${LOG_FILE}"
  else
    TSC_OUT=""
    TSC_RC=0
    # tsc --noEmit only: type-check without emitting files
    TSC_OUT=$("${TSC_RUNNER}" --noEmit 2>&1) || TSC_RC=$?

    if [[ "${TSC_RC}" -ne 0 ]]; then
      FIRST_FAIL=$(printf '%s' "${TSC_OUT}" | grep -E 'error TS' | head -1 || true)
      [[ -z "${FIRST_FAIL}" ]] && FIRST_FAIL="(unknown tsc error)"

      printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
      printf '%s stop-verify BLOCK: lang=ts rc=%d first_fail=%s files=%d\n' \
        "${_TS}" "${TSC_RC}" "${FIRST_FAIL}" "${TS_FILE_COUNT}" >> "${LOG_FILE}"

      jq -n --arg reason "smoke test failed (ts): ${FIRST_FAIL}" \
        '{decision: "block", reason: $reason, suppressOutput: false}'
      exit 0
    fi

    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify pass: lang=ts files=%d\n' \
      "${_TS}" "${TS_FILE_COUNT}" >> "${LOG_FILE}"
  fi
fi

# --- Phase: .py → pytest -x ---
if [[ -n "${PY_FILES}" ]]; then
  PY_FILE_COUNT=$(printf '%s' "${PY_FILES}" | grep -c . || true)
  PYTEST_RUNNER=$(_resolve_runner "pytest")

  if [[ -z "${PYTEST_RUNNER}" ]]; then
    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify skipped: lang=py runner-not-found\n' \
      "${_TS}" >> "${LOG_FILE}"
  else
    PY_OUT=""
    PY_RC=0
    PY_OUT=$("${PYTEST_RUNNER}" -x 2>&1) || PY_RC=$?

    if [[ "${PY_RC}" -ne 0 ]]; then
      FIRST_FAIL=$(printf '%s' "${PY_OUT}" | grep -E '^FAILED ' | head -1 \
        | sed 's/^FAILED //' || true)
      [[ -z "${FIRST_FAIL}" ]] && FIRST_FAIL="(unknown pytest)"

      printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
      printf '%s stop-verify BLOCK: lang=py rc=%d first_fail=%s files=%d\n' \
        "${_TS}" "${PY_RC}" "${FIRST_FAIL}" "${PY_FILE_COUNT}" >> "${LOG_FILE}"

      jq -n --arg reason "smoke test failed (py): ${FIRST_FAIL}" \
        '{decision: "block", reason: $reason, suppressOutput: false}'
      exit 0
    fi

    printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
    printf '%s stop-verify pass: lang=py files=%d\n' \
      "${_TS}" "${PY_FILE_COUNT}" >> "${LOG_FILE}"
  fi
fi

# no recognized code extension changed (or all languages passed)
printf -v _TS '%(%Y-%m-%dT%H:%M:%S)T' -1
printf '%s stop-verify done: no block\n' \
  "${_TS}" >> "${LOG_FILE}"
exit 0
