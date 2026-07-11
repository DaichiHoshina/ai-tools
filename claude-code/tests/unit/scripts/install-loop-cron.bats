#!/usr/bin/env bats
#
# install-loop-cron.sh テストスイート
#
# 方針: HOME を tmpdir に隔離し、MVL enforcement (Status: done 必須) と
#   plist 生成 (--dry-run) を検証する。launchctl は叩かない。
#

setup() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export HOME="$TEST_DIR/home"
  mkdir -p "$HOME"

  INSTALL_SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)/scripts/install-loop-cron.sh"
  export INSTALL_SCRIPT
  # 開発中は worktree 配下から実行するため guard を明示 skip
  export LOOP_CRON_ALLOW_WT=1
}

teardown() {
  [[ -d "$TEST_DIR" ]] && rm -rf "$TEST_DIR"
}

_mark_done() {
  mkdir -p "$HOME/.claude/loops/t1"
  printf -- '- Status: done\n' > "$HOME/.claude/loops/t1/state.md"
}

@test "manual run 実績なし → MVL enforcement で exit 2" {
  run bash "$INSTALL_SCRIPT" --name t1 --gate "true" --schedule "0 9 * * 1" --dry-run
  [[ $status -eq 2 ]]
  grep -q 'Status: done' <<< "$output"
}

@test "LOOP_CRON_FORCE=1 で enforcement を skip できる" {
  LOOP_CRON_FORCE=1 run bash "$INSTALL_SCRIPT" --name t1 --gate "true" --schedule "0 9 * * 1" --dry-run
  [[ $status -eq 0 ]]
}

@test "Status: done あり + --dry-run → plist preview (label / schedule / gate)" {
  _mark_done
  run bash "$INSTALL_SCRIPT" --name t1 --gate "bats tests/" --schedule "30 9 * * 1" --dry-run
  [[ $status -eq 0 ]]
  grep -q 'com.daichi.loop.t1' <<< "$output"
  grep -q '<key>Minute</key><integer>30</integer>' <<< "$output"
  grep -q '<key>Weekday</key><integer>1</integer>' <<< "$output"
  # dom / mon は * なので key が出ない
  ! grep -q '<key>Day</key>' <<< "$output"
  grep -q -- "--gate 'bats tests/'" <<< "$output"
}

@test "schedule が 5 field でない → exit 2" {
  _mark_done
  run bash "$INSTALL_SCRIPT" --name t1 --gate "true" --schedule "0 9 *" --dry-run
  [[ $status -eq 2 ]]
}

@test "schedule に range / list → 非対応で exit 2" {
  _mark_done
  run bash "$INSTALL_SCRIPT" --name t1 --gate "true" --schedule "0 9-17 * * 1" --dry-run
  [[ $status -eq 2 ]]
}
