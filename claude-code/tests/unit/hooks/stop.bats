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
  # fixture は session_id なしで guard により notify skip されるが、実通知の誤発火を
  # 二重に防ぐため明示 OFF にする
  export CLAUDE_STOP_NOTIFY=0
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

# =============================================================================
# chat 応答 JP 文体検査 (decision:block / systemMessage warn)
# =============================================================================

# 最小 NG 辞書 fixture を差し替え HOME 配下へ生成する
_make_stop_ng_dict() {
  mkdir -p "${TEST_TMPDIR}/.claude/guidelines/writing"
  cat > "${TEST_TMPDIR}/.claude/guidelines/writing/NG-DICTIONARY.md" <<'NGDICT'
# NG 辞書 (stop test fixture)

**AI定型語**: 効果的に / 素晴らしい

**断定語 (warn-only)**: 見込み

**英語jargon (warn-only)**: canonical / salience

**難読漢語 (block)**: 鑑みる / 踏襲

**弱い表現 (block)**: かもしれない

**冗長表現 (block)**: することができる

**非日常英語 (block)**: leverage / robust

**AI段取り定型 (block)**: まずは

**ヘッジ濫用 (block)**: 念のため

**過剰丁寧 (block)**: ご確認ください

**カタカナ造語禁止**: シームレス / ロバスト

**置換候補 (頻出)**: 鑑みる→踏まえる
NGDICT
}

# msg を stop.sh へ渡して JSON 出力全体を返す (session_id は test 固定)
_stop_out() {
  local msg="$1"
  shift
  jq -n --arg m "$msg" --argjson extra "${1:-{\}}" \
    '{last_assistant_message:$m, cwd:"/tmp", session_id:"batsjpq"} + $extra' \
    | bash "${HOOK_FILE}" 2>/dev/null
}

@test "stop: chat 応答の難読漢語 '鑑みる' は block + reason に置換候補" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
  local out
  out=$(_stop_out "過去の経緯を鑑みると妥当だ。")
  printf '%s' "${out}" | jq -e '.decision == "block"' >/dev/null
  printf '%s' "${out}" | jq -e '.reason | contains("踏まえる")' >/dev/null
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
}

@test "stop: NG 語なしの chat 応答は PASS" {
  _make_stop_ng_dict
  [[ "$(_decision "テストは全て通過した。次は配布を実行する。")" == "PASS" ]]
}

@test "stop: stop_hook_active=true なら NG 語入りでも検査 skip で PASS" {
  _make_stop_ng_dict
  local out
  out=$(_stop_out "過去の経緯を鑑みると妥当だ。" '{"stop_hook_active":true}')
  printf '%s' "${out}" | jq -e 'has("decision") | not' >/dev/null
}

@test "stop: JP_QUALITY_STOP_CHECK=0 なら NG 語入りでも PASS (escape hatch)" {
  _make_stop_ng_dict
  local out
  out=$(jq -n '{last_assistant_message:"過去の経緯を鑑みると妥当だ。", cwd:"/tmp", session_id:"batsjpq"}' \
    | JP_QUALITY_STOP_CHECK=0 bash "${HOOK_FILE}" 2>/dev/null)
  printf '%s' "${out}" | jq -e 'has("decision") | not' >/dev/null
}

@test "stop: JP_QUALITY_BLOCK_OFF=1 なら block ではなく systemMessage warn に降格する" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
  local out
  out=$(jq -n '{last_assistant_message:"過去の経緯を鑑みると妥当だ。", cwd:"/tmp", session_id:"batsjpq"}' \
    | JP_QUALITY_BLOCK_OFF=1 bash "${HOOK_FILE}" 2>/dev/null)
  printf '%s' "${out}" | jq -e 'has("decision") | not' >/dev/null
  printf '%s' "${out}" | jq -e '.systemMessage | contains("鑑みる")' >/dev/null
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
}

