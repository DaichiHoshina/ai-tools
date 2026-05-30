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

@test "pre-tool-use: commit message single quote 内の危険語は Forbidden ではなく Boundary" {
  result=$(run_hook "Bash" "{\"command\": \"git commit -m 'git push --force を防止'\"}")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: commit message -F file 形式は引数値を除外" {
  result=$(run_hook "Bash" '{"command": "git commit -F /tmp/git-push-force-msg.txt"}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

# =============================================================================
# HEREDOC 本文除去テスト（v2.2.3）
# git commit -m "$(cat <<'EOF' ... EOF)" 形式の commit message 内危険語誤発火防止
# =============================================================================

@test "pre-tool-use: HEREDOC 内の rm -rf / リテラル（git commit）は Boundary" {
  local cmd
  cmd=$'git commit -m "$(cat <<\'EOF\'\nrm -rf / を防止する\nEOF\n)"'
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: HEREDOC 内の git push --force リテラルは Boundary" {
  local cmd
  cmd=$'git commit -m "$(cat <<EOF\ngit push --force を禁止\nEOF\n)"'
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: <<-DELIM (タブ削減) ヒアドキュメント本文も除去" {
  # <<- は終端マーカー先頭のタブを許容
  local cmd
  cmd=$'git commit -m "$(cat <<-EOF\n\trm -rf / を語る\n\tEOF\n)"'
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: HEREDOC 終端後の rm -rf / は Forbidden（除去対象外）" {
  # HEREDOC 本文除去はマーカー～終端行のみ。終端後の本物の危険コマンドは検出継続
  local cmd
  cmd=$'cat <<EOF > /tmp/x\nbody\nEOF\nrm -rf /'
  _run_bash_forbidden "$cmd"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: 引用符付きマーカー <<\"DELIM\" の本文除去" {
  local cmd
  cmd=$'git commit -m "$(cat <<"EOF"\nrm -rf / 注意喚起\nEOF\n)"'
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "禁止" ]]
}

@test "pre-tool-use: commit 以外で git push --force は引き続き Forbidden" {
  _run_bash_forbidden "git push --force origin main"
  [ "$status" -eq 2 ]
  msg=$(get_system_message "$output")
  [[ "$msg" =~ "禁止" ]]
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

# =============================================================================
# 難読漢語 block テスト
# =============================================================================

_run_bash_jargon() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
}

@test "pre-tool-use: 難読漢語 commit message は block (exit 2)" {
  _run_bash_jargon 'git commit -m "鑑みると修正する"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
  [[ "$output" =~ "鑑みる" ]]
}

@test "pre-tool-use: 難読漢語 喫緊 commit message は block" {
  _run_bash_jargon 'git commit -m "喫緊の課題を修正"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

@test "pre-tool-use: 難読漢語 踏襲 commit message は block" {
  _run_bash_jargon 'git commit -m "既存方針を踏襲する"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "難読漢語 block" ]]
}

# =============================================================================
# 非日常英語 block テスト
# =============================================================================

@test "pre-tool-use: 非日常英語 leverage commit message は block (exit 2)" {
  _run_bash_jargon 'git commit -m "leverage existing infra"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]]
  [[ "$output" =~ "leverage" ]]
}

@test "pre-tool-use: 非日常英語 utilize commit message は block" {
  _run_bash_jargon 'git commit -m "utilize the cache layer"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]]
}

@test "pre-tool-use: 非日常英語 mitigate commit message は block" {
  _run_bash_jargon 'git commit -m "mitigate performance degradation"'
  [ "$status" -eq 2 ]
  [[ "$output" =~ "非日常英語 block" ]]
}

# =============================================================================
# 中間漢語 regression テスト (block されないこと)
# =============================================================================

@test "pre-tool-use: 中間漢語 網羅 commit message は block されない" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"網羅的に整合性を担保\""}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "難読漢語" ]]
  [[ ! "$msg" =~ "非日常英語" ]]
}

@test "pre-tool-use: 中間漢語 整合 担保 是正 commit message は block されない" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"整合性担保と是正\""}')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "要確認" ]]
  [[ ! "$msg" =~ "難読漢語" ]]
}

# =============================================================================
# 今日の commit inject テスト
# _inject_today_commits: 書く系 tool で additionalContext に今日の commit を inject する
# =============================================================================

# テスト用 git stub: 固定 commit log を出力してパス優先で差し替える
_setup_git_stub() {
  local stub_dir="$TEST_TMPDIR/bin"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/git" <<'STUB'
#!/usr/bin/env bash
# パターン: git -C <dir> log --since=... の場合のみ stub 出力
if [[ "$*" =~ "log" ]] && [[ "$*" =~ "since" ]]; then
  printf 'abc1234 feat: writing 規約更新\ndef5678 fix: hook 修正'
  exit 0
fi
# それ以外は本物の git を呼ぶ
exec /usr/bin/git "$@"
STUB
  chmod +x "$stub_dir/git"
  export _ORIG_PATH="$PATH"
  export PATH="$stub_dir:$PATH"
}

