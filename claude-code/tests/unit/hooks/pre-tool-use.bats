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
_DEFAULT_INPUT="{}"

run_hook() {
  local tool_name="$1"
  local tool_input="${2:-$_DEFAULT_INPUT}"
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

# Forbidden 系（exit 2 で hook がブロックする）の Bash コマンド実行
# bats `run` を使って exit code をキャプチャ。$status と $output が利用可能
_run_bash_forbidden() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
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
  _run_bash_forbidden "rm -rf /"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash rm -rf * はForbidden" {
  _run_bash_forbidden "rm -rf *"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash git push --force はForbidden" {
  _run_bash_forbidden "git push --force origin main"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash git push -f はForbidden" {
  _run_bash_forbidden "git push -f origin main"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash sudo rm はForbidden" {
  _run_bash_forbidden "sudo rm -rf /var/log"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash fork bomb はForbidden" {
  _run_bash_forbidden ":(){ :|:& };:"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: commit message 内の危険語リテラル（git push --force）は Forbidden ではなく Boundary" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"git push --force を防止する hook 修正\""}')
  msg=$(get_system_message "$result")
  # git commit は変更系（Boundary）。commit message 内の危険語は検出対象外になるため、禁止にはならない
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: commit message 内の危険語リテラル（rm -rf）は Forbidden ではなく Boundary" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"rm -rf を禁止\""}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: Bash > /dev/null リダイレクト はForbidden" {
  _run_bash_forbidden "> /dev/sda"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

# =============================================================================
# Forbidden時のadditionalContextテスト
# =============================================================================

@test "pre-tool-use: Forbidden時にadditionalContextが設定される" {
  _run_bash_forbidden "rm -rf /"
  [ "$status" -eq 2 ]
  ctx=$(get_additional_context "$output")
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
  # セミコロン付きはSafe判定から除外される（Forbiddenパターンを含まない例）
  result=$(run_hook "Bash" '{"command": "ls ; echo done"}')
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

# =============================================================================
# detect_dangerous_patterns（Edit/Write 内容検査）
# 機密リテラルは Forbidden 昇格→ exit 2、SSRF/SQL/credential は Boundary 警告
# 注: hook が検出するパターンを文字列として書くと自身の編集がブロックされるため、
#     リテラルは bash 連結 "AB""CD" で分割して書く
# =============================================================================

_run_edit_hook() {
  local file_path="$1"
  local content="$2"
  jq -n --arg fp "$file_path" --arg c "$content" \
    '{tool_name: "Edit", tool_input: {file_path: $fp, new_string: $c}}' \
    | bash "$HOOK_FILE"
}

_run_write_hook() {
  local file_path="$1"
  local content="$2"
  jq -n --arg fp "$file_path" --arg c "$content" \
    '{tool_name: "Write", tool_input: {file_path: $fp, content: $c}}' \
    | bash "$HOOK_FILE"
}

# bats run で hook 実行（exit 2 を捕捉するため）
_run_hook_blocking() {
  local file_path="$1"
  local content="$2"
  local input
  input=$(jq -n --arg fp "$file_path" --arg c "$content" \
    '{tool_name: "Edit", tool_input: {file_path: $fp, new_string: $c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
}

@test "detect_dangerous: 通常編集は警告なし" {
  result=$(_run_edit_hook "/tmp/x.txt" "hello world")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "ファイル編集" ]]
  [[ ! "$msg" =~ "機密情報" ]]
  [[ ! "$msg" =~ "危険パターン" ]]
}

@test "detect_dangerous: AWS Access Key リテラルは Forbidden（exit 2）" {
  local key="AKI""A0123456789ABCDEF"
  _run_hook_blocking "/tmp/x.py" "k=${key}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "AWS Access Key" ]]
  [[ "$output" =~ "機密情報" ]]
}

@test "detect_dangerous: GitHub PAT リテラルは Forbidden" {
  local pat="ghp""_abcdefghij1234567890ABCDEFGHIJ123456"
  _run_hook_blocking "/tmp/x.py" "t=${pat}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "GitHub PAT" ]]
}

@test "detect_dangerous: sk- API key リテラルは Forbidden" {
  local k="sk""-abcdefghij0123456789ABCDEFGHIJ0123456789ABCD"
  _run_hook_blocking "/tmp/x.py" "k=${k}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "sk-" ]]
}

@test "detect_dangerous: Slack token は Forbidden" {
  local t="xox""b-1234567890-abcdefghij1234567890"
  _run_hook_blocking "/tmp/x.py" "tok=${t}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Slack" ]]
}

@test "detect_dangerous: PRIVATE KEY block は Forbidden" {
  local pk_begin="-----BEGIN RSA PRIVATE"" KEY-----"
  local pk_end="-----END RSA PRIVATE"" KEY-----"
  _run_hook_blocking "/tmp/k" "${pk_begin}\\nMIIE\\n${pk_end}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Private key" ]]
}

@test "detect_dangerous: SSRF AWS metadata IP は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.py" "url = http://169.254.169.254/latest/meta-data/")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SSRF cloud metadata" ]]
}

@test "detect_dangerous: GCP metadata host は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.py" "u = http://metadata.google.internal/")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SSRF cloud metadata" ]]
}

@test "detect_dangerous: SQL f-string interpolation は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.py" 'q = f"SELECT * FROM users WHERE id={user_id}"')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SQL string interpolation" ]]
}

@test "detect_dangerous: SQL template literal は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.ts" 'q = "SELECT * FROM users WHERE id=${userId}"')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SQL template literal" ]]
}

@test "detect_dangerous: credential ハードコード代入は Boundary 警告" {
  result=$(_run_edit_hook "/tmp/x.py" 'api_key = "abcdefghij1234567890ABCDEF"')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "Hardcoded credential" ]]
}

@test "detect_dangerous: MultiEdit でも検出される" {
  local key="AKI""A0123456789ABCDEF"
  local input
  input=$(jq -n --arg k "$key" '{
    tool_name: "MultiEdit",
    tool_input: {
      file_path: "/tmp/x.py",
      edits: [{old_string: "x=1", new_string: ("x=" + $k)}]
    }
  }')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "AWS Access Key" ]]
}
