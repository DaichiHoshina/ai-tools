#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh
# セキュリティ保護フックのユニットテスト
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  export TEST_TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# =============================================================================
# ヘルパー関数
# =============================================================================

# フックを実行してJSON出力を取得
run_hook() {
  local tool_name="$1"
  local tool_input="${2:-{}}"
  local input
  input=$(jq -n --arg name "$tool_name" --argjson inp "$tool_input" \
    '{tool_name: $name, tool_input: $inp}')
  echo "$input" | bash "$HOOK_FILE"
}

# JSON出力から systemMessage を抽出
get_system_message() {
  echo "$1" | jq -r '.systemMessage // empty'
}

# JSON出力から additionalContext を抽出
get_additional_context() {
  echo "$1" | jq -r '.additionalContext // empty'
}

# =============================================================================
# Safe操作テスト
# =============================================================================

@test "pre-tool-use: Read はSafe（空JSON出力）" {
  result=$(run_hook "Read")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Glob はSafe" {
  result=$(run_hook "Glob")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Grep はSafe" {
  result=$(run_hook "Grep")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: WebFetch はSafe" {
  result=$(run_hook "WebFetch")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: WebSearch はSafe" {
  result=$(run_hook "WebSearch")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Task はSafe" {
  result=$(run_hook "Task")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Skill はSafe" {
  result=$(run_hook "Skill")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: AskUserQuestion はSafe" {
  result=$(run_hook "AskUserQuestion")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: TaskCreate はSafe" {
  result=$(run_hook "TaskCreate")
  [ "$result" = "{}" ]
}

# =============================================================================
# Serena MCP読み取り系テスト（Safe）
# =============================================================================

@test "pre-tool-use: mcp__serena__read_file はSafe" {
  result=$(run_hook "mcp__serena__read_file")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: mcp__serena__list_dir はSafe" {
  result=$(run_hook "mcp__serena__list_dir")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: mcp__serena__find_symbol はSafe" {
  result=$(run_hook "mcp__serena__find_symbol")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: mcp__serena__search_for_pattern はSafe" {
  result=$(run_hook "mcp__serena__search_for_pattern")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: mcp__serena__list_memories はSafe" {
  result=$(run_hook "mcp__serena__list_memories")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: mcp__serena__think_about_collected_information はSafe" {
  result=$(run_hook "mcp__serena__think_about_collected_information")
  [ "$result" = "{}" ]
}

# =============================================================================
# Jira/Confluence読み取り系テスト（Safe）
# =============================================================================

@test "pre-tool-use: mcp__jira__jira_get はSafe" {
  result=$(run_hook "mcp__jira__jira_get")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: mcp__confluence__conf_get はSafe" {
  result=$(run_hook "mcp__confluence__conf_get")
  [ "$result" = "{}" ]
}

@test "pre-tool-use: mcp__context7__resolve-library-id はSafe" {
  result=$(run_hook "mcp__context7__resolve-library-id")
  [ "$result" = "{}" ]
}

# =============================================================================
# Boundary操作テスト
# =============================================================================

