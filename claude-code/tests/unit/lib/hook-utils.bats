#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hook-utils.sh
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/hook-utils.sh"
}

# =============================================================================
# 正常系テスト: read_hook_input
# =============================================================================

@test "hook-utils: read_hook_input reads JSON from stdin" {
  local input='{"key": "value"}'
  run bash -c "source '$LIB_FILE' && echo '$input' | read_hook_input"
  [ "$status" -eq 0 ]
  [ "$output" = "$input" ]
}

@test "hook-utils: read_hook_input handles multi-line JSON" {
  local input=$'{\n  "key": "value",\n  "number": 123\n}'
  run bash -c "source '$LIB_FILE' && echo '$input' | read_hook_input"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "key" ]]
  [[ "$output" =~ "value" ]]
}

# =============================================================================
# 正常系テスト: get_field
# =============================================================================

@test "hook-utils: get_field extracts top-level string field" {
  local input='{"name": "test", "value": 123}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name'"
  [ "$status" -eq 0 ]
  [ "$output" = "test" ]
}

@test "hook-utils: get_field extracts top-level number field" {
  local input='{"name": "test", "value": 123}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'value'"
  [ "$status" -eq 0 ]
  [ "$output" = "123" ]
}

@test "hook-utils: get_field returns default for missing field" {
  local input='{"name": "test"}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'missing' 'default_value'"
  [ "$status" -eq 0 ]
  [ "$output" = "default_value" ]
}

