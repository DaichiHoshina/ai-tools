#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — 並行 session commit 巻き込み guard
# staged file が session 編集 log に無ければ additionalContext に warn を注入
# =============================================================================

setup() {
  load "../../helpers/common"
  load "../../helpers/hook-invoke"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/pre-tool-use.sh"
  setup_test_tmpdir

  # session log は /tmp 固定 path なので test 毎に unique な SESSION_ID を使う
  export TEST_SESSION_ID="commit-guard-test-$$-${RANDOM}"
  export SES_LOG="/tmp/claude-session-edits-${TEST_SESSION_ID}.log"

  # tmpdir 内で git repo を initialize (user は inline -c で指定)
  cd "$TEST_TMPDIR"
  git init -q
  git -c user.name=test -c user.email=test@test commit -q --allow-empty -m init
}

teardown() {
  rm -f "$SES_LOG"
  teardown_test_tmpdir
}

# hook を stdin JSON に session_id / cwd を含めて呼ぶ
_invoke_commit_hook() {
  local cmd="$1"
  local input
  input=$(jq -n \
    --arg name "Bash" \
    --arg cmd "$cmd" \
    --arg sid "$TEST_SESSION_ID" \
    --arg cwd "$TEST_TMPDIR" \
    '{tool_name: $name, tool_input: {command: $cmd}, session_id: $sid, cwd: $cwd}')
  # env の CLAUDE_CODE_SESSION_ID leak を防ぐため unset
  echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "$HOOK_FILE"
}

@test "commit-guard: staged に session log 外の file がある → warn injects" {
  # session が編集した file (log に記録済み)
  local ours="${TEST_TMPDIR}/ours.txt"
  echo ours > "$ours"
  printf '%s\n' "$ours" > "$SES_LOG"

  # 別 session が編集したつもりの file (log に無い) を staged にする
  local intruder="${TEST_TMPDIR}/intruder.txt"
  echo x > "$intruder"
  git -C "$TEST_TMPDIR" add "$intruder"

  result=$(_invoke_commit_hook "git commit -m 'test'")
  ctx=$(get_additional_context "$result")
  [[ "$ctx" =~ "並行 session 巻き込み疑い" ]]
  [[ "$ctx" =~ "intruder.txt" ]]
}

@test "commit-guard: staged が session log 内の file のみ → warn 無し" {
  local ours="${TEST_TMPDIR}/ours.txt"
  echo ours > "$ours"
  printf '%s\n' "$ours" > "$SES_LOG"
  git -C "$TEST_TMPDIR" add "$ours"

  result=$(_invoke_commit_hook "git commit -m 'test'")
  ctx=$(get_additional_context "$result")
  # commit-guard 由来の warn が無いこと (他 warn の可能性はあるので巻き込み文言のみ判定)
  [[ ! "$ctx" =~ "並行 session 巻き込み疑い" ]]
}

@test "commit-guard: session log 不在 → skip (warn 無し)" {
  # log を作らずに staged file を追加
  local f="${TEST_TMPDIR}/foo.txt"
  echo foo > "$f"
  git -C "$TEST_TMPDIR" add "$f"
  [ ! -f "$SES_LOG" ]

  result=$(_invoke_commit_hook "git commit -m 'test'")
  ctx=$(get_additional_context "$result")
  [[ ! "$ctx" =~ "並行 session 巻き込み疑い" ]]
}
