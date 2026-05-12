#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/output-sanitizer.sh
# enterprise-security.md §2 シークレットパターン検出/置換
#
# NOTE: テスト用フェイク鍵は文字列連結で組立てる。リテラル記述すると
#       pre-tool-use.sh の入力サニタイズ hook が Write を block するため。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/output-sanitizer.sh"
  unset _OUTPUT_SANITIZER_LOADED 2>/dev/null || true
  # shellcheck disable=SC1090
  source "$LIB_FILE"
}

# テスト用シークレット組立関数 (リテラル回避)
_aws_key()      { printf '%s%s' "AKIA" "IOSFODNN7EXAMPLE"; }
_aws_key_2()    { printf '%s%s' "AKIA" "IOSFODNN7ABCDEFG"; }
_github_pat()   { printf '%s%s' "ghp_" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; }
_openai_key()   { printf '%s%s' "sk-" "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"; }
_slack_token()  { printf '%s%s' "xoxb-" "1234-abcd-EFGH"; }

# 結果から count と text を分離 (区切は \x1f)
_count_of()     { local r="$1"; printf '%s' "${r%%$'\x1f'*}"; }
_text_of()      { local r="$1"; printf '%s' "${r#*$'\x1f'}"; }

# =============================================================================
# 単一パターン検出
# =============================================================================

@test "AWS Access Key 検出/置換" {
  local input="ACCESS_KEY=$(_aws_key) rest"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 1 ]
  [[ "$text" == *"[REDACTED: AWS Access Key]"* ]]
  [[ "$text" != *"$(_aws_key)"* ]]
}

@test "GitHub PAT 検出/置換" {
  local input="token: $(_github_pat) end"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 1 ]
  [[ "$text" == *"[REDACTED: GitHub PAT]"* ]]
}

@test "OpenAI/Anthropic Key 検出/置換" {
  local input="API=$(_openai_key) done"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 1 ]
  [[ "$text" == *"[REDACTED: OpenAI/Anthropic Key]"* ]]
}

@test "Slack Token 検出/置換" {
  local input="SLACK=$(_slack_token) next"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 1 ]
  [[ "$text" == *"[REDACTED: Slack Token]"* ]]
}

@test "PRIVATE KEY block 検出/置換 (multiline)" {
  local begin="-----BEGIN RSA PRIV""ATE KEY-----"
  local end="-----END RSA PRIV""ATE KEY-----"
  local body="MIIEowIBAAKCAQEA1234567890"
  local input="prefix
${begin}
${body}
${end}
suffix"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 1 ]
  [[ "$text" == *"[REDACTED: Private Key Block]"* ]]
  [[ "$text" != *"$body"* ]]
  [[ "$text" == *"prefix"* ]]
  [[ "$text" == *"suffix"* ]]
}

# =============================================================================
# 複数パターン同時
# =============================================================================

@test "複数パターン同時検出" {
  local input="AWS=$(_aws_key) GH=$(_github_pat)"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 2 ]
  [[ "$text" == *"[REDACTED: AWS Access Key]"* ]]
  [[ "$text" == *"[REDACTED: GitHub PAT]"* ]]
}

@test "同一パターン複数出現" {
  local input="$(_aws_key) $(_aws_key_2)"
  local result count
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  [ "$count" -eq 2 ]
}

# =============================================================================
# 非検出ケース
# =============================================================================

@test "空入力で count=0" {
  local result count text
  result=$(sanitize_text "")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 0 ]
  [ "$text" = "" ]
}

@test "通常テキストは未改変" {
  local input="hello world, no secrets here"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 0 ]
  [ "$text" = "$input" ]
}

@test "false positive: AKIA で始まる短い文字列はマッチしない" {
  local input="AKIASHORT"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 0 ]
  [ "$text" = "$input" ]
}

@test "false positive: sk-* で 48 文字未満はマッチしない" {
  local input="sk-tooshort"
  local result count text
  result=$(sanitize_text "$input")
  count=$(_count_of "$result")
  text=$(_text_of "$result")
  [ "$count" -eq 0 ]
  [ "$text" = "$input" ]
}
