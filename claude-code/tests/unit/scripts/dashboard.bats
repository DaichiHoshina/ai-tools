#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/dashboard.sh
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/dashboard.sh"
  export TEST_HOME="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_HOME}"
}

@test "dashboard.sh: analytics DB 不在なら exit 1 でエラーメッセージを出す" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Analytics DB not found" ]]
}
