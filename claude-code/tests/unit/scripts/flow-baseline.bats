#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/flow-baseline.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/flow-baseline.sh"
  export TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.claude/projects"
}

teardown() {
  rm -rf "${TEST_HOME}"
}

@test "flow-baseline.sh: --help は usage を表示して exit 0" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: flow-baseline.sh" ]]
}

@test "flow-baseline.sh: jsonl がなければ exit 0 で INFO 表示" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "no jsonl files found" ]]
}

@test "flow-baseline.sh: --since 不正形式は exit 2" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --since abc
  [ "$status" -eq 2 ]
}
