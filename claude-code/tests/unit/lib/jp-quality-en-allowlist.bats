#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/jp-quality/block-checks.sh:_check_unknown_en_terms
# 許可一覧 (allowed-en-terms.txt) 外の英単語 warn 検査
# =============================================================================

_make_allowlist() {
  local dir="$1"
  mkdir -p "${dir}/.claude/guidelines/writing"
  cat > "${dir}/.claude/guidelines/writing/allowed-en-terms.txt" <<'ALLOW'
# test fixture
commit
hook
lint
push
test
ALLOW
}

setup() {
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/jp-quality-check.sh"
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"
  export HOME="$TEST_TMPDIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

_run_check() {
  local text="$1"
  run bash -c "
    export HOME='${TEST_TMPDIR}'
    # shellcheck disable=SC1090
    source '${LIB_FILE}'
    _check_unknown_en_terms \"\$1\"
  " _ "$text"
}

@test "許可一覧の語のみ → 出力なし" {
  _make_allowlist "$TEST_TMPDIR"
  _run_check "commit して push した。test は通った。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "一覧外の語 probe / sweep → その語だけ出力される" {
  _make_allowlist "$TEST_TMPDIR"
  _run_check "commit の前に probe で sweep した。"
  [ "$status" -eq 0 ]
  [[ "$output" == *"probe"* ]]
  [[ "$output" == *"sweep"* ]]
  [[ "$output" != *"commit"* ]]
}

@test "backtick 内の一覧外語は対象外" {
  _make_allowlist "$TEST_TMPDIR"
  _run_check '`probe` を実行して commit した。'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "code block 内の一覧外語は対象外" {
  _make_allowlist "$TEST_TMPDIR"
  _run_check '実行する。
```bash
probe --sweep
```
以上だ。'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "大文字含み (固有名詞 / 略語) は対象外" {
  _make_allowlist "$TEST_TMPDIR"
  _run_check "Serena と GitHub と API と McpServer を使う。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "複合識別子 (path / kebab / snake) は対象外" {
  _make_allowlist "$TEST_TMPDIR"
  _run_check "foo/probe.sh と pre-tool-use と session_id を見た。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "2 字以下の語は対象外" {
  _make_allowlist "$TEST_TMPDIR"
  _run_check "jq と ms と wt を使う。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "一覧 file 不在 → graceful skip で出力なし" {
  _run_check "probe を実行した。"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "JP_EN_ALLOWLIST_CHECK=0 → 検査 off" {
  _make_allowlist "$TEST_TMPDIR"
  run bash -c "
    export HOME='${TEST_TMPDIR}'
    export JP_EN_ALLOWLIST_CHECK=0
    # shellcheck disable=SC1090
    source '${LIB_FILE}'
    _check_unknown_en_terms 'probe を実行した。'
  "
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_chat_quality_check 統合: 一覧外語が warn message に載る" {
  _make_allowlist "$TEST_TMPDIR"
  run bash -c "
    export HOME='${TEST_TMPDIR}'
    # shellcheck disable=SC1090
    source '${LIB_FILE}'
    mkdir -p \"${TEST_TMPDIR}/.claude/guidelines/writing\"
    printf '**AI定型語**: 効果的に\n' > \"${TEST_TMPDIR}/.claude/guidelines/writing/NG-DICTIONARY.md\"
    _chat_quality_check 'probe を実行した。'
    printf '%s' \"\${_CHAT_WARN_MSG}\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"probe"* ]]
  [[ "$output" == *"allowed-en-terms.txt"* ]]
}