_teardown_git_stub() {
  export PATH="${_ORIG_PATH:-$PATH}"
}

@test "today-commit-inject: git commit Bash で additionalContext に今日の commit が出る" {
  _setup_git_stub
  # session 重複フラグをクリア（$$が変わるので通常不要だが念のため）
  rm -f /tmp/claude-today-commits-* 2>/dev/null || true

  result=$(run_hook "Bash" '{"command": "git commit -m \"test fix\""}')
  _teardown_git_stub

  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "今日の commit" ]]
  [[ "$ctx" =~ "writing 規約" ]]
}

@test "today-commit-inject: Read tool では inject されない" {
  _setup_git_stub
  rm -f /tmp/claude-today-commits-* 2>/dev/null || true

  result=$(run_hook "Read")
  _teardown_git_stub

  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "今日の commit" ]]
}

@test "today-commit-inject: Slack tool で inject される" {
  _setup_git_stub
  rm -f /tmp/claude-today-commits-* 2>/dev/null || true

  result=$(run_hook "mcp__claude_ai_Slack__slack_send_message")
  _teardown_git_stub

  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "今日の commit" ]]
}

@test "today-commit-inject: Write tool で inject される" {
  _setup_git_stub
  rm -f /tmp/claude-today-commits-* 2>/dev/null || true

  result=$(run_hook "Write" '{"file_path": "/tmp/test.md", "content": "hello"}')
  _teardown_git_stub

  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "今日の commit" ]]
}

@test "today-commit-inject: git log 0件の時は inject されない" {
  # stub: 常に空を返す git
  local stub_dir="$TEST_TMPDIR/bin_empty"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/git" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" =~ "log" ]] && [[ "$*" =~ "since" ]]; then
  exit 0
fi
exec /usr/bin/git "$@"
STUB
  chmod +x "$stub_dir/git"
  local _orig="$PATH"
  export PATH="$stub_dir:$PATH"
  rm -f /tmp/claude-today-commits-* 2>/dev/null || true

  result=$(run_hook "Bash" '{"command": "git commit -m \"empty day\""}')
  export PATH="$_orig"

  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "今日の commit" ]]
}

@test "today-commit-inject: gh pr create Bash で inject される" {
  _setup_git_stub
  rm -f /tmp/claude-today-commits-* 2>/dev/null || true

  result=$(run_hook "Bash" '{"command": "gh pr create --title \"feat\" --body \"desc\""}')
  _teardown_git_stub

  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "今日の commit" ]]
}

# =============================================================================
# inject byte size log テスト
# _append_jp_quality_inject_log: 外向き text block/warn 判定直前に byte 数を記録する
# =============================================================================

# =============================================================================
# _inject_today_commits 追加テスト (C1/C2/W1/W2/F5 修正検証)
# =============================================================================

# session_id 付き run_hook ヘルパー
# CLAUDE_CODE_SESSION_ID を unset して stdin の session_id を優先させる
_run_hook_with_session() {
  local tool_name="$1"
  local tool_input="${2:-$_DEFAULT_INPUT}"
  local session_id="${3:-test-session-$$}"
  local input
  input=$(jq -n \
    --arg name "$tool_name" \
    --argjson inp "$tool_input" \
    --arg sid "$session_id" \
    '{tool_name: $name, tool_input: $inp, session_id: $sid}')
  echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "$HOOK_FILE"
}

# git stub セットアップ (project dir と ai-tools dir 両方に対応)
_setup_git_stub_dual() {
  local stub_dir="${TEST_TMPDIR}/bin_dual"
  mkdir -p "$stub_dir"
  cat > "$stub_dir/git" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" =~ "log" ]] && [[ "$*" =~ "since" ]]; then
  printf 'abc1234 feat: writing 規約更新\ndef5678 fix: hook 修正'
  exit 0
fi
exec /usr/bin/git "$@"
STUB
  chmod +x "$stub_dir/git"
  export _DUAL_ORIG_PATH="$PATH"
  export PATH="$stub_dir:$PATH"
}

_teardown_git_stub_dual() {
  export PATH="${_DUAL_ORIG_PATH:-$PATH}"
}

@test "today-commit-inject: 同一 session_id で 2 回起動すると 2 回目は inject なし (C1)" {
  _setup_git_stub_dual
  local sid="dedup-test-session-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result1
  result1=$(_run_hook_with_session "Write" '{"file_path":"/tmp/x.md","content":"y"}' "$sid")
  local result2
  result2=$(_run_hook_with_session "Write" '{"file_path":"/tmp/x.md","content":"y"}' "$sid")

  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  # 1回目: inject あり
  [[ "$(get_additional_context "$result1")" =~ "今日の commit" ]]
  # 2回目: inject なし (session 重複抑制)
  local ctx2
  ctx2=$(get_additional_context "$result2")
  [[ ! "$ctx2" =~ "今日の commit" ]] || [[ "$ctx2" =~ "投稿前自問" ]]
  # additionalContext に今日の commit 文字列がないことを確認
  [[ ! "$(echo "$result2" | jq -r '.additionalContext // empty')" =~ "今日の commit" ]]
}

