#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/lib/write-checkers.sh — _handle_edit_write_tool
# pre-tool-use.sh の "Edit"|"Write"|"MultiEdit"|"NotebookEdit") case 分岐から
# 切り出した関数の挙動確認
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

@test "write-checkers: 通常の Edit は Forbidden にならない (exit 0)" {
  local target="${TEST_TMPDIR}/normal.txt"
  echo "hello" > "$target"
  result=$(invoke_hook "Edit" "$(jq -n --arg p "$target" --arg o "hello" --arg n "world" \
    '{file_path: $p, old_string: $o, new_string: $n}')")
  [ -n "$result" ]
}

@test "write-checkers: worktree session 内で main repo 直接 Edit は Forbidden (exit 2)" {
  local wt_root="${TEST_TMPDIR}/.claude/worktrees/some-loop"
  mkdir -p "${wt_root}/sub"
  local outside_target="${TEST_TMPDIR}/main-repo/file.txt"
  mkdir -p "$(dirname "$outside_target")"
  echo "x" > "$outside_target"

  CLAUDE_PROJECT_DIR="${wt_root}/sub" run bash -c 'echo "$1" | CLAUDE_PROJECT_DIR="$2" bash "$3" 2>/dev/null' _ \
    "$(jq -n --arg name "Edit" --arg p "$outside_target" --arg o "x" --arg n "y" \
      '{tool_name: $name, tool_input: {file_path: $p, old_string: $o, new_string: $n}}')" \
    "${wt_root}/sub" \
    "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "write-checkers: worktree session 内で worktree 配下 Edit はブロックされない" {
  local wt_root="${TEST_TMPDIR}/.claude/worktrees/some-loop"
  mkdir -p "${wt_root}/sub"
  local inside_target="${wt_root}/sub/file.txt"
  echo "x" > "$inside_target"

  run bash -c 'echo "$1" | CLAUDE_PROJECT_DIR="$2" bash "$3" 2>/dev/null' _ \
    "$(jq -n --arg name "Edit" --arg p "$inside_target" --arg o "x" --arg n "y" \
      '{tool_name: $name, tool_input: {file_path: $p, old_string: $o, new_string: $n}}')" \
    "${wt_root}/sub" \
    "$HOOK_FILE"
  [ "$status" -eq 0 ]
}
