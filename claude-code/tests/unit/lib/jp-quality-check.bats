#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/jp-quality-check.sh (smoke test)
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/jp-quality-check.sh"
  export TEST_TMPDIR="$(mktemp -d)"

  # 本番 NG-DICTIONARY.md を参照しないよう HOME を差し替え
  export HOME="$TEST_TMPDIR"

  # per-process cache / session guard をリセット
  unset _assert_required_keys_done 2>/dev/null || true
  # _term_list_cache は declare -A で宣言されるため source 後に対処
}

teardown() {
  rm -rf "$TEST_TMPDIR"
  unset _assert_required_keys_done 2>/dev/null || true
}

# =============================================================================
# Smoke: lib が source 可能 + 主要関数が defined
# =============================================================================

@test "smoke: lib が source 可能かつ主要関数 _check_term_list と _block_if_ai_jargon が defined" {
  # NG-DICTIONARY.md 不在時は _check_term_list / _assert_required_keys が即 return 0 する設計
  # → source 成功 + 関数定義の実在を exit code で verify する

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    # _check_term_list: 空テキスト → return 0 (NG-DICTIONARY.md 不在は skip)
    _check_term_list '' 'AI定型語'
    rc_check=\$?

    # _block_if_ai_jargon: 空テキスト → NG-DICTIONARY.md 不在で _assert_required_keys が return 0
    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon '' 'smoke-test'
    rc_block=\$?

    # 両関数が exit 0 を返すことを確認
    [ \"\$rc_check\" -eq 0 ] && [ \"\$rc_block\" -eq 0 ]
  "
  [ "$status" -eq 0 ]
}