@test "stop: backtick 内の NG 語は検査対象外で PASS" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
  local out
  out=$(_stop_out "\`robust\` という識別子を維持した。")
  printf '%s' "${out}" | jq -e 'has("decision") | not' >/dev/null
}

@test "stop: ヘッジ '念のため' は block (2026-07 昇格)" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
  local out
  out=$(_stop_out "念のため設定を確認した。")
  printf '%s' "${out}" | jq -e '.decision == "block"' >/dev/null
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
}

@test "stop: warn 系のみ ('見込み') は block せず systemMessage に warn + state file 生成" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-warn-batsjpq-*
  local out
  out=$(_stop_out "回復の見込みがある状態だ。")
  printf '%s' "${out}" | jq -e 'has("decision") | not' >/dev/null
  printf '%s' "${out}" | jq -e '.systemMessage | contains("chat 文体 warn")' >/dev/null
  # warn 還流用 state file が書かれている (次 turn の UserPromptSubmit が read-and-delete する)
  local warn_file
  warn_file=$(compgen -G "/tmp/claude-stop-jpq-warn-batsjpq-*" | head -1)
  [[ -n "${warn_file}" ]]
  [[ "$(cat "${warn_file}")" == *"見込み"* ]]
  rm -f /tmp/claude-stop-jpq-warn-batsjpq-*
}

@test "stop: 体言止め bullet 連発 (2 行) は語彙 hit ゼロでも block (構造昇格)" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
  local out
  out=$(_stop_out "- 実装を修正
- test を追加
本文は文として閉じている。")
  printf '%s' "${out}" | jq -e '.decision == "block"' >/dev/null
  printf '%s' "${out}" | jq -e '.reason | contains("体言止め")' >/dev/null
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
}

@test "stop: 体言止め bullet 単発は block せず warn に留まる (2026-07-18 緩和)" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-* /tmp/claude-stop-jpq-warn-batsjpq-*
  local out
  out=$(_stop_out "- 実装を修正
本文は文として閉じている。")
  printf '%s' "${out}" | jq -e 'has("decision") | not' >/dev/null
  printf '%s' "${out}" | jq -e '.systemMessage | contains("体言止め")' >/dev/null
  rm -f /tmp/claude-stop-jpq-count-batsjpq-* /tmp/claude-stop-jpq-warn-batsjpq-*
}

@test "stop: 100字超文は 1 文でも block (2026-07-18 昇格)" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
  local long
  long=$(printf 'あ%.0s' {1..105})
  local out
  out=$(_stop_out "${long}。")
  printf '%s' "${out}" | jq -e '.decision == "block"' >/dev/null
  printf '%s' "${out}" | jq -e '.reason | contains("100字超文")' >/dev/null
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
}

@test "stop: block 5 回到達で log-only 降格し jp-quality-block.log に 1 行残す" {
  _make_stop_ng_dict
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
  local log_file="${TEST_TMPDIR}/.claude/logs/jp-quality-block.log"
  rm -f "${log_file}"
  # _append_jp_quality_log は bats 実行中の log 汚染回避で BATS_TEST_FILENAME 有無を見て skip する設計のため、
  # この test だけ unset して log 書込を有効化する (log 先は TEST_TMPDIR 配下で隔離済)
  local i out
  for i in 1 2 3 4 5 6; do
    out=$(jq -n '{last_assistant_message:"念のため設定を確認した。", cwd:"/tmp", session_id:"batsjpq"}' \
      | env -u BATS_TEST_FILENAME bash "${HOOK_FILE}" 2>/dev/null)
  done
  printf '%s' "${out}" | jq -e 'has("decision") | not' >/dev/null
  printf '%s' "${out}" | jq -e '.systemMessage | contains("log-only 降格")' >/dev/null
  grep -q "log-only-downgrade" "${log_file}"
  rm -f /tmp/claude-stop-jpq-count-batsjpq-*
}
