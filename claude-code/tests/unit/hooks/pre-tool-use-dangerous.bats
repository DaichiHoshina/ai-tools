#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh — detect_dangerous_patterns
# 機密リテラル / SSRF / SQL injection / credential 検出
# 分割元: tests/unit/hooks/pre-tool-use.bats
# 注: hook が検出するパターンを文字列として書くと自身の編集がブロックされるため、
#     リテラルは bash 連結 "AB""CD" で分割して書く
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

_run_edit_hook() {
  local input
  input=$(jq -n --arg fp "$1" --arg c "$2" '{file_path: $fp, new_string: $c}')
  invoke_hook "Edit" "$input"
}

_run_write_hook() {
  local input
  input=$(jq -n --arg fp "$1" --arg c "$2" '{file_path: $fp, content: $c}')
  invoke_hook "Write" "$input"
}

# bats run で hook 実行（exit 2 を捕捉するため）
_run_hook_blocking() {
  local input
  input=$(jq -n --arg fp "$1" --arg c "$2" '{file_path: $fp, new_string: $c}')
  invoke_hook_run "Edit" "$input"
}

@test "detect_dangerous: 通常編集は警告なし" {
  # Edit の静的 header message は削除済 (noise)。危険パターン警告が無いことだけ確認する
  result=$(_run_edit_hook "/tmp/x.txt" "hello world")
  msg=$(get_system_message "$result")
  [[ ! "$msg" =~ "機密情報" ]]
  [[ ! "$msg" =~ "危険パターン" ]]
}

@test "detect_dangerous: AWS Access Key リテラルは Forbidden（exit 2）" {
  local key="AKI""A0123456789ABCDEF"
  _run_hook_blocking "/tmp/x.py" "k=${key}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "AWS Access Key" ]]
  [[ "$output" =~ "機密情報" ]]
}

@test "detect_dangerous: GitHub PAT リテラルは Forbidden" {
  local pat="ghp""_abcdefghij1234567890ABCDEFGHIJ123456"
  _run_hook_blocking "/tmp/x.py" "t=${pat}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "GitHub PAT" ]]
}

@test "detect_dangerous: sk- API key リテラルは Forbidden" {
  local k="sk""-abcdefghij0123456789ABCDEFGHIJ0123456789ABCD"
  _run_hook_blocking "/tmp/x.py" "k=${k}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "sk-" ]]
}

@test "detect_dangerous: Slack token は Forbidden" {
  local t="xox""b-1234567890-abcdefghij1234567890"
  _run_hook_blocking "/tmp/x.py" "tok=${t}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Slack" ]]
}

@test "detect_dangerous: PRIVATE KEY block は Forbidden" {
  local pk_begin="-----BEGIN RSA PRIVATE"" KEY-----"
  local pk_end="-----END RSA PRIVATE"" KEY-----"
  _run_hook_blocking "/tmp/k" "${pk_begin}\\nMIIE\\n${pk_end}"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Private key" ]]
}

@test "detect_dangerous: SSRF AWS metadata IP は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.py" "url = http://169.254.169.254/latest/meta-data/")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SSRF cloud metadata" ]]
}

@test "detect_dangerous: GCP metadata host は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.py" "u = http://metadata.google.internal/")
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SSRF cloud metadata" ]]
}

@test "detect_dangerous: SQL f-string interpolation は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.py" 'q = f"SELECT * FROM users WHERE id={user_id}"')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SQL string interpolation" ]]
}

@test "detect_dangerous: SQL template literal は Boundary 警告" {
  result=$(_run_write_hook "/tmp/x.ts" 'q = "SELECT * FROM users WHERE id=${userId}"')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "SQL template literal" ]]
}

@test "detect_dangerous: credential ハードコード代入は Boundary 警告" {
  result=$(_run_edit_hook "/tmp/x.py" 'api_key = "abcdefghij1234567890ABCDEF"')
  msg=$(get_system_message "$result")
  [[ "$msg" =~ "Hardcoded credential" ]]
}

@test "detect_dangerous: MultiEdit でも検出される" {
  local key="AKI""A0123456789ABCDEF"
  local input
  input=$(jq -n --arg k "$key" '{
    tool_name: "MultiEdit",
    tool_input: {
      file_path: "/tmp/x.py",
      edits: [{old_string: "x=1", new_string: ("x=" + $k)}]
    }
  }')
  run bash -c 'echo "$1" | bash "$2"' _ "$input" "$HOOK_FILE"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "AWS Access Key" ]]
}
