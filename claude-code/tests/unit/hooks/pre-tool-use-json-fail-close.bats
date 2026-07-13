#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — 不正 JSON stdin の fail-close 化
# 不正 JSON 時、set -euo pipefail 下の read が exit 1 して hook error 扱いになると
# Claude Code 側で tool 実行が素通り (fail-open) するため、exit 2 block に倒す回帰保証。
# =============================================================================

setup() {
  load "../../helpers/common"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  setup_test_tmpdir
}

teardown() {
  teardown_test_tmpdir
}

@test "json-fail-close: 不正 JSON (not-json) は exit 2 で block する" {
  run bash -c 'printf "not-json" | bash "$1" 2>&1' _ "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "json-fail-close: 途中で切れた JSON は exit 2 で block する" {
  run bash -c 'printf "{\"tool_name\": \"Read\"" | bash "$1" 2>&1' _ "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "json-fail-close: 空文字 stdin は exit 2 で block する" {
  run bash -c 'printf "" | bash "$1" 2>&1' _ "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "json-fail-close: 不正 JSON 時 stderr に block 理由が出る" {
  run bash -c 'printf "not-json" | bash "$1" 2>&1' _ "$HOOK_FILE"
  [[ "$output" =~ "不正な JSON" ]]
}

@test "json-fail-close: 正常 JSON は従来通り exit 0 で通る" {
  run bash -c 'printf "%s" "$1" | bash "$2"' _ '{"tool_name":"Read","tool_input":{}}' "$HOOK_FILE"
  [ "$status" -eq 0 ]
}
