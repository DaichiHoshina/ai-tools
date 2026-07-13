#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/pre-tool-use.sh
# _check_parent_prep_missing / _check_colloquial_trigger_missing_delegation
# 分割元: tests/integration/hooks-integration.bats (L590-724 相当)
# unit 相当 (source + 関数直呼び) のため tests/unit/hooks/ 配下に移動
# =============================================================================

bats_require_minimum_version 1.5.0

setup() {
  # PROJECT_ROOT を設定
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export HOOKS_DIR="${PROJECT_ROOT}/hooks"
  # 共有 helper: HOME を tmp dir に隔離 (本番ログ汚染防止)
  load "../../helpers/common"
  setup_home_isolated
}

teardown() {
  teardown_home_isolated
}

# =============================================================================
# _check_parent_prep_missing Tests
# =============================================================================

# 600 word の long prompt を生成するヘルパー (target/verify/DoD/file:line 未出現)
_make_long_prompt_no_prep() {
  # 600 word を超える plain text (prep keyword なし)
  local word="lorem"
  local prompt=""
  for i in $(seq 1 600); do
    prompt="${prompt}${word} "
  done
  echo "$prompt"
}

@test "_check_parent_prep_missing: detects missing prep in ≥500 word prompt" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  local long_prompt
  long_prompt=$(_make_long_prompt_no_prep)
  # 関数単体を source して exit code を直接 assert
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_parent_prep_missing '${long_prompt}'"
  # exit 0 = missing 検出
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: passes when prompt contains file:line pattern" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 600 word + src/foo.ts:42 を含む prompt
  local long_prompt
  long_prompt=$(_make_long_prompt_no_prep)
  long_prompt="${long_prompt} src/foo.ts:42"
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_parent_prep_missing '${long_prompt}'"
  # exit 1 = 事前準備済 (warn しない)
  [ "$status" -eq 1 ]
}

@test "_check_parent_prep_missing: passes when prompt is short (<500 words)" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 100 word のみ (target 未出現でも short prompt は対象外)
  local short_prompt=""
  for i in $(seq 1 100); do
    short_prompt="${short_prompt}lorem "
  done
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_parent_prep_missing '${short_prompt}'"
  # exit 1 = 短 prompt、warn しない
  [ "$status" -eq 1 ]
}

@test "_check_parent_prep_missing: does not treat English 'target' in prose as prep" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 600 word + natural "target" mention but no file:line / label 付き keyword
  local long_prompt
  long_prompt=$(printf "We targeted the service layer for refactoring. %.0s" {1..30})
  long_prompt="${long_prompt} $(_make_long_prompt_no_prep)"
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_parent_prep_missing \"\$1\"" _ "${long_prompt}"
  # exit 0 = missing 検出 — natural 'target' word should NOT suppress warn
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: does not treat English 'verify' in prose as prep" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 600 word + natural "verify" mention but no file:line / label 付き keyword
  local long_prompt
  long_prompt=$(printf "Please verify the output carefully. %.0s" {1..30})
  long_prompt="${long_prompt} $(_make_long_prompt_no_prep)"
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_parent_prep_missing \"\$1\"" _ "${long_prompt}"
  # exit 0 = missing 検出 — natural 'verify' word should NOT suppress warn
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: label-prefixed 'verify cmd:' DOES suppress warn" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # label 付き形式は事前準備済とみなす
  local long_prompt
  long_prompt="$(_make_long_prompt_no_prep) verify cmd: bats tests/foo.bats"
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_parent_prep_missing \"\$1\"" _ "${long_prompt}"
  # exit 1 = 事前準備済 (warn しない) — label 付き verify cmd は trigger 抑制
  [ "$status" -eq 1 ]
}

@test "_check_parent_prep_missing: does NOT treat URL with port as file:line" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # URL+port (https://example.com:8080) は file:line ではないので warn 抑制しない
  local long_prompt
  long_prompt="$(_make_long_prompt_no_prep) See https://example.com:8080/docs for details"
  run bash -c "source '$HOOK_FILE' <<< '{}' && _check_parent_prep_missing \"\$1\"" _ "$long_prompt"
  # exit 0 = missing 検出 — URL host:port は file:line と判定しない
  [ "$status" -eq 0 ]
}

@test "_check_parent_prep_missing: file:line at line start IS detected" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 行頭の file:line は正常検出
  local long_prompt
  long_prompt="src/foo.ts:42 $(_make_long_prompt_no_prep)"
  run bash -c "source '$HOOK_FILE' <<< '{}' && _check_parent_prep_missing \"\$1\"" _ "$long_prompt"
  # exit 1 = 事前準備済 (warn しない)
  [ "$status" -eq 1 ]
}

# self-verify red 化手順 (実装者必須実行):
# 1. _check_parent_prep_missing 関数本体を `return 1` のみに置換 → case "detects missing" (positive) が FAIL
# 2. regex を旧 too-broad pattern (target|verify|DoD|:[0-9]+|file:line) に戻す
#    → "does not treat English 'target' in prose" / "does not treat English 'verify' in prose" の 2 case が FAIL
#    (false-negative 再現: 自然言語 target/verify で trigger 抑制されてしまう)
# 3. 修正版 regex に戻す → 全件 PASS
# 4. URL false-negative: regex の境界 (^|[[:space:]]) を除去 → "URL with port" test が FAIL
#    (example.com:8080 が file:line として誤判定 → exit 1 になる)
# 5. 修正版に戻す → 全件 PASS
# pass-by-coincidence 排除確認済

# =============================================================================
# _check_colloquial_trigger_missing_delegation Tests
# =============================================================================

@test "_check_colloquial_trigger: detects お任せ without file:line" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 口語起動 marker (お任せ) + file:line なし → warn 対象 (exit 0)
  local prompt="お任せで全部やっておいて。あとはうまくやってほしい。作業はそちらに委ねる。"
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_colloquial_trigger_missing_delegation \"\$1\"" _ "${prompt}"
  [ "$status" -eq 0 ]
}

@test "_check_colloquial_trigger: does not warn when file:line is explicit" {
  local HOOK_FILE="${HOOKS_DIR}/pre-tool-use.sh"
  # 「全部」を含むが file:line 明示あり → warn しない (exit 1)
  local prompt="全部修正して欲しい。対象: src/hooks/pre-tool-use.sh:670 の関数を更新する。verify cmd: shellcheck を実行する。"
  run bash -c "source '${HOOK_FILE}' <<< '{}' && _check_colloquial_trigger_missing_delegation \"\$1\"" _ "${prompt}"
  [ "$status" -eq 1 ]
}

# self-verify red 化手順 (_check_colloquial_trigger 用):
# 1. 関数本体を `return 1` のみに置換 → "detects お任せ" (positive) が FAIL
# 2. 関数本体を `return 0` のみに置換 → "does not warn when file:line is explicit" (false-positive) が FAIL
# 3. 元の実装に戻す → 全件 PASS
# pass-by-coincidence 排除確認済
