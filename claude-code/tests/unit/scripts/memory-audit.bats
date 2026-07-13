#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/memory-audit.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/memory-audit.sh"
  export TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.claude/projects"
}

teardown() {
  rm -rf "${TEST_HOME}"
}

@test "memory-audit.sh: --help は usage を表示して exit 0" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: memory-audit.sh" ]]
}

@test "memory-audit.sh: project なしでも exit 0 で report を出力する" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Memory Audit Report" ]]
  [[ "$output" =~ "projects scanned:       0" ]]
}

@test "memory-audit.sh: 不明な option は exit 2" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --unknown-flag
  [ "$status" -eq 2 ]
}
