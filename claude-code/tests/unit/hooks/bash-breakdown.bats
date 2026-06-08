#!/usr/bin/env bats
# =============================================================================
# BATS Tests for post-tool-use.sh Bash command breakdown logic
# bash-breakdown.tsv への先頭 token 記録を検証する
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export HOOK_FILE="${PROJECT_ROOT}/hooks/post-tool-use.sh"
  export TEST_TMPDIR="$(mktemp -d)"
  # HOME を上書きして ~/.claude/logs を tmp に向ける
  export ORIG_HOME="$HOME"
  export HOME="$TEST_TMPDIR"
  export BREAKDOWN_TSV="${TEST_TMPDIR}/.claude/logs/bash-breakdown.tsv"
}

teardown() {
  export HOME="$ORIG_HOME"
  rm -rf "$TEST_TMPDIR"
}

# ヘルパー: Bash tool event JSON を生成してフックを実行
_run_bash_event() {
  local cmd="$1"
  local input
  input=$(jq -n --arg c "$cmd" '{
    tool_name: "Bash",
    tool_input: {command: $c},
    session_id: "test-session-001",
    cwd: "/tmp",
    tool_response: {stdout: "", duration_ms: 100}
  }')
  echo "$input" | bash "$HOOK_FILE"
}

# ヘルパー: 非 Bash tool event JSON を生成してフックを実行
_run_non_bash_event() {
  local tool_name="$1"
  local input
  input=$(jq -n --arg t "$tool_name" '{
    tool_name: $t,
    tool_input: {file_path: "/tmp/test.txt"},
    session_id: "test-session-001",
    cwd: "/tmp",
    tool_response: {stdout: "", duration_ms: 50}
  }')
  echo "$input" | bash "$HOOK_FILE"
}

# =============================================================================
# tsv append テスト
# =============================================================================

@test "bash-breakdown: git コマンドで tsv 行が 1 行 append される" {
  [ ! -f "$BREAKDOWN_TSV" ]
  _run_bash_event "git status"
  [ -f "$BREAKDOWN_TSV" ]
  line_count=$(wc -l < "$BREAKDOWN_TSV")
  [ "$line_count" -eq 1 ]
}

@test "bash-breakdown: 先頭 token が git になる" {
  _run_bash_event "git log --oneline -10"
  token=$(cut -f2 "$BREAKDOWN_TSV")
  [ "$token" = "git" ]
}

@test "bash-breakdown: ls コマンドで token が ls になる" {
  _run_bash_event "ls -la /tmp"
  token=$(cut -f2 "$BREAKDOWN_TSV")
  [ "$token" = "ls" ]
}

@test "bash-breakdown: echo コマンドで token が echo になる" {
  _run_bash_event "echo hello world"
  token=$(cut -f2 "$BREAKDOWN_TSV")
  [ "$token" = "echo" ]
}

@test "bash-breakdown: 複数回実行で行数が累積する" {
  _run_bash_event "git status"
  _run_bash_event "ls /tmp"
  _run_bash_event "echo test"
  line_count=$(wc -l < "$BREAKDOWN_TSV")
  [ "$line_count" -eq 3 ]
}

@test "bash-breakdown: full_command は先頭 60 chars に切り詰められる" {
  # 80 chars のコマンドを入力
  long_cmd="echo $(printf 'a%.0s' {1..80})"
  _run_bash_event "$long_cmd"
  full_cmd=$(cut -f3 "$BREAKDOWN_TSV")
  len=${#full_cmd}
  [ "$len" -le 60 ]
}

@test "bash-breakdown: tab は space に置換される" {
  _run_bash_event "$(printf 'git\tstatus')"
  full_cmd=$(cut -f3 "$BREAKDOWN_TSV")
  # tab が残っていないこと
  [[ ! "$full_cmd" =~ $'\t' ]]
}

@test "bash-breakdown: newline は space に置換される" {
  _run_bash_event "$(printf 'git\nstatus')"
  full_cmd=$(cut -f3 "$BREAKDOWN_TSV")
  [[ ! "$full_cmd" =~ $'\n' ]]
}

@test "bash-breakdown: timestamp が ISO8601 形式になる" {
  _run_bash_event "ls"
  ts=$(cut -f1 "$BREAKDOWN_TSV")
  # YYYY-MM-DDTHH:MM:SSZ 形式を検証
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# =============================================================================
# 非 Bash tool は append しない
# =============================================================================

@test "bash-breakdown: Read tool では tsv に append しない" {
  _run_non_bash_event "Read"
  [ ! -f "$BREAKDOWN_TSV" ]
}

@test "bash-breakdown: Write tool では tsv に append しない" {
  _run_non_bash_event "Write"
  [ ! -f "$BREAKDOWN_TSV" ]
}

@test "bash-breakdown: Edit tool では tsv に append しない" {
  _run_non_bash_event "Edit"
  [ ! -f "$BREAKDOWN_TSV" ]
}

# =============================================================================
# tsv 出力 path 検証
# =============================================================================

@test "bash-breakdown: tsv は HOME/.claude/logs/bash-breakdown.tsv に書き込まれる" {
  _run_bash_event "pwd"
  [ -f "${TEST_TMPDIR}/.claude/logs/bash-breakdown.tsv" ]
}

@test "bash-breakdown: ログディレクトリが存在しなくても自動作成される" {
  rm -rf "${TEST_TMPDIR}/.claude"
  _run_bash_event "pwd"
  [ -f "${TEST_TMPDIR}/.claude/logs/bash-breakdown.tsv" ]
}
