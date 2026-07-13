#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/usage-stats.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/usage-stats.sh"
  export TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.claude/projects"
}

teardown() {
  rm -rf "${TEST_HOME}"
}

@test "usage-stats.sh: jsonl なしでも exit 0 で Commands/Skills 見出しを出す" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "=== Commands ===" ]]
  [[ "$output" =~ "=== Skills ===" ]]
}

@test "usage-stats.sh: --zero で 0 利用一覧のみ表示する" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --zero
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0 利用" ]]
}

@test "usage-stats.sh: 不明な option は exit 2" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --unknown-flag
  [ "$status" -eq 2 ]
}
