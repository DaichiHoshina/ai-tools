#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — _inject_today_commits
# 書く系 tool の additionalContext に今日の commit を inject する動作
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
  # session_id を stdin から優先させるため env の CLAUDE_CODE_SESSION_ID を落とす
  # (共有 helper の invoke_hook_stdin は env 制御しないので直接展開)
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
