#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/health-check.sh
# 方針: --bench-skip / --plans-skip で重い hook-bench 計測を回避する
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/health-check.sh"
  export TEST_HOME="$(mktemp -d)"
  mkdir -p "${TEST_HOME}/.claude/projects"
}

teardown() {
  rm -rf "${TEST_HOME}"
}

@test "health-check.sh: --bench-skip --plans-skip で正常終了し主要見出しを含む" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --bench-skip --plans-skip
  [ "$status" -eq 0 ]
  [[ "$output" =~ "# Claude Code Health Check" ]]
  [[ "$output" =~ "## Usage" ]]
}

@test "health-check.sh: 不明な option は exit 2" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --unknown-flag
  [ "$status" -eq 2 ]
}

@test "health-check.sh: --bench-repeats に非整数を渡すと exit 2" {
  run env HOME="${TEST_HOME}" bash "${SCRIPT_FILE}" --bench-repeats abc
  [ "$status" -eq 2 ]
}
