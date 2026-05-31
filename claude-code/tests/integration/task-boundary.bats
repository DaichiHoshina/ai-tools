#!/usr/bin/env bats
# =============================================================================
# Task Boundary Tests - 1 task = 1 session 原則 /clear 推奨 notify
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"
  export ORIGINAL_HOME="$HOME"
  export HOME="$(mktemp -d)"
  mkdir -p "$HOME/.claude/logs"

  # テスト用 session_id と日付
  export TEST_SESSION_ID="test-session-abc123"
  export TEST_DATE="$(date -u +"%Y%m%d")"
  export TEST_FLAG="/tmp/claude_task_count_${TEST_SESSION_ID}_${TEST_DATE}.flag"

  # テスト開始時に flag をクリア（前回テストの残留防止）
  rm -f "${TEST_FLAG}"
}

teardown() {
  rm -f "${TEST_FLAG}"
  if [[ "$HOME" != "$ORIGINAL_HOME" && "$HOME" == /tmp/* ]]; then
    rm -rf "$HOME"
  fi
  export HOME="$ORIGINAL_HOME"
}

# タスク完了 hook を呼び出すヘルパー
_run_hook() {
  local session_id="${1}"
  local task_id="${2:-task-001}"
  local input
  input=$(jq -n \
    --arg sid "${session_id}" \
    --arg tid "${task_id}" \
    '{session_id: $sid, task_id: $tid, task_subject: "test task", teammate_name: "dev1", team_name: "test-team", cwd: "/tmp"}')
  run bash -c "echo '${input}' | ${HOOKS_DIR}/task-completed.sh"
}

# =============================================================================

@test "task-boundary: 1 task 完了 → notify なし (閾値 2 未満)" {
  _run_hook "${TEST_SESSION_ID}" "task-001"
  [ "$status" -eq 0 ]
  # stderr に [task-done] が出ていないこと
  [[ "${output}" != *"[task-done]"* ]]
}

@test "task-boundary: 2 task 完了 → notify あり" {
  # 1 task 目
  _run_hook "${TEST_SESSION_ID}" "task-001"
  [ "$status" -eq 0 ]

  # 2 task 目
  _run_hook "${TEST_SESSION_ID}" "task-002"
  [ "$status" -eq 0 ]

  # stderr に /clear 推奨メッセージが出ること
  # bash -c で stderr も stdout に混ぜて確認
  local combined
  combined=$(echo "$(jq -n --arg sid "${TEST_SESSION_ID}" '{session_id: $sid, task_id: "task-002", task_subject: "test", teammate_name: "dev1", team_name: "t", cwd: "/tmp"}')" \
    | bash "${HOOKS_DIR}/task-completed.sh" 2>&1)
  [[ "${combined}" == *"[task-done]"* ]]
  [[ "${combined}" == *"/clear 推奨"* ]]
}

@test "task-boundary: 別 session_id → counter 独立" {
  local session_a="session-aaa-111"
  local session_b="session-bbb-222"
  local flag_a="/tmp/claude_task_count_${session_a}_${TEST_DATE}.flag"
  local flag_b="/tmp/claude_task_count_${session_b}_${TEST_DATE}.flag"
  rm -f "${flag_a}" "${flag_b}"

  # session_a: 2 task 完了
  _run_hook "${session_a}" "task-001"
  _run_hook "${session_a}" "task-002"

  # session_b: 1 task のみ → notify なし
  local combined_b
  combined_b=$(echo "$(jq -n --arg sid "${session_b}" '{session_id: $sid, task_id: "task-001", task_subject: "test", teammate_name: "dev1", team_name: "t", cwd: "/tmp"}')" \
    | bash "${HOOKS_DIR}/task-completed.sh" 2>&1)

  # session_b は 1 task 目なので notify なし
  [[ "${combined_b}" != *"[task-done]"* ]]

  # session_a の flag は 2
  local count_a
  count_a=$(< "${flag_a}")
  [ "${count_a}" -ge 2 ]

  # session_b の flag は 1
  local count_b
  count_b=$(< "${flag_b}")
  [ "${count_b}" -eq 1 ]

  rm -f "${flag_a}" "${flag_b}"
}
