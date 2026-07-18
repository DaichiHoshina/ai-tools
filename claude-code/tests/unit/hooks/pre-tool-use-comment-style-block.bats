#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — comment 体言止め block (2026-07-18)
# 連発 (3 件以上 or 連続 2 行) のみ exit 2 で block し、単発 1-2 件は warn に留める
# (natural-japanese コーパス分析による 2026-07-18 緩和)
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

@test "comment-style-block: Edit new_string の単発体言止め comment は block されず warn に留まる" {
  local input
  input=$(jq -n '{tool_name:"Edit", tool_input:{file_path:"/tmp/cs-block-1.go", old_string:"foo()", new_string:"// 改行文字の処理\nfoo()"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
  [[ "$output" =~ "体言止め" ]]
}

@test "comment-style-block: Edit new_string の連続 2 行体言止めは exit 2 block" {
  local input
  input=$(jq -n '{tool_name:"Edit", tool_input:{file_path:"/tmp/cs-block-1b.go", old_string:"foo()", new_string:"// 改行文字の処理\n// 空白文字の除去\nfoo()"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "連発" ]]
}

@test "comment-style-block: Edit new_string の非連続 3 件体言止めは exit 2 block" {
  local input
  input=$(jq -n '{tool_name:"Edit", tool_input:{file_path:"/tmp/cs-block-1c.go", old_string:"foo()", new_string:"// 改行文字の処理\nfoo()\n// 空白文字の除去\nbar()\n// 末尾記号の削除\nbaz()"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "連発" ]]
}

@test "comment-style-block: Edit new_string の常体で閉じた comment (五段活用く終止) は block されない" {
  local input
  input=$(jq -n '{tool_name:"Edit", tool_input:{file_path:"/tmp/cs-block-2.go", old_string:"foo()", new_string:"// 常体で閉じたcommentを書く\nfoo()"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
}

@test "comment-style-block: Write 新規 file の単発体言止め comment は block されない" {
  local input
  input=$(jq -n '{tool_name:"Write", tool_input:{file_path:"/tmp/cs-block-3-new.go", content:"package main\n// 改行文字の処理\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
}

@test "comment-style-block: Write 新規 file の連続 2 行体言止めは exit 2 block" {
  local input
  input=$(jq -n '{tool_name:"Write", tool_input:{file_path:"/tmp/cs-block-3b-new.go", content:"package main\n// 改行文字の処理\n// 空白文字の除去\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "連発" ]]
}

@test "comment-style-block: Write 既存 file の変更なし comment は block されない (新規行なし)" {
  local tmpfile
  tmpfile=$(mktemp "${BATS_TEST_TMPDIR}/cs-block-existing-XXXX.go")
  printf 'package main\n// 改行文字の処理\nfunc main() {}\n' > "$tmpfile"
  local input
  input=$(jq -n --arg p "$tmpfile" '{tool_name:"Write", tool_input:{file_path:$p, content:"package main\n// 改行文字の処理\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
}

@test "comment-style-block: Write 既存 file への新規体言止め連続 2 行追加は exit 2 block" {
  local tmpfile
  tmpfile=$(mktemp "${BATS_TEST_TMPDIR}/cs-block-add-XXXX.go")
  printf 'package main\nfunc main() {}\n' > "$tmpfile"
  local input
  input=$(jq -n --arg p "$tmpfile" '{tool_name:"Write", tool_input:{file_path:$p, content:"package main\n// 新規の追加処理\n// 空白文字の除去\nfunc main() {}\n"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "新規の追加処理" ]]
}

@test "comment-style-block: Serena replace_symbol_body の単発体言止めは block されない" {
  local input
  input=$(jq -n '{tool_name:"mcp__serena__replace_symbol_body", tool_input:{relative_path:"pkg/foo.go", name_path:"Foo", body:"func Foo() {\n\t// 改行文字の処理\n}"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
}

@test "comment-style-block: Serena replace_symbol_body の連続 2 行体言止めは exit 2 block" {
  local input
  input=$(jq -n '{tool_name:"mcp__serena__replace_symbol_body", tool_input:{relative_path:"pkg/foo.go", name_path:"Foo", body:"func Foo() {\n\t// 改行文字の処理\n\t// 空白文字の除去\n}"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "連発" ]]
}

@test "comment-style-block: Serena replace_content の常体で閉じた comment は block されない" {
  local input
  input=$(jq -n '{tool_name:"mcp__serena__replace_content", tool_input:{relative_path:"pkg/foo.go", needle:"x", repl:"// 常体で閉じたcommentを書く\nfoo()", mode:"literal"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -ne 2 ]
}
