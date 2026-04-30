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
  unset TEST_TMPDIR
}

@test "send_stop_notification: terminal-notifier に title/message を渡す" {
  setup_send_stop_notification
  local input='{"last_assistant_message":"test message","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input' '' 'Glass'" 2>/dev/null
  sleep 0.5  # バックグラウンドプロセス完了を待つ
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  grep -q "test message" "${TEST_TMPDIR}/terminal-notifier.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: メッセージが 80 文字超なら truncate される" {
  setup_send_stop_notification
  local long_msg=$(printf 'x%.0s' {1..100})  # 100文字
  local input="{\"last_assistant_message\":\"${long_msg}\",\"cwd\":\"/tmp/project\"}"
  bash -c "source '$LIB_FILE' && send_stop_notification '$input' '' 'Glass'" 2>/dev/null
  sleep 0.5  # バックグラウンド完了を待つ
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  # Log には最初の 80 文字 + "..." が含まれる
  grep -q "xxx..." "${TEST_TMPDIR}/terminal-notifier.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: NTFY_TOPIC がなければ curl は呼ばれない" {
  setup_send_stop_notification
  unset CLAUDE_NTFY_TOPIC 2>/dev/null || true
  local input='{"last_assistant_message":"test","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  # curl.log が生成されない（呼ばれていない）
  [ ! -f "${TEST_TMPDIR}/curl.log" ]
  teardown_send_stop_notification
}

@test "send_stop_notification: NTFY_TOPIC があれば curl で ntfy.sh を叩く" {
  setup_send_stop_notification
  export CLAUDE_NTFY_TOPIC="test-topic"
  local input='{"last_assistant_message":"hello","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.5  # バックグラウンド完了を待つ
  [ -f "${TEST_TMPDIR}/curl.log" ]
  grep -q "ntfy.sh" "${TEST_TMPDIR}/curl.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: terminal-notifier が PATH にないなら graceful" {
  setup_send_stop_notification
  # stub を削除
  rm "${TEST_TMPDIR}/terminal-notifier"
  local input='{"last_assistant_message":"test","cwd":"/tmp/project"}'
  run bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>&1
  [ "$status" -eq 0 ]
  teardown_send_stop_notification
}

@test "send_stop_notification: 空メッセージでも crash しない" {
  setup_send_stop_notification
  local input='{"last_assistant_message":"","cwd":"/tmp/project"}'
  run bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>&1
  [ "$status" -eq 0 ]
  teardown_send_stop_notification
}

@test "send_stop_notification: default message を使う（last_assistant_message なし）" {
  setup_send_stop_notification
  local input='{"cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input'" 2>/dev/null
  sleep 0.5  # バックグラウンド完了を待つ
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  grep -q "作業が完了しました" "${TEST_TMPDIR}/terminal-notifier.log"
  teardown_send_stop_notification
}

@test "send_stop_notification: title_suffix が付与される" {
  setup_send_stop_notification
  local input='{"last_assistant_message":"msg","cwd":"/tmp/project"}'
  bash -c "source '$LIB_FILE' && send_stop_notification '$input' '[SUCCESS]'" 2>/dev/null
  sleep 0.5  # バックグラウンド完了を待つ
  [ -f "${TEST_TMPDIR}/terminal-notifier.log" ]
  grep -q "\[SUCCESS\]" "${TEST_TMPDIR}/terminal-notifier.log"
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
