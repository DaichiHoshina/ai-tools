#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/lib/task-agent-checkers.sh — _handle_task_agent_tool
# pre-tool-use.sh の "Task"|"Agent" case 分岐から切り出した関数の挙動確認
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

@test "task-agent-checkers: subagent_type 未指定は Forbidden (exit 2)" {
  local input
  input=$(jq -n '{tool_name:"Task", tool_input:{prompt:"x"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "task-agent-checkers: SUBTYPE_EMPTY_BLOCK_OFF=1 で subagent_type 未指定は warn 据え置き (exit 0)" {
  local input
  input=$(jq -n '{tool_name:"Task", tool_input:{prompt:"x"}}')
  run bash -c 'echo "$1" | SUBTYPE_EMPTY_BLOCK_OFF=1 bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "subagent_type 未指定" ]]
}

@test "task-agent-checkers: Agent tool 名でも Task と同様に分類される (subagent_type 必須)" {
  local input
  input=$(jq -n '{tool_name:"Agent", tool_input:{prompt:"x"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "task-agent-checkers: Agent tool 名 + explore-agent は Safe (exit 0)" {
  local input
  input=$(jq -n '{tool_name:"Agent", tool_input:{subagent_type:"explore-agent", prompt:"x"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 0 ]
}
