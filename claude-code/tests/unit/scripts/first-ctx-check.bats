#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/first-ctx-check.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/first-ctx-check.sh"
  export TEST_PROJECTS_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_PROJECTS_DIR}"
}

@test "first-ctx-check.sh: 対象 session がなければ exit 0" {
  run env CLAUDE_PROJECTS_DIR="${TEST_PROJECTS_DIR}" bash "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "対象 session がない" ]]
}

@test "first-ctx-check.sh: 不明な option は exit 2" {
  run env CLAUDE_PROJECTS_DIR="${TEST_PROJECTS_DIR}" bash "${SCRIPT_FILE}" --unknown-flag
  [ "$status" -eq 2 ]
}
