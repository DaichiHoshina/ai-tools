#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/session-cost-top.sh
# 方針: ccusage 未インストール環境が前提 (実 network を叩かない)
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/session-cost-top.sh"
}

@test "session-cost-top.sh: --help は usage を表示して exit 0" {
  run bash "${SCRIPT_FILE}" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "session-cost-top.sh" ]]
}

@test "session-cost-top.sh: ccusage が PATH になければ exit 1" {
  run env PATH="/usr/bin:/bin" bash "${SCRIPT_FILE}"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ccusage not found" ]]
}

@test "session-cost-top.sh: 不明な option は exit 2" {
  run bash "${SCRIPT_FILE}" --unknown-flag
  [ "$status" -eq 2 ]
}
