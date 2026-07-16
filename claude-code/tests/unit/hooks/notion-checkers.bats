#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/lib/notion-checkers.sh — _handle_notion_slack_tool
# pre-tool-use.sh の "mcp__claude_ai_Notion__..." / "mcp__claude_ai_Slack__..."
# case 分岐から切り出した関数の挙動確認
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

@test "notion-checkers: notion-create-pages は Safe (exit 0) かつ投稿前自問 additionalContext を含む" {
  local input
  input=$(jq -n '{tool_name:"mcp__claude_ai_Notion__notion-create-pages", tool_input:{content:"普通の内容です"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "投稿前自問5点" ]]
}

@test "notion-checkers: slack_send_message は Safe (exit 0) かつ投稿前自問 additionalContext を含む" {
  local input
  input=$(jq -n '{tool_name:"mcp__claude_ai_Slack__slack_send_message", tool_input:{text:"普通の内容です"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "投稿前自問5点" ]]
}

@test "notion-checkers: AI定型語を含む content は Forbidden (exit 2)" {
  local input
  input=$(jq -n '{tool_name:"mcp__claude_ai_Notion__notion-create-pages", tool_input:{content:"包括的な改善を実施しました"}}')
  run bash -c 'echo "$1" | bash "$2" 2>/dev/null' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
}
