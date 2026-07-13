#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/hook-bench-ci.sh
# 方針: 実 benchmark 実行 (重い) は避け、引数検証パスのみ確認する
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/hook-bench-ci.sh"
}

@test "hook-bench-ci.sh: mode 未指定は exit 2" {
  run bash "${SCRIPT_FILE}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "--check or --update-baseline required" ]]
}

@test "hook-bench-ci.sh: 不明な option は exit 2" {
  run bash "${SCRIPT_FILE}" --unknown-flag
  [ "$status" -eq 2 ]
}
