#!/usr/bin/env bats
# =============================================================================
# BATS Tests for hooks/stop.sh
# raw tool-call XML guard (応答本文に生のツール呼び出し痕跡があれば decision:block)
# のユニットテスト。検出 pattern: <invoke name= / <parameter name= / antml: 接頭辞 / function_calls
# =============================================================================

setup() {
  load "../../helpers/common"
  export PROJECT_ROOT
  export HOOK_FILE="${PROJECT_ROOT}/hooks/stop.sh"
  setup_test_tmpdir
  # stop.sh は HOME/.claude/logs/ へ stderr を飛ばすため HOME を差し替え
  export HOME="${TEST_TMPDIR}"
  mkdir -p "${TEST_TMPDIR}/.claude/logs"
}

teardown() {
  teardown_test_tmpdir
}

# last_assistant_message を渡して decision を取り出す。
# JSON は jq -n で安全に組む (literal を直書きすると JSON 破損する)
_decision() {
  local msg="$1"
  jq -n --arg m "$msg" '{last_assistant_message:$m, cwd:"/tmp"}' \
    | bash "${HOOK_FILE}" 2>/dev/null \
    | jq -r '.decision // "PASS"'
}

# 検出対象 literal は変数で組み立て、bats file 自体に生 XML を含めない
# (この file 自体が将来 hook の検査対象になっても誤爆させないため)
LT='<'

# =============================================================================
# block ケース: raw tool-call XML を検出する
# =============================================================================

@test "stop: invoke タグを含む応答は block" {
  [[ "$(_decision "count ${LT}invoke name=\"Edit\">foo")" == "block" ]]
}

@test "stop: parameter タグを含む応答は block" {
  [[ "$(_decision "${LT}parameter name=\"file_path\">/tmp/x")" == "block" ]]
}

@test "stop: antml:invoke タグを含む応答は block" {
  [[ "$(_decision "${LT}antml:invoke name=\"Bash\">")" == "block" ]]
}

@test "stop: function_calls タグを含む応答は block" {
  [[ "$(_decision "${LT}antml:function_calls>")" == "block" ]]
}

# =============================================================================
# PASS ケース: 通常 prose は素通し (誤爆させない)
# =============================================================================

@test "stop: 通常の日本語 prose は PASS" {
  [[ "$(_decision "実装完了。テスト通過した。")" == "PASS" ]]
}

@test "stop: name= を含む説明文は PASS (invoke/parameter でない)" {
  [[ "$(_decision "function の name= 引数を説明した")" == "PASS" ]]
}

@test "stop: invoke/parameter 以外の XML タグ説明は PASS" {
  [[ "$(_decision "例: ${LT}div name=\"x\"> は HTML タグ")" == "PASS" ]]
}

# =============================================================================
# block 時の JSON 形状: decision と reason が両方そろう
# =============================================================================

@test "stop: block 時は decision と reason を両方出力する" {
  local out
  out=$(jq -n --arg m "${LT}invoke name=\"Edit\">x" '{last_assistant_message:$m, cwd:"/tmp"}' \
    | bash "${HOOK_FILE}" 2>/dev/null)
  echo "${out}" | jq -e '.decision == "block"' >/dev/null
  echo "${out}" | jq -e '.reason | length > 0' >/dev/null
}
