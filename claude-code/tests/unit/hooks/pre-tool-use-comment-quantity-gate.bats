#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — comment 量 gate (2026-07-18)
# 新規 comment 行が 3 行以上で exit 2 block、1-2 行で warn を発火させる動作
# =============================================================================

setup() {
  load "../../helpers/common"
  load "../../helpers/hook-invoke"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  setup_test_tmpdir
}

teardown() {
  teardown_test_tmpdir
}

@test "comment-quantity-gate: Write で新規日本語 comment 3 行は exit 2 block" {
  local input
  input=$(jq -n '{tool_name:"Write", tool_input:{file_path:"/tmp/cqg-block-1.go", content:"package main\n// 一行目の説明を書く\n// 二行目の説明を書く\n// 三行目の説明を書く\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "comment 量 block" ]]
}

@test "comment-quantity-gate: Write で新規日本語 comment 2 行は block されず warn になる" {
  local input
  input=$(jq -n '{tool_name:"Write", tool_input:{file_path:"/tmp/cqg-warn-1.go", content:"package main\n// 一行目の説明を書く\n// 二行目の説明を書く\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
  [[ "$output" =~ "comment 量 warn" ]]
}

@test "comment-quantity-gate: directive comment (eslint-disable 等) は行数カウント対象外" {
  local input
  input=$(jq -n '{tool_name:"Write", tool_input:{file_path:"/tmp/cqg-directive-1.go", content:"package main\n// eslint-disable-next-line\n// nolint:errcheck\n// 一行目の説明を書く\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
  [[ ! "$output" =~ "comment 量 block" ]]
}

@test "comment-quantity-gate: 英語のみ comment は日本語対象外のため block されない" {
  local input
  input=$(jq -n '{tool_name:"Write", tool_input:{file_path:"/tmp/cqg-english-1.go", content:"package main\n// first line comment\n// second line comment\n// third line comment\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
  [[ ! "$output" =~ "comment 量" ]]
}

@test "comment-quantity-gate: Serena replace_symbol_body の新規日本語 comment 3 行は exit 2 block" {
  local input
  input=$(jq -n '{tool_name:"mcp__serena__replace_symbol_body", tool_input:{relative_path:"pkg/foo.go", name_path:"Foo", body:"func Foo() {\n\t// 一行目の説明を書く\n\t// 二行目の説明を書く\n\t// 三行目の説明を書く\n}"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "comment 量 block" ]]
}

@test "comment-quantity-gate: Edit new_string の新規日本語 comment 1 行は block されず warn になる" {
  local input
  input=$(jq -n '{tool_name:"Edit", tool_input:{file_path:"/tmp/cqg-edit-1.go", old_string:"foo()", new_string:"// 一行だけ説明を書く\nfoo()"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
  [[ "$output" =~ "comment 量 warn" ]]
}
