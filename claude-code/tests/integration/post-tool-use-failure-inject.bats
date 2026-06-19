#!/usr/bin/env bats
# =============================================================================
# post-tool-use-failure.sh: additionalContext inject テスト
# =============================================================================
# テスト対象: hooks/post-tool-use-failure.sh
# 観点:
#   case 1: 正常 inject - exit 0 / additionalContext に "tool Bash failed:" / " ..." なし
#   case 2: 200 chars 切り捨て - error 250 chars → " ..." 末尾付与
#   case 3: robust (unknown + 空 error) - stdout "{}" / log append は継続
#   case 4: tool_name 欠落でも exit 0
#   case 5: 空 JSON でも exit 0 かつ log append
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"

  # テスト用 HOME（本番ログ汚染防止）
  export ORIGINAL_HOME="$HOME"
  export HOME
  HOME="$(mktemp -d)"
  mkdir -p "${HOME}/.claude/logs"

  # log file を temp に向ける（env var override）
  export TOOL_FAILURE_LOG_FILE="${HOME}/.claude/logs/tool-failures.log"

  # Serena カウンタも temp に向ける
  export CLAUDE_SERENA_FAIL_COUNT="${HOME}/_serena_fail_count_test"
}

teardown() {
  if [[ "$HOME" != "$ORIGINAL_HOME" && "$HOME" == /tmp/* ]]; then
    rm -rf "$HOME"
  fi
  export HOME="$ORIGINAL_HOME"
}

# =============================================================================
# Case 1: 正常 inject
# full JSON を投入。exit 0 / additionalContext に "tool Bash failed:" を含む
# error が 200 chars 以下のため末尾 " ..." は付与されない
# =============================================================================
@test "post-tool-use-failure: case1 正常 inject - additionalContext に tool Bash failed: を含む" {
  local input
  input='{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","error":"X failed","duration_ms":100,"session_id":"test","cwd":"/tmp"}'

  run bash -c "echo '${input}' | '${HOOKS_DIR}/post-tool-use-failure.sh'"
  [ "$status" -eq 0 ]

  # output が有効な JSON
  echo "$output" | jq . >/dev/null

  # additionalContext フィールドが存在する
  local ctx
  ctx=$(echo "$output" | jq -r '.additionalContext')
  [ "$ctx" != "null" ]
  [ -n "$ctx" ]

  # "tool Bash failed:" を含む
  echo "$ctx" | grep -q "tool Bash failed:"

  # 末尾に " ..." が付かない（200 chars 以下なので切り捨てなし）
  [ "${ctx: -4}" != " ..." ]
}

# =============================================================================
# Case 2: 200 chars 切り捨て
# error が 250 chars（>200）のとき additionalContext 末尾に " ..." を付与
# error 部分は 200 chars に切り捨て
# =============================================================================
@test "post-tool-use-failure: case2 切り捨て - 250 chars error は ' ...' 付与" {
  # 250 文字の error 文字列を生成
  local long_error
  long_error="$(python3 -c "print('X' * 250, end='')")"
  local input
  input="{\"hook_event_name\":\"PostToolUseFailure\",\"tool_name\":\"Bash\",\"error\":\"${long_error}\",\"duration_ms\":100,\"session_id\":\"test\",\"cwd\":\"/tmp\"}"

  run bash -c "echo '${input}' | '${HOOKS_DIR}/post-tool-use-failure.sh'"
  [ "$status" -eq 0 ]

  local ctx
  ctx=$(echo "$output" | jq -r '.additionalContext')
  [ "$ctx" != "null" ]

  # 末尾に " ..." が付いている
  echo "$ctx" | grep -q ' \.\.\.$'

  # error 部分が 200 chars に切り捨てられている
  # format: "tool Bash failed: " (18 chars) + 200 chars + " ..." (4 chars) = 222 chars
  local ctx_len
  ctx_len="${#ctx}"
  [ "$ctx_len" -le 230 ]
}

# =============================================================================
# Case 3: robust (tool_name=unknown / error 空)
# hook は exit 0 / stdout は "{}" (inject skip)
# log file への append は継続して走る
# =============================================================================
@test "post-tool-use-failure: case3 robust - unknown + 空 error は stdout {} かつ log append" {
  local input
  input='{"hook_event_name":"PostToolUseFailure","tool_name":"unknown","error":"","duration_ms":100,"session_id":"test","cwd":"/tmp"}'

  run bash -c "echo '${input}' | '${HOOKS_DIR}/post-tool-use-failure.sh'"
  [ "$status" -eq 0 ]

  # stdout が "{}" (inject skip)
  [ "$output" = "{}" ]

  # log file に行が追記されている（log append は skip されない）
  [ -f "${TOOL_FAILURE_LOG_FILE}" ]
  grep -q "FAIL: unknown" "${TOOL_FAILURE_LOG_FILE}"
}

# =============================================================================
# Case 4: tool_name 欠落でも exit 0
# =============================================================================
@test "post-tool-use-failure: case4 tool_name 欠落でも exit 0" {
  local input
  input='{"error": "something went wrong", "session_id": "sess-test-004"}'

  run bash -c "echo '${input}' | '${HOOKS_DIR}/post-tool-use-failure.sh'"
  [ "$status" -eq 0 ]

  # output が有効な JSON
  echo "$output" | jq . >/dev/null
}

# =============================================================================
# Case 5: 空 JSON でも exit 0 かつ log append
# =============================================================================
@test "post-tool-use-failure: case5 空 JSON でも exit 0 かつ log append" {
  local input='{}'

  run bash -c "echo '${input}' | '${HOOKS_DIR}/post-tool-use-failure.sh'"
  [ "$status" -eq 0 ]

  # log file に行が追記されている
  [ -f "${TOOL_FAILURE_LOG_FILE}" ]
}
