#!/usr/bin/env bats
# sleep-harvest.sh: source 欠損 skip / redact / cap を検証する。sqlite・claude は使わない。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROJECT_ROOT
  SCRIPT="${PROJECT_ROOT}/scripts/sleep-harvest.sh"
  export SCRIPT
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}"
  REPO="${TEST_DIR}/repo"
  export REPO
  mkdir -p "${REPO}/memory"
  export SLEEP_ANALYTICS_DB="${TEST_DIR}/none.db"
  export SLEEP_HISTORY_JSONL="${TEST_DIR}/none.jsonl"
  export SLEEP_LOG_DIR="${TEST_DIR}/logs"
  export SLEEP_SKILL_EVAL="${TEST_DIR}/none.sh"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

@test "sleep-harvest: 全 source 欠損でも exit 0 で skip note を出す" {
  run bash "${SCRIPT}" --days 7 --repo "${REPO}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sleep harvest digest" ]]
  [[ "$output" =~ "(skip: " ]]
}

@test "sleep-harvest: --days が数値以外なら exit 2" {
  run bash "${SCRIPT}" --days abc
  [ "$status" -eq 2 ]
}

@test "sleep-harvest: pending-improvements.md を digest に含める" {
  echo "- pending: test-item-xyz" > "${REPO}/memory/pending-improvements.md"
  run bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "test-item-xyz" ]]
}

@test "sleep-harvest: private term を REDACT する" {
  mkdir -p "${HOME}/.claude/references-private"
  echo "secretcorp" > "${HOME}/.claude/references-private/private-name-list.txt"
  echo "- pending: secretcorp の件" > "${REPO}/memory/pending-improvements.md"
  run bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "[REDACTED]" ]]
  [[ ! "$output" =~ "secretcorp" ]]
}

@test "sleep-harvest: rejected file の heading を含める" {
  printf '### P1: old idea\nREJECT reason x\n' > "${REPO}/memory/sleep-proposals-2026-01-01.rejected.md"
  run bash "${SCRIPT}" --repo "${REPO}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "old idea" ]]
}
