#!/usr/bin/env bats
# Smoke test: hook-bench.sh --log flag
#   --log で ~/.claude/logs/hook-bench-<ts>.log に stdout を tee 保存することを確認する。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROJECT_ROOT
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/hook-bench.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
}

teardown() {
  [[ -d "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
}

@test "--log flag は ~/.claude/logs/ に hook-bench-<ts>.log を生成する" {
  run bash "$SCRIPT_FILE" --hook session-start.sh --log --runs 3 --warmup 1
  [ "$status" -eq 0 ]

  shopt -s nullglob
  local logs=("$TEST_HOME"/.claude/logs/hook-bench-*.log)
  [ "${#logs[@]}" -ge 1 ]

  grep -q "^# hook-bench log:" "${logs[0]}"
  grep -q "^# args:"           "${logs[0]}"
  grep -q "session-start.sh"   "${logs[0]}"
}

@test "--log なしは log file を作らない" {
  run bash "$SCRIPT_FILE" --hook session-start.sh --runs 3 --warmup 1
  [ "$status" -eq 0 ]

  shopt -s nullglob
  local logs=("$TEST_HOME"/.claude/logs/hook-bench-*.log)
  [ "${#logs[@]}" -eq 0 ]
}