@test "pre-tool-use: Edit はBoundary（要確認メッセージ）" {
  result=$(run_hook "Edit")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Write はBoundary" {
  result=$(run_hook "Write")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: MultiEdit はBoundary" {
  result=$(run_hook "MultiEdit")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

# =============================================================================
# Serena MCP変更系テスト（Boundary）
# =============================================================================

@test "pre-tool-use: mcp__serena__create_text_file はBoundary" {
  result=$(run_hook "mcp__serena__create_text_file")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: mcp__serena__replace_regex はBoundary" {
  result=$(run_hook "mcp__serena__replace_regex")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: mcp__serena__execute_shell_command はBoundary" {
  result=$(run_hook "mcp__serena__execute_shell_command")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: mcp__serena__write_memory はBoundary" {
  result=$(run_hook "mcp__serena__write_memory")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

# =============================================================================
# Jira/Confluence変更系テスト（Boundary）
# =============================================================================

@test "pre-tool-use: mcp__jira__jira_post はBoundary" {
  result=$(run_hook "mcp__jira__jira_post")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: mcp__confluence__conf_delete はBoundary" {
  result=$(run_hook "mcp__confluence__conf_delete")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

# =============================================================================
# Bash コマンド分類テスト
# =============================================================================

@test "pre-tool-use: Bash git status はSafe" {
  result=$(run_hook "Bash" '{"command": "git status"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash git log はSafe" {
  result=$(run_hook "Bash" '{"command": "git log --oneline"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash git diff はSafe" {
  result=$(run_hook "Bash" '{"command": "git diff HEAD"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash ls はSafe" {
  result=$(run_hook "Bash" '{"command": "ls -la"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash pwd はSafe" {
  result=$(run_hook "Bash" '{"command": "pwd"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash echo はSafe" {
  result=$(run_hook "Bash" '{"command": "echo hello"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash cat はSafe" {
  result=$(run_hook "Bash" '{"command": "cat file.txt"}')
  [ "$result" = "{}" ]
}

# =============================================================================
# Bash 変更系コマンド（Boundary）
# =============================================================================

@test "pre-tool-use: Bash git commit はBoundary" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"test\""}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash git push はBoundary" {
  result=$(run_hook "Bash" '{"command": "git push origin main"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash npm install はBoundary" {
  result=$(run_hook "Bash" '{"command": "npm install express"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash docker build はBoundary" {
  result=$(run_hook "Bash" '{"command": "docker build -t myapp ."}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

# =============================================================================
# Bash 自動整形コマンド（Boundary）
# =============================================================================

@test "pre-tool-use: Bash npm run lint はBoundary（自動整形）" {
  result=$(run_hook "Bash" '{"command": "npm run lint"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash prettier はBoundary（自動整形）" {
  result=$(run_hook "Bash" '{"command": "prettier --write src/"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash eslint --fix はBoundary（自動整形）" {
  result=$(run_hook "Bash" '{"command": "eslint --fix src/"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash go fmt はBoundary（自動整形）" {
  result=$(run_hook "Bash" '{"command": "go fmt ./..."}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash black はBoundary（自動整形）" {
  result=$(run_hook "Bash" '{"command": "black src/main.py"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

# =============================================================================
# Forbidden操作テスト（破壊的コマンド）
# =============================================================================

@test "pre-tool-use: Bash rm -rf / はForbidden" {
  result=$(run_hook "Bash" '{"command": "rm -rf /"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash rm -rf * はForbidden" {
  result=$(run_hook "Bash" '{"command": "rm -rf *"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash git push --force はForbidden" {
  result=$(run_hook "Bash" '{"command": "git push --force origin main"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash git push -f はForbidden" {
  result=$(run_hook "Bash" '{"command": "git push -f origin main"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash sudo rm はForbidden" {
  result=$(run_hook "Bash" '{"command": "sudo rm -rf /var/log"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash fork bomb はForbidden" {
  result=$(run_hook "Bash" '{"command": ":(){ :|:& };:"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash > /dev/null リダイレクト はForbidden" {
  result=$(run_hook "Bash" '{"command": "> /dev/sda"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "禁止" ]]
}

# =============================================================================
# Forbidden時のadditionalContextテスト
# =============================================================================

@test "pre-tool-use: Forbidden時にadditionalContextが設定される" {
  result=$(run_hook "Bash" '{"command": "rm -rf /"}')
  ctx=$(get_additional_context "$result")
  [ -n "$ctx" ]
  [[ "$ctx" =~ "破壊的" ]]
}

@test "pre-tool-use: Safe時にadditionalContextは空" {
  result=$(run_hook "Read")
  ctx=$(get_additional_context "$result")
  [ -z "$ctx" ]
}

@test "pre-tool-use: Boundary(Edit)時にadditionalContextは空" {
  result=$(run_hook "Edit")
  ctx=$(get_additional_context "$result")
  [ -z "$ctx" ]
}

# =============================================================================
# 未知ツールテスト
# =============================================================================

@test "pre-tool-use: 未知ツールはBoundary" {
  result=$(run_hook "UnknownTool123")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ "$msg" =~ "未分類" ]]
}

# =============================================================================
# エッジケース
# =============================================================================

@test "pre-tool-use: Bashコマンドにパイプがある場合はBoundary" {
  result=$(run_hook "Bash" '{"command": "git status | grep modified"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bashコマンドにセミコロンがある場合はBoundary" {
  result=$(run_hook "Bash" '{"command": "ls ; rm -rf /tmp/test"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
}

@test "pre-tool-use: Bash git branch はSafe" {
  result=$(run_hook "Bash" '{"command": "git branch -a"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash which はSafe" {
  result=$(run_hook "Bash" '{"command": "which node"}')
  [ "$result" = "{}" ]
}