@test "today-commit-inject: Edit tool で inject される (Write と別確認)" {
  _setup_git_stub_dual
  local sid="edit-inject-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Edit" \
    '{"file_path":"/tmp/x.sh","old_string":"foo","new_string":"bar"}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ "$(get_additional_context "$result")" =~ "今日の commit" ]]
}

@test "today-commit-inject: Notion tool で inject される (Slack と別確認)" {
  _setup_git_stub_dual
  local sid="notion-inject-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "mcp__claude_ai_Notion__notion-create-pages" '{}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ "$(get_additional_context "$result")" =~ "今日の commit" ]]
}

@test "today-commit-inject: git commit-tree で inject されない (W1 regex anchor)" {
  _setup_git_stub_dual
  local sid="commit-tree-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Bash" '{"command":"git commit-tree abc123 -m msg"}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ ! "$(echo "$result" | jq -r '.additionalContext // empty')" =~ "今日の commit" ]]
}

@test "today-commit-inject: gh issue list で inject されない" {
  _setup_git_stub_dual
  local sid="gh-list-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Bash" '{"command":"gh issue list"}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ ! "$(echo "$result" | jq -r '.additionalContext // empty')" =~ "今日の commit" ]]
}

@test "today-commit-inject: gh pr review --body で inject される (W2)" {
  _setup_git_stub_dual
  local sid="gh-pr-review-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Bash" \
    '{"command":"gh pr review 42 --body \"LGTM\""}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ "$(get_additional_context "$result")" =~ "今日の commit" ]]
}

@test "today-commit-inject: gh release create --notes で inject される (W2)" {
  _setup_git_stub_dual
  local sid="gh-release-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "Bash" \
    '{"command":"gh release create v1.0.0 --notes \"release notes\""}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ "$(get_additional_context "$result")" =~ "今日の commit" ]]
}

@test "today-commit-inject: slack_schedule_message で inject される (C2)" {
  _setup_git_stub_dual
  local sid="slack-sched-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "mcp__claude_ai_Slack__slack_schedule_message" '{}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ "$(get_additional_context "$result")" =~ "今日の commit" ]]
}

@test "today-commit-inject: slack_create_canvas で inject される (C2)" {
  _setup_git_stub_dual
  local sid="slack-canvas-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "mcp__claude_ai_Slack__slack_create_canvas" '{}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ "$(get_additional_context "$result")" =~ "今日の commit" ]]
}

@test "today-commit-inject: notion-create-database で inject される (C2)" {
  _setup_git_stub_dual
  local sid="notion-db-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  local result
  result=$(_run_hook_with_session "mcp__claude_ai_Notion__notion-create-database" '{}' "$sid")
  _teardown_git_stub_dual
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  [[ "$(get_additional_context "$result")" =~ "今日の commit" ]]
}

@test "today-commit-inject: flag ファイルに日付が含まれる (W5)" {
  _setup_git_stub_dual
  local sid="date-flag-$$"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true

  _run_hook_with_session "Write" '{"file_path":"/tmp/x.md","content":"y"}' "$sid" > /dev/null

  _teardown_git_stub_dual

  # フラグファイルに日付が含まれていること
  [[ -f "/tmp/claude-today-commits-${sid}-${today}" ]]
  rm -f "/tmp/claude-today-commits-${sid}-${today}" 2>/dev/null || true
}

# =============================================================================
# inject byte size log テスト
# _append_jp_quality_inject_log: 外向き text block/warn 判定直前に byte 数を記録する
# =============================================================================

@test "inject-log: commit message チェック時に jp-quality-inject.log が追記される" {
  local log_file="$HOME/.claude/logs/jp-quality-inject.log"
  local before_lines=0
  [[ -f "$log_file" ]] && before_lines=$(wc -l < "$log_file")

  # 難読漢語 block で _block_if_ai_jargon → inject log が書かれる
  local input
  input=$(jq -n --arg c 'git commit -m "鑑みると修正する"' \
    '{tool_name:"Bash", tool_input:{command:$c}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  # exit 2 (block) を期待するが、log 書き込みを確認するために status は問わない

  [[ -f "$log_file" ]]
  local after_lines
  after_lines=$(wc -l < "$log_file")
  [[ "$after_lines" -gt "$before_lines" ]]

  # 最終行に期待フォーマットが含まれること
  local last_line
  last_line=$(tail -1 "$log_file")
  [[ "$last_line" =~ "tool=commit message" ]]
  [[ "$last_line" =~ "bytes=" ]]
  [[ "$last_line" =~ "threshold=1500" ]]
  [[ "$last_line" =~ "status=" ]]
}
