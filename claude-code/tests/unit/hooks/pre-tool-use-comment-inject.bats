#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — _inject_code_comment_rules
# code file への comment 追加編集で code-comment 規範 digest を inject する動作
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

# session_id 付き run_hook ヘルパー (today-commits bats と同方式)
_run_hook_with_session() {
  local tool_name="$1"
  local tool_input="$2"
  local session_id="$3"
  local input
  input=$(jq -n \
    --arg name "$tool_name" \
    --argjson inp "$tool_input" \
    --arg sid "$session_id" \
    '{tool_name: $name, tool_input: $inp, session_id: $sid}')
  echo "$input" | env -u CLAUDE_CODE_SESSION_ID bash "$HOOK_FILE"
}

_clear_comment_flag() {
  local sid="$1"
  local today
  today=$(date +%Y%m%d)
  rm -f "/tmp/claude-comment-inject-${sid}-${today}" 2>/dev/null || true
}

@test "comment-inject: code file (.go) への comment 追加 Edit で digest が出る" {
  local sid="cc-go-$$"
  _clear_comment_flag "$sid"

  local result
  result=$(_run_hook_with_session "Edit" \
    '{"file_path":"/tmp/x.go","old_string":"foo()","new_string":"// rate limit が 10 req/s のため 100ms 遅延する\nfoo()"}' "$sid")
  _clear_comment_flag "$sid"

  [[ "$(get_additional_context "$result")" =~ "code comment 規範" ]]
}

@test "comment-inject: 非 code file (.md) では inject されない" {
  local sid="cc-md-$$"
  _clear_comment_flag "$sid"

  local result
  result=$(_run_hook_with_session "Write" \
    '{"file_path":"/tmp/x.md","content":"# heading\n// これは md の code block 例"}' "$sid")
  _clear_comment_flag "$sid"

  [[ ! "$(echo "$result" | jq -r '.additionalContext // empty')" =~ "code comment 規範" ]]
}

@test "comment-inject: comment 行なしの code Edit では inject されない" {
  local sid="cc-nocomment-$$"
  _clear_comment_flag "$sid"

  local result
  result=$(_run_hook_with_session "Edit" \
    '{"file_path":"/tmp/x.go","old_string":"foo()","new_string":"bar()"}' "$sid")
  _clear_comment_flag "$sid"

  [[ ! "$(echo "$result" | jq -r '.additionalContext // empty')" =~ "code comment 規範" ]]
}

@test "comment-inject: 同一 session 2 回目は inject されない" {
  local sid="cc-dedup-$$"
  _clear_comment_flag "$sid"

  local result1 result2
  result1=$(_run_hook_with_session "Edit" \
    '{"file_path":"/tmp/x.go","old_string":"a","new_string":"// why not: goroutine 化は order 保証が崩れるため採らない\na"}' "$sid")
  result2=$(_run_hook_with_session "Edit" \
    '{"file_path":"/tmp/x.go","old_string":"b","new_string":"// what: b を呼ぶ\nb"}' "$sid")
  _clear_comment_flag "$sid"

  [[ "$(get_additional_context "$result1")" =~ "code comment 規範" ]]
  [[ ! "$(echo "$result2" | jq -r '.additionalContext // empty')" =~ "code comment 規範" ]]
}

@test "comment-inject: shebang のみの .sh では inject されない" {
  local sid="cc-shebang-$$"
  _clear_comment_flag "$sid"

  local result
  result=$(_run_hook_with_session "Write" \
    '{"file_path":"/tmp/x.sh","content":"#!/usr/bin/env bash\nset -euo pipefail\necho ok"}' "$sid")
  _clear_comment_flag "$sid"

  [[ ! "$(echo "$result" | jq -r '.additionalContext // empty')" =~ "code comment 規範" ]]
}

@test "comment-inject: .sh の # comment (shebang 以外) で inject される" {
  local sid="cc-sh-$$"
  _clear_comment_flag "$sid"

  local result
  result=$(_run_hook_with_session "Write" \
    '{"file_path":"/tmp/x.sh","content":"#!/usr/bin/env bash\n# retry 上限は外部 API の rate limit 由来\necho ok"}' "$sid")
  _clear_comment_flag "$sid"

  [[ "$(get_additional_context "$result")" =~ "code comment 規範" ]]
}

@test "comment-inject: serena replace_symbol_body の body comment で inject される" {
  local sid="cc-serena-$$"
  _clear_comment_flag "$sid"

  local result
  result=$(_run_hook_with_session "mcp__serena__replace_symbol_body" \
    '{"relative_path":"pkg/foo.go","name_path":"Foo","body":"func Foo() {\n\t// fail-open: 設定取得失敗時は dry-run=true で続行する\n}"}' "$sid")
  _clear_comment_flag "$sid"

  [[ "$(get_additional_context "$result")" =~ "code comment 規範" ]]
}

@test "comment-inject: sql の -- comment で inject される" {
  local sid="cc-sql-$$"
  _clear_comment_flag "$sid"

  local result
  result=$(_run_hook_with_session "Write" \
    '{"file_path":"/tmp/x.sql","content":"-- replica lag 回避のため primary を明示指定する\nSELECT 1;"}' "$sid")
  _clear_comment_flag "$sid"

  [[ "$(get_additional_context "$result")" =~ "code comment 規範" ]]
}
