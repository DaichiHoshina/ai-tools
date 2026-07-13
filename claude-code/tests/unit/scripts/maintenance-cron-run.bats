#!/usr/bin/env bats
# =============================================================================
# Smoke tests for scripts/maintenance-cron-run.sh
# 方針: claude CLI を stub 化し実際の headless 実行を回避する
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/maintenance-cron-run.sh"
  export TEST_HOME="$(mktemp -d)"
  export TEST_BIN="$(mktemp -d)"
}

teardown() {
  rm -rf "${TEST_HOME}" "${TEST_BIN}"
}

@test "maintenance-cron-run.sh: claude CLI が見つからなければ exit 2" {
  run env HOME="${TEST_HOME}" PATH="/usr/bin:/bin" CLAUDE_BIN="" bash "${SCRIPT_FILE}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "claude CLI が見つかりません" ]]
}

@test "maintenance-cron-run.sh: claude stub で全 command 実行し log file を作成する" {
  cat > "${TEST_BIN}/claude" << 'EOF'
#!/usr/bin/env bash
echo "stub claude called with: $*"
exit 0
EOF
  chmod +x "${TEST_BIN}/claude"

  run env HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" bash "${SCRIPT_FILE}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "done: " ]]

  local log_file
  log_file=$(echo "$output" | sed -n 's/^done: //p')
  [ -f "${log_file}" ]
  grep -q "memory-clean" "${log_file}"
}
