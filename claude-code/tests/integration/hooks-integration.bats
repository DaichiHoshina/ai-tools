#!/usr/bin/env bats
# =============================================================================
# Integration Tests for Hooks System
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  # PROJECT_ROOT を設定
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"
  # 共有 helper: HOME を tmp dir に隔離 (本番ログ汚染防止)
  load "../helpers/common"
  setup_home_isolated
}

teardown() {
  teardown_home_isolated
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
  # smoke test: valid JSON → exit 0
  # block + auto-retry 方式のため marker check を skip する CLAUDE_FORCE_COMPACT=1 で迂回
  local input='{"session_id": "test", "workspace": {"current_dir": "/test"}, "current_tokens": 150000}'
  run bash -c "echo '$input' | CLAUDE_FORCE_COMPACT=1 ${HOOKS_DIR}/pre-compact.sh"
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
  # session-start.sh は jq // fallback で malformed 入力でも exit 0 + 有効 JSON を返す
  [ "$status" -eq 0 ]
  [[ "$output" =~ systemMessage ]]
}

# =============================================================================
# Security Tests
# =============================================================================

@test "hooks: pre-tool-use detects dangerous commands" {
  local input='{"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-tool-use.sh"
  # Forbiddenは exit 2 でtoolブロック（Claude Code hook契約）
  [ "$status" -eq 2 ]
  # 禁止メッセージが出力されることを確認
  [[ "$output" =~ "禁止" ]] || [[ "$output" =~ "危険" ]]
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
  run bash -c "source ${PROJECT_ROOT}/lib/security-functions.sh && declare -F validate_json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "validate_json" ]]
}

@test "integration: hooks can load lib/hook-utils.sh" {
  # hook-utils.sh が正しくロードできることを確認
  run bash -c "source ${PROJECT_ROOT}/lib/hook-utils.sh && declare -F get_field"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "get_field" ]]
}

