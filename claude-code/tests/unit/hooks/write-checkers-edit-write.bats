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

# =============================================================================
# 追加 5 関数の bats coverage
# session_id top-level field 付き Write 呼び出し helper (churn / 大repo 判定用)。
# CLAUDE_CODE_SESSION_ID の env leak を避けるため env -u で明示的に外す。
# =============================================================================
_invoke_write_with_session() {
  local file_path="$1"
  local content="$2"
  local session_id="$3"
  local input
  if [ -n "$session_id" ]; then
    input=$(jq -n --arg p "$file_path" --arg c "$content" --arg sid "$session_id" \
      '{tool_name: "Write", tool_input: {file_path: $p, content: $c}, session_id: $sid}')
  else
    input=$(jq -n --arg p "$file_path" --arg c "$content" \
      '{tool_name: "Write", tool_input: {file_path: $p, content: $c}}')
  fi
  echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "$HOOK_FILE"
}

@test "write-checkers: migration safety warn — .up.sql に対応する down.sql が無いと warn" {
  export CLAUDE_TARGET_PROJECT_PATH_PATTERN="${TEST_TMPDIR}/*"
  local target="${TEST_TMPDIR}/db/001_test.up.sql"
  mkdir -p "$(dirname "$target")"
  local result
  result=$(_invoke_write_with_session "$target" "ALTER TABLE foo ADD COLUMN bar text;" "")
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  local ctx
  ctx=$(get_additional_context "$result")
  [[ "$ctx" == *"migration safety warn"* ]]
  [[ "$ctx" == *"down.sql が存在しない"* ]]
}

@test "write-checkers: migration safety no-op — CLAUDE_TARGET_PROJECT_PATH_PATTERN 未設定" {
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  local target="${TEST_TMPDIR}/db/001_test.up.sql"
  mkdir -p "$(dirname "$target")"
  local result
  result=$(_invoke_write_with_session "$target" "ALTER TABLE foo ADD COLUMN bar text;" "")
  local ctx
  ctx=$(get_additional_context "$result")
  # 他 hook (今日の commit inject 等) の unrelated context 混入は許容し、対象関数の
  # warn marker が出ていないことだけを確認する
  [[ "$ctx" != *"migration safety warn"* ]]
}

@test "write-checkers: edit churn warn — 同一 path 3 回目の書き換えで warn" {
  setup_home_isolated
  local target="${TEST_TMPDIR}/churn.txt"
  local session="churn-test-$$"
  _invoke_write_with_session "$target" "v1" "$session" >/dev/null
  _invoke_write_with_session "$target" "v2" "$session" >/dev/null
  local result
  result=$(_invoke_write_with_session "$target" "v3" "$session")
  teardown_home_isolated
  local ctx
  ctx=$(get_additional_context "$result")
  [[ "$ctx" == *"churn warn"* ]]
}

@test "write-checkers: edit churn no-op — session_id 空なら state file を作らない" {
  setup_home_isolated
  local target="${TEST_TMPDIR}/churn-noop.txt"
  local result
  result=$(_invoke_write_with_session "$target" "v1" "")
  local state_dir="${HOME}/.claude/state"
  teardown_home_isolated
  local ctx
  ctx=$(get_additional_context "$result")
  [ -z "$ctx" ]
  [ ! -d "$state_dir" ] || [ -z "$(ls -A "$state_dir" 2>/dev/null)" ]
}

@test "write-checkers: AI 造語 block — pattern 一致で hard-block (exit 2)" {
  export CLAUDE_TARGET_PROJECT_PATH_PATTERN="${TEST_TMPDIR}/*"
  export CLAUDE_AI_COINED_TERMS_PATTERN='banned_word'
  local target="${TEST_TMPDIR}/doc.md"
  local input
  input=$(jq -n --arg p "$target" --arg c "この文書には banned_word が含まれる。" \
    '{tool_name: "Write", tool_input: {file_path: $p, content: $c}}')
  run bash -c 'echo "$1" | bash "$2" 2>&1' _ "$input" "$HOOK_FILE"
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  unset CLAUDE_AI_COINED_TERMS_PATTERN
  [ "$status" -eq 2 ]
  [[ "$output" == *"AI 造語 block"* ]]
}

@test "write-checkers: AI 造語 no-op — CLAUDE_AI_COINED_TERMS_PATTERN 未設定なら通過" {
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  unset CLAUDE_AI_COINED_TERMS_PATTERN
  local target="${TEST_TMPDIR}/doc.md"
  local input
  input=$(jq -n --arg p "$target" --arg c "この文書には banned_word が含まれる。" \
    '{tool_name: "Write", tool_input: {file_path: $p, content: $c}}')
  run bash -c 'echo "$1" | bash "$2" 2>/dev/null' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 0 ]
}

@test "write-checkers: subtest parallel warn — t.Run に t.Parallel() 欠如で warn" {
  export CLAUDE_TARGET_PROJECT_PATH_PATTERN="${TEST_TMPDIR}/*"
  local target="${TEST_TMPDIR}/foo_test.go"
  local content
  content=$'func TestFoo(t *testing.T) {\n\tt.Run("case1", func(t *testing.T) {\n\t\tif true {\n\t\t\tdoSomething()\n\t\t}\n\t})\n}'
  local result
  result=$(_invoke_write_with_session "$target" "$content" "")
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  local ctx
  ctx=$(get_additional_context "$result")
  [[ "$ctx" == *"subtest parallel warn"* ]]
}

@test "write-checkers: subtest parallel no-op — CLAUDE_TARGET_PROJECT_PATH_PATTERN 未設定" {
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  local target="${TEST_TMPDIR}/foo_test.go"
  local content
  content=$'func TestFoo(t *testing.T) {\n\tt.Run("case1", func(t *testing.T) {\n\t\tif true {\n\t\t\tdoSomething()\n\t\t}\n\t})\n}'
  local result
  result=$(_invoke_write_with_session "$target" "$content" "")
  local ctx
  ctx=$(get_additional_context "$result")
  # 他 hook (今日の commit inject 等) の unrelated context 混入は許容し、対象関数の
  # warn marker が出ていないことだけを確認する
  [[ "$ctx" != *"subtest parallel warn"* ]]
}

@test "write-checkers: sql.Null 手書き block — 非 test file で hard-block (exit 2)" {
  export CLAUDE_TARGET_PROJECT_PATH_PATTERN="${TEST_TMPDIR}/*"
  local target="${TEST_TMPDIR}/foo.go"
  local input
  input=$(jq -n --arg p "$target" --arg c 'var x sql.NullString' \
    '{tool_name: "Write", tool_input: {file_path: $p, content: $c}}')
  run bash -c 'echo "$1" | bash "$2" 2>&1' _ "$input" "$HOOK_FILE"
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  [ "$status" -eq 2 ]
  [[ "$output" == *"sql.Null"*"手書き block"* ]]
}

@test "write-checkers: sql.Null no-op — _test.go は除外対象" {
  export CLAUDE_TARGET_PROJECT_PATH_PATTERN="${TEST_TMPDIR}/*"
  local target="${TEST_TMPDIR}/foo_test.go"
  local input
  input=$(jq -n --arg p "$target" --arg c 'var x sql.NullString' \
    '{tool_name: "Write", tool_input: {file_path: $p, content: $c}}')
  run bash -c 'echo "$1" | bash "$2" 2>/dev/null' _ "$input" "$HOOK_FILE"
  unset CLAUDE_TARGET_PROJECT_PATH_PATTERN
  [ "$status" -eq 0 ]
}
