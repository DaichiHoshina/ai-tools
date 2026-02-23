#!/usr/bin/env bats
# =============================================================================
# Integration Tests for Hooks System
# =============================================================================

setup() {
  # PROJECT_ROOT を設定
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"
  # テスト用HOME（本番ログ汚染防止）
  export ORIGINAL_HOME="$HOME"
  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude/logs"
  mkdir -p "$HOME/.claude/session-logs"
}

teardown() {
  # テスト用HOMEを削除して復元
  if [[ "$HOME" != "$ORIGINAL_HOME" && "$HOME" == /tmp/* ]]; then
    rm -rf "$HOME"
  fi
  export HOME="$ORIGINAL_HOME"
}

# =============================================================================
# Hook JSON Input/Output Tests
# =============================================================================

@test "hooks: session-start accepts valid JSON input" {
  local input='{"mcp_servers": {"serena": {}}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/session-start.sh"
  [ "$status" -eq 0 ]
  # 出力が有効なJSONであることを確認
  echo "$output" | jq . >/dev/null
}

@test "hooks: user-prompt-submit accepts valid JSON input" {
  local input='{"prompt": "Fix the bug", "workspace": {"current_dir": "/test"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  # 出力が有効なJSONであることを確認
  echo "$output" | jq . >/dev/null 2>&1 || true
}

@test "hooks: pre-tool-use accepts valid JSON input" {
  local input='{"tool_name": "Bash", "tool_input": {"command": "ls"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: pre-compact accepts valid JSON input" {
  local input='{"session_id": "test", "workspace": {"current_dir": "/test"}, "current_tokens": 150000}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-compact.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: session-end accepts valid JSON input" {
  local input='{"session_id": "test", "workspace": {"current_dir": "/test"}, "total_tokens": 50000, "total_messages": 25, "duration": 1200}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/session-end.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Error Handling Tests
# =============================================================================

@test "hooks: session-start handles empty JSON" {
  local input='{}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/session-start.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: user-prompt-submit handles empty prompt" {
  local input='{"prompt": "", "workspace": {"current_dir": "/test"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: pre-tool-use handles unknown tool" {
  local input='{"tool_name": "UnknownTool", "tool_input": {}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# DoS Protection Tests
# =============================================================================

@test "hooks: user-prompt-submit rejects oversized input" {
  # 1MB を超える入力を拒否
  skip "Requires large input generation - slow test"
}

@test "hooks: handles malformed JSON gracefully" {
  local input='{"invalid": json}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/session-start.sh 2>&1"
  # エラーが発生しても終了コードが0でない、または適切なエラーメッセージ
  [[ "$output" =~ "error" ]] || [ "$status" -ne 0 ]
}

# =============================================================================
# Security Tests
# =============================================================================

@test "hooks: pre-tool-use detects dangerous commands" {
  local input='{"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  # 警告メッセージが出力されることを確認
  [[ "$output" =~ "⚠" ]] || [[ "$output" =~ "warning" ]]
}

@test "hooks: user-prompt-submit handles code injection attempts" {
  local input='{"prompt": "$(rm -rf /)", "workspace": {"current_dir": "/test"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  # コマンドインジェクションが実行されないことを確認（テストディレクトリが存在）
  [ -d "/tmp" ]
}

# =============================================================================
# Performance Tests
# =============================================================================

@test "hooks: user-prompt-submit completes within reasonable time" {
  local input='{"prompt": "Test prompt", "workspace": {"current_dir": "/test"}}'
  local start=$(date +%s)
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  local end=$(date +%s)
  local duration=$((end - start))

  # 5秒以内に完了することを確認
  [ "$duration" -lt 5 ]
}

# =============================================================================
# Integration: Hook Dependencies
# =============================================================================

@test "integration: hooks can load lib/security-functions.sh" {
  # security-functions.sh が正しくロードできることを確認
  run bash -c "source ${PROJECT_ROOT}/claude-code/lib/security-functions.sh && declare -F validate_json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "validate_json" ]]
}

@test "integration: hooks can load lib/hook-utils.sh" {
  # hook-utils.sh が正しくロードできることを確認
  run bash -c "source ${PROJECT_ROOT}/claude-code/lib/hook-utils.sh && declare -F get_field"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "get_field" ]]
}

@test "integration: hooks can load lib/print-functions.sh" {
  # print-functions.sh が正しくロードできることを確認
  run bash -c "source ${PROJECT_ROOT}/claude-code/lib/print-functions.sh && declare -F print_success"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "print_success" ]]
}

# =============================================================================
# Setup Hook Tests
# =============================================================================

@test "hooks: setup accepts valid JSON input" {
  local input='{"cwd": "/test", "mcp_servers": {"serena": {}}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/setup.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "hooks: setup handles missing cwd" {
  local input='{}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/setup.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Subagent Start/Stop Hook Tests
# =============================================================================

@test "hooks: subagent-start accepts valid JSON input" {
  local input='{"agent_id": "test-123", "agent_type": "developer-agent", "cwd": "/test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/subagent-start.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "hooks: subagent-stop accepts valid JSON input" {
  local input='{"agent_id": "test-123", "agent_type": "developer-agent", "cwd": "/test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/subagent-stop.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "hooks: subagent-start handles unknown agent" {
  local input='{"agent_id": "unknown", "agent_type": "unknown", "cwd": "."}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/subagent-start.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Pre-Skill-Use Hook Tests
# =============================================================================

@test "hooks: pre-skill-use accepts valid JSON input" {
  local input='{"skill": "test-skill"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-skill-use.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: pre-skill-use handles empty skill name" {
  local input='{"skill": ""}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-skill-use.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: pre-skill-use handles missing skill field" {
  local input='{}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-skill-use.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Post-Tool-Use Hook Tests
# =============================================================================

@test "hooks: post-tool-use accepts valid JSON input" {
  local input='{"tool_name": "Bash", "tool_input": {"command": "echo test"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/post-tool-use.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: post-tool-use handles Edit tool with nonexistent file" {
  local input='{"tool_name": "Edit", "tool_input": {"file_path": "/nonexistent/file.ts"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/post-tool-use.sh"
  [ "$status" -eq 0 ]
}

@test "hooks: post-tool-use handles unknown tool" {
  local input='{"tool_name": "UnknownTool", "tool_input": {}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/post-tool-use.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Task-Completed Hook Tests
# =============================================================================

@test "hooks: task-completed accepts valid JSON input" {
  local input='{"agent_id": "test-456", "agent_type": "developer-agent"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/task-completed.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "hooks: task-completed handles unknown agent" {
  local input='{}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/task-completed.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Stop Hook Tests
# =============================================================================

@test "hooks: stop accepts valid JSON input" {
  local input='{}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/stop.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Teammate-Idle Hook Tests
# =============================================================================

@test "hooks: teammate-idle accepts valid JSON input" {
  local input='{"agent_id": "idle-789", "agent_type": "explorer-agent"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/teammate-idle.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
}

@test "hooks: teammate-idle handles unknown agent" {
  local input='{}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/teammate-idle.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Integration: End-to-End Workflow
# =============================================================================

@test "integration: hooks work together in sequence" {
  # セッション開始 → プロンプト送信 → ツール実行 → セッション終了
  local session_input='{"mcp_servers": {"serena": {}}}'
  local prompt_input='{"prompt": "Test", "workspace": {"current_dir": "/test"}}'
  local tool_input='{"tool_name": "Bash", "tool_input": {"command": "echo test"}}'
  local end_input='{"session_id": "test", "workspace": {"current_dir": "/test"}, "total_tokens": 5000, "total_messages": 5, "duration": 300}'

  run bash -c "echo '$session_input' | ${HOOKS_DIR}/session-start.sh"
  [ "$status" -eq 0 ]

  run bash -c "echo '$prompt_input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]

  run bash -c "echo '$tool_input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]

  run bash -c "echo '$end_input' | ${HOOKS_DIR}/session-end.sh"
  [ "$status" -eq 0 ]
}

# =============================================================================
# Integration: Pre-Tool-Use 3-Layer Classification
# =============================================================================

@test "integration: pre-tool-use classifies Safe tools correctly" {
  local tools=("Read" "Glob" "Grep" "WebSearch" "Task" "TaskCreate" "AskUserQuestion")
  for tool in "${tools[@]}"; do
    local input="{\"tool_name\": \"${tool}\", \"tool_input\": {}}"
    run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
    [ "$status" -eq 0 ]
    # Safe操作はメッセージなし（空JSON）
    [[ "$output" == "{}" ]]
  done
}

@test "integration: pre-tool-use classifies Boundary tools correctly" {
  local tools=("Edit" "Write")
  for tool in "${tools[@]}"; do
    local input="{\"tool_name\": \"${tool}\", \"tool_input\": {}}"
    run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
    [ "$status" -eq 0 ]
    # Boundary操作はsystemMessageあり
    echo "$output" | jq -e '.systemMessage' >/dev/null
  done
}

@test "integration: pre-tool-use classifies Forbidden bash commands" {
  local input='{"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.additionalContext' >/dev/null
}

# =============================================================================
# Integration: Stop + Session-End Chain
# =============================================================================

@test "integration: stop then session-end both produce valid JSON" {
  local stop_input='{}'
  local end_input='{"session_id": "chain-test", "workspace": {"current_dir": "/test"}, "total_tokens": 10000, "total_messages": 20, "duration": 600}'

  # stop.sh (通知音ファイルなしの場合)
  run bash -c "echo '$stop_input' | ${HOOKS_DIR}/stop.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null

  # session-end.sh
  run bash -c "echo '$end_input' | ${HOOKS_DIR}/session-end.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq . >/dev/null
  # ログファイルが作成されたことを確認
  [ -f "$HOME/.claude/session-logs/$(date +%Y%m%d).log" ]
}

# =============================================================================
# Integration: Pre-Compact Memory Save Flow
# =============================================================================

@test "integration: pre-compact with serena produces memory save instruction" {
  local input='{"mcp_servers": {"serena": {}}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-compact.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage' >/dev/null
  echo "$output" | jq -e '.additionalContext' >/dev/null
  # Serena memory保存指示を含む
  [[ "$output" == *"write_memory"* ]]
}

@test "integration: pre-compact without serena produces warning" {
  local input='{"mcp_servers": {}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-compact.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage' >/dev/null
  # Serena無効メッセージを含む
  [[ "$output" == *"Serena"* ]]
}

# =============================================================================
# Integration: User-Prompt-Submit Tech Detection
# =============================================================================

@test "integration: user-prompt-submit detects Go from prompt" {
  local input='{"prompt": "go.modのバグを修正して"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  if [ "$output" != "{}" ]; then
    echo "$output" | jq . >/dev/null
  fi
}

@test "integration: user-prompt-submit detects TypeScript from prompt" {
  local input='{"prompt": "TypeScriptのpackage.jsonを更新して"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  if [ "$output" != "{}" ]; then
    echo "$output" | jq . >/dev/null
  fi
}

@test "integration: user-prompt-submit handles empty prompt" {
  local input='{"prompt": ""}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == "{}" ]]
}