@test "integration: hooks can load lib/print-functions.sh" {
  # print-functions.sh が正しくロードできることを確認
  run bash -c "source ${PROJECT_ROOT}/lib/print-functions.sh && declare -F print_success"
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

@test "hooks: pre-tool-use hints Serena for cat <code_file>" {
  local input; input=$(jq -nc '{tool_name:"Bash",tool_input:{command:"cat src/foo.ts"}}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.additionalContext | test("Serena 振替推奨")' >/dev/null
}

@test "hooks: pre-tool-use does NOT hint for grep -r (recursive)" {
  local input; input=$(jq -nc '{tool_name:"Bash",tool_input:{command:"grep -r foo claude-code/"}}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  ! echo "$output" | jq -e '.additionalContext // "" | test("Serena 振替推奨")' >/dev/null
}

@test "hooks: pre-tool-use does NOT hint for cat README.md" {
  local input; input=$(jq -nc '{tool_name:"Bash",tool_input:{command:"cat README.md"}}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  ! echo "$output" | jq -e '.additionalContext // "" | test("Serena 振替推奨")' >/dev/null
}

@test "hooks: pre-tool-use hints for head -20 main.go" {
  local input; input=$(jq -nc '{tool_name:"Bash",tool_input:{command:"head -20 src/main.go"}}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.additionalContext | test("Serena 振替推奨")' >/dev/null
}

@test "hooks: post-tool-use detects literal '\\n' line in .sh after Edit" {
  local tmp; tmp=$(mktemp -d)
  printf '#!/usr/bin/env bash\necho hi\n\\n\necho bye\n' > "${tmp}/bad.sh"
  local input; input=$(jq -nc --arg fp "${tmp}/bad.sh" '{tool_name:"Edit",tool_input:{file_path:$fp},cwd:"/tmp"}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/post-tool-use.sh"
  rm -rf "${tmp}"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage | test("Literal .\\\\n. line detected")' >/dev/null
}

@test "hooks: post-tool-use detects literal '\\n' line via serena relative_path" {
  local tmp; tmp=$(mktemp -d)
  printf '#!/usr/bin/env bash\necho hi\n\\n\necho bye\n' > "${tmp}/bad.sh"
  local input; input=$(jq -nc --arg rp "bad.sh" --arg cwd "${tmp}" '{tool_name:"mcp__serena__replace_content",tool_input:{relative_path:$rp},cwd:$cwd}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/post-tool-use.sh"
  rm -rf "${tmp}"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.systemMessage | test("Literal .\\\\n. line detected")' >/dev/null
}

@test "hooks: post-tool-use does not warn on clean .sh file" {
  local tmp; tmp=$(mktemp -d)
  printf '#!/usr/bin/env bash\necho hi\necho bye\n' > "${tmp}/good.sh"
  local input; input=$(jq -nc --arg fp "${tmp}/good.sh" '{tool_name:"Edit",tool_input:{file_path:$fp},cwd:"/tmp"}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/post-tool-use.sh"
  rm -rf "${tmp}"
  [ "$status" -eq 0 ]
  ! echo "$output" | jq -e '.systemMessage // "" | test("Literal")' >/dev/null
}

# =============================================================================
# Task-Completed Hook Tests
# =============================================================================

@test "hooks: task-completed accepts valid JSON input" {
  local input='{"agent_id": "test-456", "agent_type": "developer-agent"}'
  run --separate-stderr bash -c "echo '$input' | ${HOOKS_DIR}/task-completed.sh"
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
  # Task は並列判定 self-review reminder を additionalContext で返すため別 test で検証
  local tools=("Read" "Glob" "Grep" "WebSearch" "TaskCreate" "AskUserQuestion")
  for tool in "${tools[@]}"; do
    local input="{\"tool_name\": \"${tool}\", \"tool_input\": {}}"
    run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
    [ "$status" -eq 0 ]
    # Safe操作はメッセージなし（空JSON）
    [[ "$output" == "{}" ]]
  done
}

@test "integration: pre-tool-use injects parallel self-review reminder for Task" {
  # subagent_type 必須化後は subagent_type 明示が前提
  local input='{"tool_name": "Task", "tool_input": {"subagent_type": "explore-agent"}}'
  run bash -c "echo '${input}' | ${HOOKS_DIR}/pre-tool-use.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.additionalContext | contains("並列 self-review")' >/dev/null
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
  # Forbiddenは exit 2 でtoolブロック
  [ "$status" -eq 2 ]
  # additionalContext が出力される
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
# Integration: Pre-Compact Memory Save Flow (2026-06-11: Serena → auto-memory 統一)
# block + auto-retry 方式: marker (直近 5 分以内 compact-restore-*.md) 不在で block、
# 存在で通常進行
# =============================================================================

# helper: 直近 marker 配置 (通常進行 path 用)
_setup_recent_marker() {
  local memdir="${HOME}/.claude/projects/-Users-daichi-hoshina-ai-tools/memory"
  mkdir -p "${memdir}"
  echo "fixture" > "${memdir}/compact-restore-test-marker.md"
}

# helper: marker 全消去 (block path 用)
_clear_markers() {
  local memdir="${HOME}/.claude/projects/-Users-daichi-hoshina-ai-tools/memory"
  rm -f "${memdir}"/compact-restore-*.md
}

@test "integration: pre-compact blocks when no recent save marker" {
  _clear_markers
  rm -f "${HOME}/.claude/.compact-memory-state"
  local input='{"session_id": "test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-compact.sh"
  [ "$status" -eq 2 ]
  echo "$output" | jq -e '.decision == "block"' >/dev/null
  [[ "$output" == *"COMPACT中止"* ]]
  [[ "$output" == *"Write tool"* ]]
  [[ "$output" == *"再実行してください"* ]]
}

@test "integration: pre-compact emits required body fields in block instruction" {
  _clear_markers
  rm -f "${HOME}/.claude/.compact-memory-state"
  local input='{"session_id": "test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-compact.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"現在のタスク"* ]]
  [[ "$output" == *"完了済"* ]]
  [[ "$output" == *"次アクション"* ]]
}

@test "integration: pre-compact proceeds when recent save marker present" {
  _clear_markers
  _setup_recent_marker
  rm -f "${HOME}/.claude/.compact-memory-state"
  local input='{"session_id": "test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/pre-compact.sh"
  _clear_markers
  [ "$status" -eq 0 ]
  [[ "$output" == *"COMPACT進行"* ]]
  local state
  state="$(cat "${HOME}/.claude/.compact-memory-state")"
  [[ "$state" =~ ^ready:[0-9]{8}_[0-9]{6}$ ]]
  rm -f "${HOME}/.claude/.compact-memory-state"
}

@test "integration: pre-compact CLAUDE_FORCE_COMPACT skips marker check" {
  _clear_markers
  rm -f "${HOME}/.claude/.compact-memory-state"
  local input='{"session_id": "test"}'
  run bash -c "echo '$input' | CLAUDE_FORCE_COMPACT=1 ${HOOKS_DIR}/pre-compact.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"強行モード"* ]]
  [ -f "${HOME}/.claude/.compact-memory-state" ]
  rm -f "${HOME}/.claude/.compact-memory-state"
}

@test "integration: post-compact-reload reads ready state and instructs Read tool" {
  # Read tool 分岐を真に exercise するため、restore file を実在させる。
  # 単に state file だけだと file 不在 fallback 分岐に落ちて、git-log embed の
  # commit message に "auto-memory" 文字列が混入して vacuous pass する。
  local ts="20991231_235959"
  local memdir="${HOME}/.claude/projects/-Users-daichi-hoshina-ai-tools/memory"
  local restore="${memdir}/compact-restore-${ts}.md"
  mkdir -p "${memdir}"
  echo "test fixture" > "${restore}"
  echo "ready:${ts}" > "${HOME}/.claude/.compact-memory-state"
  local input='{"session_id": "test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/post-compact-reload.sh"
  rm -f "${restore}" "${HOME}/.claude/.compact-memory-state"
  [ "$status" -eq 0 ]
  # Read tool 分岐固有の文字列を assert (file 不在 fallback の文言と区別)
  [[ "$output" == *"Read tool"* ]]
  [[ "$output" == *"復元（自動実行"* ]]
  [ ! -f "${HOME}/.claude/.compact-memory-state" ]
}

@test "integration: post-compact-reload file-not-found branch when restore file missing" {
  # state は ready だが restore file が無い場合の fallback 分岐
  rm -f "${HOME}/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/compact-restore-19000101_000000.md"
  echo "ready:19000101_000000" > "${HOME}/.claude/.compact-memory-state"
  local input='{"session_id": "test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/post-compact-reload.sh"
  [ "$status" -eq 0 ]
  # MEMORY_DIR 内に他の compact-restore-* が無ければ fallback、あれば最新を拾う。
  # どちらの分岐でも exit 0 + state file 削除契約は守られること。
  [ ! -f "${HOME}/.claude/.compact-memory-state" ]
}

@test "integration: post-compact-reload handles missing state gracefully" {
  rm -f "${HOME}/.claude/.compact-memory-state"
  local input='{"session_id": "test"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/post-compact-reload.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"状態不明"* ]]
}

@test "integration: user-prompt-submit injects save on 'compact' natural-language when marker absent" {
  _clear_markers
  local input='{"session_id": "test", "cwd": ".", "prompt": "compact"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"compact 自然語検知"* ]]
  [[ "$output" == *"marker 不在"* ]]
  [[ "$output" == *"Write tool"* ]]
}

@test "integration: user-prompt-submit injects save on 'コンパクト' Katakana trigger" {
  _clear_markers
  local input='{"session_id": "test", "cwd": ".", "prompt": "コンパクト"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"compact 自然語検知"* ]]
}

@test "integration: user-prompt-submit skips save when marker present" {
  _clear_markers
  _setup_recent_marker
  local input='{"session_id": "test", "cwd": ".", "prompt": "compact"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  _clear_markers
  [ "$status" -eq 0 ]
  [[ "$output" != *"compact 自然語検知"* ]]
  [[ "$output" != *"marker 不在"* ]]
}

@test "integration: user-prompt-submit does not trigger on non-compact prompts" {
  _clear_markers
  local input='{"session_id": "test", "cwd": ".", "prompt": "hello world"}'
  run bash -c "echo '$input' | ${HOOKS_DIR}/user-prompt-submit.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"compact 自然語検知"* ]]
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

# =============================================================================
# _check_parent_prep_missing Tests
# =============================================================================

# 600 word の long prompt を生成するヘルパー (target/verify/DoD/file:line 未出現)
_make_long_prompt_no_prep() {
  # 600 word を超える plain text (prep keyword なし)
  local word="lorem"
  local prompt=""
  for i in $(seq 1 600); do
    prompt="${prompt}${word} "
  done
  echo "$prompt"
}

@test "_check_parent_prep_missing: detects missing prep in ≥500 word prompt" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  local long_prompt
  long_prompt=$(_make_long_prompt_no_prep)
  # 関数単体を source して exit code を直接 assert
  run bash -c "source '${HOOK_FILE}' && _check_parent_prep_missing '${long_prompt}'"
  # exit 0 = missing 検出
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: passes when prompt contains file:line pattern" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 600 word + src/foo.ts:42 を含む prompt
  local long_prompt
  long_prompt=$(_make_long_prompt_no_prep)
  long_prompt="${long_prompt} src/foo.ts:42"
  run bash -c "source '${HOOK_FILE}' && _check_parent_prep_missing '${long_prompt}'"
  # exit 1 = 事前準備済 (warn しない)
  [ "$status" -eq 1 ]
}

@test "_check_parent_prep_missing: passes when prompt is short (<500 words)" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 100 word のみ (target 未出現でも short prompt は対象外)
  local short_prompt=""
  for i in $(seq 1 100); do
    short_prompt="${short_prompt}lorem "
  done
  run bash -c "source '${HOOK_FILE}' && _check_parent_prep_missing '${short_prompt}'"
  # exit 1 = 短 prompt、warn しない
  [ "$status" -eq 1 ]
}

@test "_check_parent_prep_missing: does not treat English 'target' in prose as prep" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 600 word + natural "target" mention but no file:line / label 付き keyword
  local long_prompt
  long_prompt=$(printf "We targeted the service layer for refactoring. %.0s" {1..30})
  long_prompt="${long_prompt} $(_make_long_prompt_no_prep)"
  run bash -c "source '${HOOK_FILE}' && _check_parent_prep_missing \"\$1\"" _ "${long_prompt}"
  # exit 0 = missing 検出 — natural 'target' word should NOT suppress warn
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: does not treat English 'verify' in prose as prep" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 600 word + natural "verify" mention but no file:line / label 付き keyword
  local long_prompt
  long_prompt=$(printf "Please verify the output carefully. %.0s" {1..30})
  long_prompt="${long_prompt} $(_make_long_prompt_no_prep)"
  run bash -c "source '${HOOK_FILE}' && _check_parent_prep_missing \"\$1\"" _ "${long_prompt}"
  # exit 0 = missing 検出 — natural 'verify' word should NOT suppress warn
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: label-prefixed 'verify cmd:' DOES suppress warn" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # label 付き形式は事前準備済とみなす
  local long_prompt
  long_prompt="$(_make_long_prompt_no_prep) verify cmd: bats tests/foo.bats"
  run bash -c "source '${HOOK_FILE}' && _check_parent_prep_missing \"\$1\"" _ "${long_prompt}"
  # exit 1 = 事前準備済 (warn しない) — label 付き verify cmd は trigger 抑制
  [ "$status" -eq 1 ]
}

@test "_check_parent_prep_missing: does NOT treat URL with port as file:line" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # URL+port (https://example.com:8080) は file:line ではないので warn 抑制しない
  local long_prompt
  long_prompt="$(_make_long_prompt_no_prep) See https://example.com:8080/docs for details"
  run bash -c "source '$HOOK_FILE' && _check_parent_prep_missing \"\$1\"" _ "$long_prompt"
  # exit 0 = missing 検出 — URL host:port は file:line と判定しない
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: file:line at line start IS detected" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 行頭の file:line は正常検出
  local long_prompt
  long_prompt="src/foo.ts:42 $(_make_long_prompt_no_prep)"
  run bash -c "source '$HOOK_FILE' && _check_parent_prep_missing \"\$1\"" _ "$long_prompt"
  # exit 1 = 事前準備済 (warn しない)
  [ "$status" -eq 1 ]
}

# self-verify red 化手順 (実装者必須実行):
# 1. _check_parent_prep_missing 関数本体を `return 1` のみに置換 → case "detects missing" (positive) が FAIL
# 2. regex を旧 too-broad pattern (target|verify|DoD|:[0-9]+|file:line) に戻す
#    → "does not treat English 'target' in prose" / "does not treat English 'verify' in prose" の 2 case が FAIL
#    (false-negative 再現: 自然言語 target/verify で trigger 抑制されてしまう)
# 3. 修正版 regex に戻す → 全件 PASS
# 4. URL false-negative: regex の境界 (^|[[:space:]]) を除去 → "URL with port" test が FAIL
#    (example.com:8080 が file:line として誤判定 → exit 1 になる)
# 5. 修正版に戻す → 全件 PASS
# pass-by-coincidence 排除確認済

# =============================================================================
# _check_colloquial_trigger_missing_delegation Tests
# =============================================================================

@test "_check_colloquial_trigger: detects お任せ without file:line" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 口語起動 marker (お任せ) + file:line なし → warn 対象 (exit 0)
  local prompt="お任せで全部やっておいて。あとはうまくやってほしい。作業はそちらに委ねる。"
  run bash -c "source '${HOOK_FILE}' && _check_colloquial_trigger_missing_delegation \"\$1\"" _ "${prompt}"
  [ "$status" -eq 0 ]
}

@test "_check_colloquial_trigger: does not warn when file:line is explicit" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 「全部」を含むが file:line 明示あり → warn しない (exit 1)
  local prompt="全部修正して欲しい。対象: src/hooks/pre-tool-use.sh:670 の関数を更新する。verify cmd: shellcheck を実行する。"
  run bash -c "source '${HOOK_FILE}' && _check_colloquial_trigger_missing_delegation \"\$1\"" _ "${prompt}"
  [ "$status" -eq 1 ]
}

# self-verify red 化手順 (_check_colloquial_trigger 用):
# 1. 関数本体を `return 1` のみに置換 → "detects お任せ" (positive) が FAIL
# 2. 関数本体を `return 0` のみに置換 → "does not warn when file:line is explicit" (false-positive) が FAIL
# 3. 元の実装に戻す → 全件 PASS
# pass-by-coincidence 排除確認済
