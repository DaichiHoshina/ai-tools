#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — tool classification
# Safe / Boundary / Forbidden 分類 (Read/Glob/Grep/Edit/Write/Bash 等)
# 分割元: tests/unit/hooks/pre-tool-use.bats
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

_DEFAULT_INPUT="{}"

run_hook() {
  invoke_hook "$1" "${2:-$_DEFAULT_INPUT}"
}

# Forbidden 系（exit 2 で hook がブロックする）の Bash コマンド実行
# bats `run` を使って exit code をキャプチャ。$status と $output が利用可能
_run_bash_forbidden() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{command:$c}')
  invoke_hook_run "Bash" "$input"
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

@test "pre-tool-use: Task はSafe (並列 self-review inject あり)" {
  # subagent_type 必須化後は explore-agent など明示が前提
  # PARALLEL_REVIEW は session 1 回のみ inject (flag: /tmp/claude-parallel-review-<key>-<date>)。
  # 他 test との flag 衝突を避けるため test 固有 session_id を使い、実行後に flag を消す。
  local input session_id flag_file today
  session_id="test-parallel-review-$$"
  input=$(jq -n --arg sid "$session_id" '{session_id:$sid, tool_name:"Task", tool_input:{subagent_type:"explore-agent", prompt:"x"}}')
  today=$(date +%Y%m%d)
  flag_file="/tmp/claude-parallel-review-${session_id}-${today}"
  rm -f "$flag_file"
  result=$(echo "$input" | CLAUDE_CODE_SESSION_ID="$session_id" bash "$HOOK_FILE")
  rm -f "$flag_file"
  echo "$result" | grep -q "並列 self-review"
}

@test "pre-tool-use: Task subagent_type=general-purpose は Forbidden (exit 2 block)" {
  local input
  input=$(jq -n '{tool_name:"Task", tool_input:{subagent_type:"general-purpose", prompt:"x"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
}

@test "pre-tool-use: Task subagent_type=explore-agent は Safe (exit 0)" {
  local input
  input=$(jq -n '{tool_name:"Task", tool_input:{subagent_type:"explore-agent", prompt:"x"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 0 ]
}

@test "pre-tool-use: GP_BLOCK_OFF=1 で general-purpose は warn 据え置き (exit 0)" {
  local input
  input=$(jq -n '{tool_name:"Task", tool_input:{subagent_type:"general-purpose", prompt:"x"}}')
  run bash -c 'echo "$1" | GP_BLOCK_OFF=1 bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 0 ]
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

@test "pre-tool-use: Edit はBoundary (静的 message なし)" {
  # 毎 Edit 発火の header message は noise として削除済 (下流 check が必要時のみ context を積む)
  result=$(run_hook "Edit")
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: Write はBoundary (静的 message なし)" {
  result=$(run_hook "Write")
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: MultiEdit はBoundary (静的 message なし)" {
  result=$(run_hook "MultiEdit")
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

# =============================================================================
# Serena MCP変更系テスト（Boundary）
# =============================================================================

@test "pre-tool-use: mcp__serena__create_text_file はBoundary (静的 message なし)" {
  result=$(run_hook "mcp__serena__create_text_file")
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: mcp__serena__replace_regex はBoundary (静的 message なし)" {
  result=$(run_hook "mcp__serena__replace_regex")
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: mcp__serena__execute_shell_command はBoundary (静的 message なし)" {
  result=$(run_hook "mcp__serena__execute_shell_command")
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: mcp__serena__write_memory はBoundary (静的 message なし)" {
  result=$(run_hook "mcp__serena__write_memory")
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
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

@test "pre-tool-use: Bash cat はSafe (block されない)" {
  local input
  input=$(jq -n '{tool_name:"Bash", tool_input:{command:"cat file.txt"}}')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  # exit 2 (Forbidden block) にならないことを確認
  [ "$status" -ne 2 ]
}

# =============================================================================
# Bash 変更系コマンド（Boundary）
# =============================================================================

@test "pre-tool-use: Bash git commit はBoundary (静的 message なし)" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"test\""}')
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: Bash git push はBoundary (静的 message なし)" {
  result=$(run_hook "Bash" '{"command": "git push origin main"}')
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: Bash npm install はBoundary (静的 message なし)" {
  result=$(run_hook "Bash" '{"command": "npm install express"}')
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
}

@test "pre-tool-use: Bash docker build はBoundary (静的 message なし)" {
  result=$(run_hook "Bash" '{"command": "docker build -t myapp ."}')
  msg=$(get_system_message "$result")
  [ -z "$msg" ]
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
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
}

@test "pre-tool-use: commit message 内の危険語リテラル（rm -rf）は Forbidden ではなく Boundary" {
  result=$(run_hook "Bash" '{"command": "git commit -m \"rm -rf を禁止\""}')
  msg=$(get_system_message "$result")
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
}

@test "pre-tool-use: commit message single quote 内の危険語は Forbidden ではなく Boundary" {
  result=$(run_hook "Bash" "{\"command\": \"git commit -m 'git push --force を防止'\"}")
  msg=$(get_system_message "$result")
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
}

@test "pre-tool-use: commit message -F file 形式は引数値を除外" {
  result=$(run_hook "Bash" '{"command": "git commit -F /tmp/git-push-force-msg.txt"}')
  msg=$(get_system_message "$result")
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
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
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
}

@test "pre-tool-use: HEREDOC 内の git push --force リテラルは Boundary" {
  local cmd
  cmd=$'git commit -m "$(cat <<EOF\ngit push --force を禁止\nEOF\n)"'
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  msg=$(get_system_message "$result")
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
}

@test "pre-tool-use: <<-DELIM (タブ削減) ヒアドキュメント本文も除去" {
  # <<- は終端マーカー先頭のタブを許容
  local cmd
  cmd=$'git commit -m "$(cat <<-EOF\n\trm -rf / を語る\n\tEOF\n)"'
  local input
  input=$(jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input:{command:$c}}')
  result=$(echo "$input" | bash "$HOOK_FILE")
  msg=$(get_system_message "$result")
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
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
  # 変更系 Boundary は静的 message なし。禁止 (Forbidden) 昇格していないことだけ確認
  [ -z "$msg" ]
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

@test "pre-tool-use: Forbidden時に block 理由が stderr にも出る" {
  local input
  input=$(jq -n --arg c "rm -rf /" '{command:$c}')
  invoke_hook_run_merged "Bash" "$input"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "禁止" ]]
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

@test "pre-tool-use: 未知ツールはBoundary (message なし、log に記録)" {
  # systemMessage は出さず、drift 検出用に hook-info.log へ tool 名を残す
  result=$(run_hook "UnknownTool123")
  [ "$result" = "{}" ]
}

# =============================================================================
# エッジケース
# =============================================================================

@test "pre-tool-use: Bashコマンドにパイプがある場合はBoundary (message なし)" {
  # fallback Boundary は systemMessage を出さない (noise 削減で MESSAGE を削除済)
  result=$(run_hook "Bash" '{"command": "git status | grep modified"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bashコマンドにセミコロンがある場合はBoundary (message なし)" {
  # セミコロン付きはSafe判定から除外されるが、fallback Boundary は message を出さない
  result=$(run_hook "Bash" '{"command": "ls ; echo done"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash git branch はSafe" {
  result=$(run_hook "Bash" '{"command": "git branch -a"}')
  [ "$result" = "{}" ]
}

@test "pre-tool-use: Bash which はSafe" {
  result=$(run_hook "Bash" '{"command": "which node"}')
  [ "$result" = "{}" ]
}
