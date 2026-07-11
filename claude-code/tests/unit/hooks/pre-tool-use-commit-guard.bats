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

# =============================================================================
# staged diff scan (warn-only): 追加行の private term 検出
# =============================================================================

# HOME 隔離 + $HOME/ai-tools を git repo 化して ai-tools cwd を再現する
_setup_aitools_repo() {
  setup_home_isolated
  export AIT_REPO="${HOME}/ai-tools"
  mkdir -p "$AIT_REPO"
  git -C "$AIT_REPO" init -q
  git -C "$AIT_REPO" -c user.name=test -c user.email=test@test commit -q --allow-empty -m init
  # private-name 動的 list に test 用 term を登録
  mkdir -p "${HOME}/.claude/references-private"
  printf 'secretcorp\n' > "${HOME}/.claude/references-private/private-name-list.txt"
}

# ai-tools cwd で hook を呼ぶ
_invoke_commit_hook_aitools() {
  local cmd="$1"
  local input
  input=$(jq -n \
    --arg name "Bash" \
    --arg cmd "$cmd" \
    --arg sid "$TEST_SESSION_ID" \
    --arg cwd "$AIT_REPO" \
    '{tool_name: $name, tool_input: {command: $cmd}, session_id: $sid, cwd: $cwd}')
  echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "$HOOK_FILE"
}

@test "staged-diff-scan: 追加行に private term → warn injects (deny しない)" {
  _setup_aitools_repo
  echo "notes about secretcorp launch" > "${AIT_REPO}/memo.md"
  git -C "$AIT_REPO" add memo.md

  result=$(_invoke_commit_hook_aitools "git commit -m 'add memo'")
  teardown_home_isolated

  ctx=$(echo "$result" | jq -r '.additionalContext // empty')
  [[ "$ctx" =~ "staged diff に private term の疑い" ]]
  [[ "$ctx" =~ "secretcorp" ]]
  # warn-only: deny されないこと
  [[ "$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecision // .permissionDecision // empty')" != "deny" ]]
}

@test "staged-diff-scan: term なし → warn 無し" {
  _setup_aitools_repo
  echo "clean content" > "${AIT_REPO}/memo.md"
  git -C "$AIT_REPO" add memo.md

  result=$(_invoke_commit_hook_aitools "git commit -m 'add memo'")
  teardown_home_isolated

  ctx=$(echo "$result" | jq -r '.additionalContext // empty')
  [[ ! "$ctx" =~ "staged diff に private term の疑い" ]]
}

@test "staged-diff-scan: ai-tools 外 cwd → scan skip" {
  _setup_aitools_repo
  # ai-tools 外の repo (TEST_TMPDIR) に term 入り file を staged
  echo "secretcorp here" > "${TEST_TMPDIR}/memo.md"
  git -C "$TEST_TMPDIR" add memo.md

  result=$(_invoke_commit_hook "git commit -m 'add memo'")
  teardown_home_isolated

  ctx=$(echo "$result" | jq -r '.additionalContext // empty')
  [[ ! "$ctx" =~ "staged diff に private term の疑い" ]]
}

@test "staged-diff-scan: 巨大 diff でも hook が完走する" {
  _setup_aitools_repo
  # 128KB 上限を超える追加行 (term は末尾に置いて cap で切られる側に回す)
  { yes "padding line without terms" | head -20000; echo "secretcorp"; } > "${AIT_REPO}/big.txt"
  git -C "$AIT_REPO" add big.txt

  run bash -c '
    input=$(jq -n --arg cmd "git commit -m big" --arg sid "'"$TEST_SESSION_ID"'" --arg cwd "'"$AIT_REPO"'" \
      "{tool_name: \"Bash\", tool_input: {command: \$cmd}, session_id: \$sid, cwd: \$cwd}")
    echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "'"$HOOK_FILE"'"
  '
  teardown_home_isolated
  [ "$status" -eq 0 ]
}
