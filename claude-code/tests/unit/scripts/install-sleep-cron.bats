#!/usr/bin/env bats
# install-sleep-cron.sh: MVL enforcement と plist 生成 (--dry-run) を検証する。launchctl は叩かない。

setup() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export HOME="${TEST_DIR}/home"
  mkdir -p "${HOME}"
  INSTALL_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)/scripts/install-sleep-cron.sh"
  export INSTALL_SCRIPT
  export SLEEP_CRON_ALLOW_WT=1
}

teardown() {
  rm -rf "${TEST_DIR}"
}

_mark_done() {
  mkdir -p "${HOME}/.claude/sleep"
  printf -- '- Status: done\n' > "${HOME}/.claude/sleep/state.md"
}

@test "manual run 実績なし → MVL enforcement で exit 2" {
  run bash "${INSTALL_SCRIPT}" --dry-run
  [ "$status" -eq 2 ]
  grep -q 'Status: done' <<< "$output"
}

@test "SLEEP_CRON_FORCE=1 で enforcement を skip できる" {
  SLEEP_CRON_FORCE=1 run bash "${INSTALL_SCRIPT}" --dry-run
  [ "$status" -eq 0 ]
}

@test "Status: done + --dry-run → plist preview (label / default 03:30)" {
  _mark_done
  run bash "${INSTALL_SCRIPT}" --dry-run
  [ "$status" -eq 0 ]
  grep -q 'com.daichi.sleep-pipeline.daily' <<< "$output"
  grep -q '<key>Minute</key><integer>30</integer>' <<< "$output"
  grep -q '<key>Hour</key><integer>3</integer>' <<< "$output"
  ! grep -q '<key>Weekday</key>' <<< "$output"
}

@test "schedule が 5 field でない → exit 2" {
  _mark_done
  run bash "${INSTALL_SCRIPT}" --schedule "0 3 *" --dry-run
  [ "$status" -eq 2 ]
}

@test "schedule に range → 非対応で exit 2" {
  _mark_done
  run bash "${INSTALL_SCRIPT}" --schedule "0 3-5 * * *" --dry-run
  [ "$status" -eq 2 ]
}
