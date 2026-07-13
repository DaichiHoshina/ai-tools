#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/memory-dangling-check.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/memory-dangling-check.sh"
  export TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

@test "memory-dangling-check.sh: --help は usage を表示して exit 0" {
  run bash "${SCRIPT_FILE}" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: memory-dangling-check.sh" ]]
}

@test "memory-dangling-check.sh: dir 不在は SKIP で exit 0" {
  run bash "${SCRIPT_FILE}" --dir "${TEST_DIR}/nonexistent"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SKIP: dir not found" ]]
}

@test "memory-dangling-check.sh: dangling entry がある dir は WARNING を出しつつ exit 0" {
  local mem_dir="${TEST_DIR}/memory"
  mkdir -p "${mem_dir}"
  printf -- '- [Missing](missing.md) — hook\n' > "${mem_dir}/MEMORY.md"
  run bash "${SCRIPT_FILE}" --dir "${mem_dir}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "WARNING: memory integrity issues detected" ]]
  [[ "$output" =~ "missing.md" ]]
}