@test "hook-utils: get_field returns empty for missing field without default" {
  local input='{"name": "test"}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'missing'"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

# =============================================================================
# 正常系テスト: get_nested_field
# =============================================================================

@test "hook-utils: get_nested_field extracts nested field" {
  local input='{"workspace": {"current_dir": "/home/user"}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'workspace.current_dir'"
  [ "$status" -eq 0 ]
  [ "$output" = "/home/user" ]
}

@test "hook-utils: get_nested_field extracts deeply nested field" {
  local input='{"a": {"b": {"c": "deep_value"}}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a.b.c'"
  [ "$status" -eq 0 ]
  [ "$output" = "deep_value" ]
}

@test "hook-utils: get_nested_field returns default for missing nested path" {
  local input='{"workspace": {"current_dir": "/home/user"}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'workspace.missing' 'default'"
  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

# =============================================================================
# 異常系テスト
# =============================================================================

@test "hook-utils: get_field handles invalid JSON gracefully" {
  local input='invalid json'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name' 'fallback' 2>&1"
  # jq will fail, but we check that it doesn't crash
  [ "$status" -ne 0 ]
}

@test "hook-utils: get_field handles empty JSON object" {
  local input='{}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'name' 'default'"
  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

# =============================================================================
# 境界値テスト
# =============================================================================

@test "boundary: get_field handles special characters in values" {
  local input='{"key": "value with spaces & special <chars>"}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'key'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "value with spaces" ]]
}

@test "boundary: get_field handles null value" {
  local input='{"key": null}'
  run bash -c "source '$LIB_FILE' && get_field '$input' 'key' 'default'"
  [ "$status" -eq 0 ]
  [ "$output" = "default" ]
}

@test "boundary: get_nested_field handles array access" {
  local input='{"items": [{"name": "first"}, {"name": "second"}]}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'items[0].name'"
  [ "$status" -eq 0 ]
  [ "$output" = "first" ]
}

@test "security: get_nested_field rejects path with space → default" {
  local input='{"a": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a + 100' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects path with comma → default" {
  local input='{"a": 1, "b": 2}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' '.a, .b' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects path with pipe → default" {
  local input='{"a": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a | length' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects leading dot → default" {
  local input='{"a": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' '.a' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects double dot → default" {
  local input='{"a": {"b": 1}}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a..b' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects trailing dot → default" {
  local input='{"a": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a.' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects bracket with non-digit → default" {
  local input='{"a": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a[xyz]' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects empty bracket → default" {
  local input='{"a": [1,2]}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a[]' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects bracket-only path → default" {
  local input='{"a": [1]}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' '[0]' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects reversed brackets → default" {
  local input='{"a": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' ']abc[' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects leading digit → default" {
  local input='{"1abc": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' '1abc' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects hyphen in path → default" {
  local input='{"a-b": 1}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a-b' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

@test "security: get_nested_field rejects bracket without separator → default" {
  local input='{"a": [{"b": 1}]}'
  run bash -c "source '$LIB_FILE' && get_nested_field '$input' 'a[0]b' 'safe'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe" ]
}

# =============================================================================
# 統合テスト
# =============================================================================

@test "integration: hook-utils functions work together" {
  local input='{"workspace": {"current_dir": "/home/user"}, "prompt": "test"}'

  # First extract nested field
  dir=$(bash -c "source '$LIB_FILE' && get_nested_field '$input' 'workspace.current_dir'")
  [ "$dir" = "/home/user" ]

  # Then extract top-level field
  prompt=$(bash -c "source '$LIB_FILE' && get_field '$input' 'prompt'")
  [ "$prompt" = "test" ]
}

# =============================================================================
# append_message テスト
# =============================================================================

@test "append_message: 両空 → 空" {
  run bash -c "source '$LIB_FILE' && append_message '' ''"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "append_message: current 空 + addition 値 → addition そのまま" {
  run bash -c "source '$LIB_FILE' && append_message '' 'first'"
  [ "$status" -eq 0 ]
  [ "$output" = "first" ]
}

@test "append_message: current 値 + addition 空 → current そのまま" {
  run bash -c "source '$LIB_FILE' && append_message 'existing' ''"
  [ "$status" -eq 0 ]
  [ "$output" = "existing" ]
}

@test "append_message: current 値 + addition 値 → 改行結合" {
  run bash -c "source '$LIB_FILE' && append_message 'first' 'second'"
  [ "$status" -eq 0 ]
  [ "$output" = "first
second" ]
}

@test "append_message: 連続 append で複数行蓄積" {
  result=$(bash -c "source '$LIB_FILE' && M=''; M=\$(append_message \"\$M\" 'a'); M=\$(append_message \"\$M\" 'b'); M=\$(append_message \"\$M\" 'c'); printf '%s' \"\$M\"")
  [ "$result" = "a
b
c" ]
}

@test "append_message: addition が多行文字列でも正しく結合" {
  run bash -c "source '$LIB_FILE' && append_message 'first' 'line1
line2'"
  [ "$status" -eq 0 ]
  [ "$output" = "first
line1
line2" ]
}

# =============================================================================
# extract_json_fields テスト
# =============================================================================

@test "extract_json_fields: 単一フィールド抽出" {
  local input='{"name": "test", "value": 42}'
  run bash -c "source '$LIB_FILE' && extract_json_fields '$input' '.name'"
  [ "$status" -eq 0 ]
  [ "$output" = "test" ]
}

@test "extract_json_fields: 複数フィールドを TSV で取得" {
  local input='{"a": "x", "b": "y", "c": "z"}'
  run bash -c "source '$LIB_FILE' && extract_json_fields '$input' '.a' '.b' '.c'"
  [ "$status" -eq 0 ]
  [ "$output" = $'x\ty\tz' ]
}

@test "extract_json_fields: デフォルト値付き jq 式" {
  local input='{"a": "x"}'
  run bash -c "source '$LIB_FILE' && extract_json_fields '$input' '.a // \"default_a\"' '.missing // \"default_b\"'"
  [ "$status" -eq 0 ]
  [ "$output" = $'x\tdefault_b' ]
}

@test "extract_json_fields: ネストフィールド抽出" {
  local input='{"outer": {"inner": "nested_value"}}'
  run bash -c "source '$LIB_FILE' && extract_json_fields '$input' '.outer.inner'"
  [ "$status" -eq 0 ]
  [ "$output" = "nested_value" ]
}

@test "extract_json_fields: 数値フィールドも文字列化される" {
  local input='{"count": 100}'
  run bash -c "source '$LIB_FILE' && extract_json_fields '$input' '.count'"
  [ "$status" -eq 0 ]
  [ "$output" = "100" ]
}

# =============================================================================
# require_jq テスト
# =============================================================================

@test "require_jq: jq インストール済み環境で exit 0" {
  run bash -c "source '$LIB_FILE' && require_jq && echo SUCCESS"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "SUCCESS" ]]
}

@test "require_jq: PATH から jq を外すと exit 1" {
  # bash 本体は $BASH で絶対パス解決（PATH=/nonexistent でも子bash起動可能）
  # → jq だけ非到達 → require_jq の exit 1 を厳格検証（127 = command not found を排除）
  run -1 env -i PATH=/nonexistent HOME="$HOME" "$BASH" -c "source '$LIB_FILE' && require_jq"
}

# =============================================================================
# send_stop_notification テスト
# =============================================================================

setup_send_stop_notification() {
  # tmpdir作成 + PATH をそこに絞る（terminal-notifier/curl をstub化）
  export TEST_TMPDIR="$(mktemp -d)"
  export PATH="${TEST_TMPDIR}:${PATH}"
  export HOME="${TEST_TMPDIR}/home"
  mkdir -p "${HOME}/.claude"
  # short-message skip を default 無効化 (既存 test は短 message を許容前提のため)
  export CLAUDE_STOP_NOTIFY_MIN_LEN=0
  # user turn 通知は default ON。明示 OFF (=0) test 側で unset / 上書きする。
  unset CLAUDE_STOP_NOTIFY

  # stub script: terminal-notifier
  cat > "${TEST_TMPDIR}/terminal-notifier" << 'EOF'
#!/bin/bash
# Log all arguments
echo "$@" > "$TEST_TMPDIR/terminal-notifier.log"
EOF
  chmod +x "${TEST_TMPDIR}/terminal-notifier"

  # stub script: curl
  cat > "${TEST_TMPDIR}/curl" << 'EOF'
#!/bin/bash
# Log all arguments and stdin
{
  echo "ARGS: $@"
  echo "STDIN: $(cat)"
} > "$TEST_TMPDIR/curl.log"
EOF
  chmod +x "${TEST_TMPDIR}/curl"
}

teardown_send_stop_notification() {
  rm -rf "${TEST_TMPDIR}"
  unset TEST_TMPDIR CLAUDE_STOP_NOTIFY_MIN_LEN CLAUDE_STOP_NOTIFY
}

@test "send_stop_notification: min_len 未満の short message は notify skip" {
  setup_send_stop_notification
  # skip 発火のため min_len を default (8) に戻す
  unset CLAUDE_STOP_NOTIFY_MIN_LEN
  local input='{"session_id":"s1","last_assistant_message":"test","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  # 200ms 待って log が生成されないことを確認
  sleep 0.2
  [ ! -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  teardown_send_stop_notification
}

@test "send_stop_notification: CLAUDE_STOP_NOTIFY=0 なら明示 OFF (notify skip)" {
  setup_send_stop_notification
  # 明示 OFF は CLAUDE_STOP_NOTIFY=0
  export CLAUDE_STOP_NOTIFY=0
  local input='{"session_id":"s1","last_assistant_message":"long enough message here","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.2
  [ ! -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  teardown_send_stop_notification
}

# send_stop_notification は terminal-notifier / curl を background (&) で fire するため、
# log ファイル生成は非同期。固定 sleep だと並列実行時に間に合わず flaky になるので、
# 生成をポーリング待ちする (最大 5s、10ms 刻み)。
_wait_for_file() {
  local f="$1" i=0
  while [ ! -f "$f" ] && [ "$i" -lt 500 ]; do
    sleep 0.01
    i=$((i + 1))
  done
}

@test "send_stop_notification: terminal-notifier に title/message を渡す" {
  setup_send_stop_notification
  local input='{"session_id":"s1","last_assistant_message":"test message","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input' '' 'Glass'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/terminal-notifier.log"
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  grep -q "test message" "${TEST_TMPDIR}/terminal-notifier.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: メッセージが 80 文字超なら truncate される" {
  setup_send_stop_notification
  local long_msg=$(printf 'x%.0s' {1..100})  # 100文字
  local input="{\"session_id\":\"s1\",\"last_assistant_message\":\"${long_msg}\",\"cwd\":\"/tmp/project\"}"
  bash -c "source '$LIB_FILE' && send_stop_notification '$input' '' 'Glass'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/terminal-notifier.log"
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  # Log には最初の 80 文字 + "..." が含まれる
  grep -q "xxx..." "${TEST_TMPDIR}/terminal-notifier.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: NTFY_TOPIC がなければ curl は呼ばれない" {
  setup_send_stop_notification
  unset CLAUDE_NTFY_TOPIC 2>/dev/null || true
  local input='{"session_id":"s1","last_assistant_message":"test","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  # curl.log が生成されない（呼ばれていない）
  [ ! -f "${TEST_TMPDIR}/curl.log" ]
  teardown_send_stop_notification
}

@test "send_stop_notification: NTFY_TOPIC があれば curl で ntfy.sh を叩く" {
  setup_send_stop_notification
  export CLAUDE_NTFY_TOPIC="test-topic"
  local input='{"session_id":"s1","last_assistant_message":"hello","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/curl.log"
  [ -f "${TEST_TMPDIR}/curl.log" ]
  grep -q "ntfy.sh" "${TEST_TMPDIR}/curl.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: terminal-notifier が PATH にないなら graceful" {
  setup_send_stop_notification
  # stub を削除しただけだと PATH 探索が homebrew の実 terminal-notifier に fallthrough
  # して実通知が鳴る。jq だけ TEST_TMPDIR に link し、homebrew を含まない PATH に絞る
  rm "${TEST_TMPDIR}/terminal-notifier"
  ln -s "$(command -v jq)" "${TEST_TMPDIR}/jq"
  export PATH="${TEST_TMPDIR}:/usr/bin:/bin"
  local input='{"session_id":"s1","last_assistant_message":"test","cwd":"/tmp/project"}'
  run bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>&1
  [ "$status" -eq 0 ]
  teardown_send_stop_notification
}

@test "send_stop_notification: 空メッセージでも crash しない" {
  setup_send_stop_notification
  local input='{"session_id":"s1","last_assistant_message":"","cwd":"/tmp/project"}'
  run bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>&1
  [ "$status" -eq 0 ]
  teardown_send_stop_notification
}

@test "send_stop_notification: default message を使う（last_assistant_message なし）" {
  setup_send_stop_notification
  local input='{"session_id":"s1","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/terminal-notifier.log"
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  grep -q "作業が完了しました" "${TEST_TMPDIR}/terminal-notifier.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: title_suffix が付与される" {
  setup_send_stop_notification
  local input='{"session_id":"s1","last_assistant_message":"msg","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input' '[SUCCESS]'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/terminal-notifier.log"
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  grep -q "\[SUCCESS\]" "${TEST_TMPDIR}/terminal-notifier.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: session_id なし (fixture/smoke) は notify skip" {
  setup_send_stop_notification
  local input='{"last_assistant_message":"real event ではない fixture","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.2
  [ ! -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  teardown_send_stop_notification
}

@test "send_stop_notification: cursor_version あり (Claude Code 以外) は notify skip" {
  setup_send_stop_notification
  local input='{"session_id":"s1","cursor_version":"1.0","last_assistant_message":"cursor generation done"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.2
  [ ! -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  teardown_send_stop_notification
}

@test "send_stop_notification: Stop event で background task running なら notify skip" {
  setup_send_stop_notification
  local input='{"session_id":"s1","hook_event_name":"Stop","last_assistant_message":"agent 実行中に turn end","cwd":"/tmp/project","background_tasks":[{"id":"t1","type":"shell","status":"running"}]}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.2
  [ ! -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  teardown_send_stop_notification
}

@test "send_stop_notification: background task が全部 completed なら notify する" {
  setup_send_stop_notification
  local input='{"session_id":"s1","hook_event_name":"Stop","last_assistant_message":"全 task 完了後の user turn","cwd":"/tmp/project","background_tasks":[{"id":"t1","type":"shell","status":"completed"}]}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  _wait_for_file "${TEST_TMPDIR}/terminal-notifier.log"
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  teardown_send_stop_notification
}

# =============================================================================
# ensure_worktree_memory_link テスト
# =============================================================================

setup_ensure_worktree() {
  export TEST_WORKTREE_ROOT="$(mktemp -d)"
  export HOME="${TEST_WORKTREE_ROOT}/home"
  mkdir -p "${HOME}/.claude/projects"
  export CLAUDE_DIR="${HOME}/.claude"
}

teardown_ensure_worktree() {
  rm -rf "${TEST_WORKTREE_ROOT}"
  unset TEST_WORKTREE_ROOT HOME CLAUDE_DIR
}

@test "ensure_worktree_memory_link: 通常 git repo（worktree 非該当）→ 何もしない" {
  setup_ensure_worktree
  # 通常の git repo
  mkdir -p "${TEST_WORKTREE_ROOT}/repo"
  (cd "${TEST_WORKTREE_ROOT}/repo" && git init)
  run bash -c "source '$LIB_FILE' && ensure_worktree_memory_link '${TEST_WORKTREE_ROOT}/repo'"
  [ "$status" -eq 0 ]
  [ ! -e "${HOME}/.claude/projects/$(echo ${TEST_WORKTREE_ROOT}/repo | sed 's|/|-|g')/memory" ]
  teardown_ensure_worktree
}

@test "ensure_worktree_memory_link: worktree + memory dir なし → 作成 + symlink 構築" {
  setup_ensure_worktree
  local main_repo="${TEST_WORKTREE_ROOT}/main"
  local wt_root="${TEST_WORKTREE_ROOT}/wt1"

  # main repo を初期化
  mkdir -p "${main_repo}"
  git -C "${main_repo}" init 2>/dev/null
  git -C "${main_repo}" config user.email "test@example.com" 2>/dev/null
  git -C "${main_repo}" config user.name "Test" 2>/dev/null

  # worktree を作成
  git -C "${main_repo}" worktree add "${wt_root}" 2>/dev/null

  # git の出力からパス情報を取得（symlink 先の絶対パスを git-common-dir 親から計算）
  local abs_common
  abs_common=$(git -C "${wt_root}" rev-parse --git-common-dir 2>/dev/null)
  local calc_main_repo
  calc_main_repo=$(dirname "${abs_common}")

  # ID を git 出力から計算
  local wt_id main_id
  wt_id=${wt_root//\//-}
  main_id=${calc_main_repo//\//-}

  local wt_mem="${HOME}/.claude/projects/${wt_id}/memory"
  local main_mem="${HOME}/.claude/projects/${main_id}/memory"

  # 関数を実呼び出し - memory dir なし、symlink 構築を検証
  run bash -c "HOME='${HOME}' source '$LIB_FILE' && ensure_worktree_memory_link '${wt_root}'"
  [ "$status" -eq 0 ]
  [ -L "${wt_mem}" ]
  [ "$(readlink "${wt_mem}")" = "${main_mem}" ]
  teardown_ensure_worktree
}

@test "ensure_worktree_memory_link: 既存 symlink → idempotent（何もしない）" {
  setup_ensure_worktree
  local main_repo="${TEST_WORKTREE_ROOT}/main"
  local wt_root="${TEST_WORKTREE_ROOT}/wt1"

  # main repo を初期化
  mkdir -p "${main_repo}"
  git -C "${main_repo}" init 2>/dev/null
  git -C "${main_repo}" config user.email "test@example.com" 2>/dev/null
  git -C "${main_repo}" config user.name "Test" 2>/dev/null

  # worktree を作成
  git -C "${main_repo}" worktree add "${wt_root}" 2>/dev/null

  # git の出力からパス情報を取得
  local abs_common
  abs_common=$(git -C "${wt_root}" rev-parse --git-common-dir 2>/dev/null)
  local calc_main_repo
  calc_main_repo=$(dirname "${abs_common}")

  # ID を git 出力から計算
  local wt_id main_id
  wt_id=${wt_root//\//-}
  main_id=${calc_main_repo//\//-}

  local wt_mem="${HOME}/.claude/projects/${wt_id}/memory"
  local main_mem="${HOME}/.claude/projects/${main_id}/memory"

  # 事前に symlink を作成
  mkdir -p "${main_mem}"
  mkdir -p "$(dirname "${wt_mem}")"
  ln -s "${main_mem}" "${wt_mem}"

  # 関数を実呼び出し - idempotent チェック
  run bash -c "HOME='${HOME}' source '$LIB_FILE' && ensure_worktree_memory_link '${wt_root}'"
  [ "$status" -eq 0 ]
  [ -L "${wt_mem}" ]
  [ "$(readlink "${wt_mem}")" = "${main_mem}" ]
  teardown_ensure_worktree
}

@test "ensure_worktree_memory_link: 既存 dir（symlink ではない） → 退避して symlink" {
  setup_ensure_worktree
  local main_repo="${TEST_WORKTREE_ROOT}/main"
  local wt_root="${TEST_WORKTREE_ROOT}/wt1"

  # main repo を初期化
  mkdir -p "${main_repo}"
  git -C "${main_repo}" init 2>/dev/null
  git -C "${main_repo}" config user.email "test@example.com" 2>/dev/null
  git -C "${main_repo}" config user.name "Test" 2>/dev/null

  # worktree を作成
  git -C "${main_repo}" worktree add "${wt_root}" 2>/dev/null

  # git の出力からパス情報を取得
  local abs_common
  abs_common=$(git -C "${wt_root}" rev-parse --git-common-dir 2>/dev/null)
  local calc_main_repo
  calc_main_repo=$(dirname "${abs_common}")

  # ID を git 出力から計算
  local wt_id main_id
  wt_id=${wt_root//\//-}
  main_id=${calc_main_repo//\//-}

  local wt_mem="${HOME}/.claude/projects/${wt_id}/memory"
  local main_mem="${HOME}/.claude/projects/${main_id}/memory"

  # 既存 memory dir を作成（ファイル含む）
  mkdir -p "${wt_mem}"
  echo "test content" > "${wt_mem}/test.md"
  mkdir -p "${main_mem}"

  # 関数を実呼び出し - 既存 dir を退避して symlink を構築
  run bash -c "HOME='${HOME}' source '$LIB_FILE' && ensure_worktree_memory_link '${wt_root}'"
  [ "$status" -eq 0 ]
  [ -L "${wt_mem}" ]
  [ "$(readlink "${wt_mem}")" = "${main_mem}" ]
  [ -f "${main_mem}/test.md" ]
  grep -q "test content" "${main_mem}/test.md"
  teardown_ensure_worktree
}

@test "ensure_worktree_memory_link: git -C 失敗（無効パス） → graceful" {
  setup_ensure_worktree
  run bash -c "HOME='${HOME}' source '$LIB_FILE' && ensure_worktree_memory_link '/nonexistent/path'"
  [ "$status" -eq 0 ]
  teardown_ensure_worktree
}

# =============================================================================
# _aitools_dir テスト
# =============================================================================

@test "_aitools_dir: ghq path が存在する → ghq path を返す" {
  local tmp_home
  tmp_home="$(mktemp -d)"
  mkdir -p "${tmp_home}/ghq/github.com/DaichiHoshina/ai-tools"

  run env HOME="${tmp_home}" bash -c "source '${LIB_FILE}' && _aitools_dir"
  [ "$status" -eq 0 ]
  [ "$output" = "${tmp_home}/ghq/github.com/DaichiHoshina/ai-tools" ]

  rm -rf "${tmp_home}"
}

@test "_aitools_dir: ghq 不在・symlink のみ存在 → symlink path を返す" {
  local tmp_home
  tmp_home="$(mktemp -d)"
  mkdir -p "${tmp_home}/ai-tools"
  # ghq path は作成しない

  run env HOME="${tmp_home}" bash -c "source '${LIB_FILE}' && _aitools_dir"
  [ "$status" -eq 0 ]
  [ "$output" = "${tmp_home}/ai-tools" ]

  rm -rf "${tmp_home}"
}

@test "_aitools_dir: ghq・symlink 両方不在 → ghq canonical path を返す (フォールバック)" {
  local tmp_home
  tmp_home="$(mktemp -d)"
  # どちらのディレクトリも作成しない

  run env HOME="${tmp_home}" bash -c "source '${LIB_FILE}' && _aitools_dir"
  [ "$status" -eq 0 ]
  [ "$output" = "${tmp_home}/ghq/github.com/DaichiHoshina/ai-tools" ]

  rm -rf "${tmp_home}"
}

@test "_aitools_dir: ghq・symlink 両方存在 → ghq を優先して返す" {
  local tmp_home
  tmp_home="$(mktemp -d)"
  mkdir -p "${tmp_home}/ghq/github.com/DaichiHoshina/ai-tools"
  mkdir -p "${tmp_home}/ai-tools"

  run env HOME="${tmp_home}" bash -c "source '${LIB_FILE}' && _aitools_dir"
  [ "$status" -eq 0 ]
  [ "$output" = "${tmp_home}/ghq/github.com/DaichiHoshina/ai-tools" ]

  rm -rf "${tmp_home}"
}

@test "ensure_worktree_memory_link: memory dir ソース側に既存 .md → 退避先で温存" {
  setup_ensure_worktree
  local main_repo="${TEST_WORKTREE_ROOT}/main"
  local wt_root="${TEST_WORKTREE_ROOT}/wt1"

  # main repo を初期化
  mkdir -p "${main_repo}"
  git -C "${main_repo}" init 2>/dev/null
  git -C "${main_repo}" config user.email "test@example.com" 2>/dev/null
  git -C "${main_repo}" config user.name "Test" 2>/dev/null

  # worktree を作成
  git -C "${main_repo}" worktree add "${wt_root}" 2>/dev/null

  # git の出力からパス情報を取得
  local abs_common
  abs_common=$(git -C "${wt_root}" rev-parse --git-common-dir 2>/dev/null)
  local calc_main_repo
  calc_main_repo=$(dirname "${abs_common}")

  # ID を git 出力から計算
  local wt_id main_id
  wt_id=${wt_root//\//-}
  main_id=${calc_main_repo//\//-}

  local wt_mem="${HOME}/.claude/projects/${wt_id}/memory"
  local main_mem="${HOME}/.claude/projects/${main_id}/memory"

  # worktree 側に memory dir と .md ファイルを作成
  mkdir -p "${wt_mem}"
  echo "old content" > "${wt_mem}/existing.md"
  mkdir -p "${main_mem}"

  # 関数を実呼び出し - 既存ファイルを main_mem に退避
  run bash -c "HOME='${HOME}' source '$LIB_FILE' && ensure_worktree_memory_link '${wt_root}'"
  [ "$status" -eq 0 ]
  [ -L "${wt_mem}" ]
  [ "$(readlink "${wt_mem}")" = "${main_mem}" ]
  [ -f "${main_mem}/existing.md" ]
  grep -q "old content" "${main_mem}/existing.md"
  teardown_ensure_worktree
}

# =============================================================================
# _is_memory_path: memory file 判定 (NG-DICTIONARY / private-name block skip 対象)
# canonical: CLAUDE.md § Memory write target + user 指示 2026-06-30
# =============================================================================

@test "is_memory_path: ~/ai-tools/memory/ 配下を memory として判定する" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/ai-tools/memory/foo.md'"
  [ "$status" -eq 0 ]
}

@test "is_memory_path: ~/.claude/projects/*/memory/ 配下を memory として判定する" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/.claude/projects/-Users-foo-bar/memory/baz.md'"
  [ "$status" -eq 0 ]
}

@test "is_memory_path: ~/.claude/agent-memory/ 配下を memory として判定する" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/.claude/agent-memory/agent-foo.md'"
  [ "$status" -eq 0 ]
}

@test "is_memory_path: .serena/memories/ 配下を memory として判定する" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '/some/project/.serena/memories/notes.md'"
  [ "$status" -eq 0 ]
}

@test "is_memory_path: 通常 path (~/ai-tools/claude-code/ 配下) は memory として判定しない" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/ai-tools/claude-code/CLAUDE.md'"
  [ "$status" -eq 1 ]
}

@test "is_memory_path: memory に似た path (~/ai-tools/memory-archive/) は memory として判定しない" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/ai-tools/memory-archive/old.md'"
  [ "$status" -eq 1 ]
}

@test "is_memory_path: ~/.claude/memory (projects なし) は memory として判定しない" {
  run bash -c "source '$LIB_FILE' && _is_memory_path '$HOME/.claude/memory/notes.md'"
  [ "$status" -eq 1 ]
}

# =============================================================================
# _aitools_recorded_root / _aitools_dir / _aitools_prefixes
# (.ai-tools-root 記録 file による repo root 解決)
# =============================================================================

@test "aitools_dir: 記録 file が有効なら記録済み root を最優先で返す" {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo/claude-code"
  echo "$tmp/repo" > "$tmp/root-file"
  run bash -c "source '$LIB_FILE' && AITOOLS_ROOT_FILE='$tmp/root-file' _aitools_dir"
  [ "$status" -eq 0 ]
  [ "$output" = "$tmp/repo" ]
  rm -rf "$tmp"
}

@test "aitools_dir: 記録 file の root が実在しなければ fallback path を返す" {
  local tmp
  tmp="$(mktemp -d)"
  echo "$tmp/nonexistent" > "$tmp/root-file"
  run bash -c "source '$LIB_FILE' && AITOOLS_ROOT_FILE='$tmp/root-file' _aitools_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == "$HOME/"* ]]
  rm -rf "$tmp"
}

@test "aitools_dir: 記録 file 不在でも従来の fallback で動作する" {
  run bash -c "source '$LIB_FILE' && AITOOLS_ROOT_FILE='/nonexistent/root-file' _aitools_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == "$HOME/"* ]]
}

@test "aitools_prefixes: 記録済み root が prefix list の先頭に入る" {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo/claude-code"
  echo "$tmp/repo" > "$tmp/root-file"
  run bash -c "source '$LIB_FILE' && AITOOLS_ROOT_FILE='$tmp/root-file' _aitools_prefixes | head -1"
  [ "$status" -eq 0 ]
  [ "$output" = "$tmp/repo/" ]
  rm -rf "$tmp"
}

@test "is_aitools_path: 記録済み root 配下の path を ai-tools 配下と判定する" {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/repo/claude-code"
  echo "$tmp/repo" > "$tmp/root-file"
  run bash -c "source '$LIB_FILE' && AITOOLS_ROOT_FILE='$tmp/root-file' _is_aitools_path '$tmp/repo/claude-code/CLAUDE.md'"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

# =============================================================================
# _rotate_log_if_needed: log rotation 共通関数
# =============================================================================

@test "rotate_log_if_needed: 存在しない file は no-op で 0 返し" {
  local tmpdir; tmpdir="$(mktemp -d)"
  run bash -c "source '$LIB_FILE' && _rotate_log_if_needed '${tmpdir}/absent.log'"
  [ "$status" -eq 0 ]
  [ ! -e "${tmpdir}/absent.log" ]
  [ -z "$(ls "${tmpdir}"/absent.log.*.bak 2>/dev/null)" ]
  rm -rf "$tmpdir"
}

@test "rotate_log_if_needed: 閾値以下の file は rotation しない" {
  local tmpdir; tmpdir="$(mktemp -d)"
  local log="${tmpdir}/small.log"
  printf 'hello\n' > "$log"
  run bash -c "source '$LIB_FILE' && _rotate_log_if_needed '$log'"
  [ "$status" -eq 0 ]
  [ -f "$log" ]
  [ -z "$(ls "${tmpdir}"/small.log.*.bak 2>/dev/null)" ]
  rm -rf "$tmpdir"
}

@test "rotate_log_if_needed: 閾値超えで .bak rename する" {
  local tmpdir; tmpdir="$(mktemp -d)"
  local log="${tmpdir}/big.log"
  # _TH_LOG_MAX_BYTES=1048576 を超えるサイズ (1MB + 1B) を生成
  dd if=/dev/zero of="$log" bs=1024 count=1025 2>/dev/null
  run bash -c "source '$LIB_FILE' && _rotate_log_if_needed '$log'"
  [ "$status" -eq 0 ]
  [ ! -f "$log" ]
  local bak_count
  bak_count=$(ls "${tmpdir}"/big.log.*.bak 2>/dev/null | wc -l | tr -d ' ')
  [ "$bak_count" -eq 1 ]
  rm -rf "$tmpdir"
}

@test "rotate_log_if_needed: keep_bak_count=3 なら古い .bak を 3 世代まで残す" {
  local tmpdir; tmpdir="$(mktemp -d)"
  local log="${tmpdir}/rot.log"
  # 既存 .bak を 4 個先置き (古い順)
  touch -t 202001010001 "${tmpdir}/rot.log.20200101000100.bak"
  touch -t 202001010002 "${tmpdir}/rot.log.20200101000200.bak"
  touch -t 202001010003 "${tmpdir}/rot.log.20200101000300.bak"
  touch -t 202001010004 "${tmpdir}/rot.log.20200101000400.bak"
  dd if=/dev/zero of="$log" bs=1024 count=1025 2>/dev/null
  run bash -c "source '$LIB_FILE' && _rotate_log_if_needed '$log' 3"
  [ "$status" -eq 0 ]
  [ ! -f "$log" ]
  # 新規 rotation で 1 個増えたが keep=3 で古い側から 2 個削除される (計 5 - 2 = 3)
  local bak_count
  bak_count=$(ls "${tmpdir}"/rot.log.*.bak 2>/dev/null | wc -l | tr -d ' ')
  [ "$bak_count" -eq 3 ]
  # 最古 (20200101000100) は削除されている
  [ ! -e "${tmpdir}/rot.log.20200101000100.bak" ]
  rm -rf "$tmpdir"
}
