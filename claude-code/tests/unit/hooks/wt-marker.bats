#!/usr/bin/env bats
# =============================================================================
# BATS Tests for post-tool-use.sh statusline worktree marker logic
# cd 検出 (~ 展開 / 最後の cd 採用) と worktree マーカー保護を検証する
# =============================================================================

setup() {
  load "../../helpers/common"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/post-tool-use.sh"
  setup_test_tmpdir
  export ORIG_HOME="$HOME"
  export HOME="$TEST_TMPDIR"
  export TEST_SESSION="wtmk-$$-${RANDOM}"
  export MARKER="/tmp/claude-wt-${TEST_SESSION}-$(date +%Y%m%d)"
  # cd 先 / CWD は git repo である必要があるため tmp に repo を作る
  git init -q "${TEST_TMPDIR}/mainrepo"
  git init -q "${TEST_TMPDIR}/repo-wt-topic"
}

teardown() {
  rm -f "$MARKER"
  export HOME="$ORIG_HOME"
  teardown_test_tmpdir
}

_run_bash_event() {
  local cmd="$1"
  local cwd="${2:-${TEST_TMPDIR}/mainrepo}"
  jq -n --arg c "$cmd" --arg s "$TEST_SESSION" --arg w "$cwd" '{
    tool_name: "Bash",
    tool_input: {command: $c},
    session_id: $s,
    cwd: $w,
    tool_response: {stdout: "", duration_ms: 100}
  }' | bash "$HOOK_FILE"
}

@test "cd の ~ 付き path を HOME 展開して marker に書く" {
  git init -q "${TEST_TMPDIR}/tilde-target"
  _run_bash_event 'cd ~/tilde-target && git status'
  [ -f "$MARKER" ]
  run cat "$MARKER"
  [[ "$output" == *"/tilde-target" ]]
}

@test "複合 command は最後の cd を marker に採る" {
  git init -q "${TEST_TMPDIR}/first"
  git init -q "${TEST_TMPDIR}/second"
  _run_bash_event "cd ${TEST_TMPDIR}/first && ls; cd ${TEST_TMPDIR}/second && ls"
  run cat "$MARKER"
  [[ "$output" == *"/second" ]]
}

@test "cd なし Bash は実在する -wt- sibling marker を上書きしない" {
  echo "${TEST_TMPDIR}/repo-wt-topic" > "$MARKER"
  _run_bash_event 'git status'
  run cat "$MARKER"
  [ "$output" = "${TEST_TMPDIR}/repo-wt-topic" ]
}

@test "cd なし Bash は削除済み worktree marker を CWD で上書きする" {
  echo "${TEST_TMPDIR}/repo-wt-gone" > "$MARKER"
  _run_bash_event 'git status'
  run cat "$MARKER"
  [[ "$output" == *"/mainrepo" ]]
}
