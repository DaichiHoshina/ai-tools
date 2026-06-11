#!/usr/bin/env bats
# =============================================================================
# BATS Tests for lib/jp-quality-check.sh
# =============================================================================

# ---------------------------------------------------------------------------
# テスト用 NG-DICTIONARY.md を生成するヘルパー
# 引数: dir (NG-DICTIONARY.md を置くディレクトリ)
# ---------------------------------------------------------------------------
_make_ng_dict() {
  local dir="$1"
  mkdir -p "${dir}/.claude/guidelines/writing"
  cat > "${dir}/.claude/guidelines/writing/NG-DICTIONARY.md" <<'NGDICT'
# NG 辞書 (test fixture)

**AI定型語**: 効果的に / シームレスに / 革新的な / 素晴らしい / 強力な / より良い / 〜を実現します / 〜を提供します / 〜を可能にします / 〜することができます / ご紹介します / ご覧ください / 〜いただけます / まず〜しましょう / 重要なポイント / 注目すべき点 / 本機能は / 本ドキュメントは / 本記事では / 本稿では〜について述べる / 包括的な / 堅牢な / 柔軟な / スケーラブルな / 最適化 / 影響なし / 収まる / 外挿 / 余裕大 / 無視可 / 無視可能 / 懸念解消 / 全観点 / 判定確定 / 漸近

**断定語 (warn-only)**: 完了 / 解消 / 見込み / クリア / 問題なし

**難読漢語 (block)**: 鑑みる / 勘案 / 斟酌 / 慮る / 忖度 / 俯瞰 / 俯瞰的 / 概観 / 敷衍 / 援用 / 惹起 / 奏功 / 踏襲 / 看做す / 然るに / 喫緊 / 肝要 / 要諦 / 蓋し

**弱い表現 (block)**: かもしれない / と思います / と思われる / 可能性がある

**冗長表現 (block)**: することができる / することが可能 / を行う / ということになる / であると言えます

**非日常英語 (block)**: leverage / utilize / facilitate / mitigate / comprehensive / robust / seamless / holistic / granular / rationale / paradigm

**カタカナ造語禁止**: シームレス / シームレスに / ロバスト / スケーラブル / 直感的 / 直感的に / 革新的 / 革新的な / 包括的 / 包括的な / 堅牢 / 堅牢な / フレキシブル / インテリジェント / スマート / リッチ / モダン / クリーン / ハイレベル / ローレベル / クリティカル / クリティカルに / セキュア
NGDICT
}

setup() {
  export PROJECT_ROOT
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export LIB_FILE="${PROJECT_ROOT}/lib/jp-quality-check.sh"
  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"

  # 本番 NG-DICTIONARY.md を参照しないよう HOME を差し替え
  export HOME="$TEST_TMPDIR"

  # per-process cache / session guard をリセット
  unset _assert_required_keys_done 2>/dev/null || true
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

# =============================================================================
# Case 1: block 正例 — 難読漢語を含む text は exit 2 + 該当語が stderr に出る
# =============================================================================

@test "block: 難読漢語 '鑑みる' を含む text → _block_if_ai_jargon が GUARD_CLASS=Forbidden をセット" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon 'この変更を鑑みると問題ない。' 'commit message'

    # block hit → GUARD_CLASS が Forbidden になる
    [ \"\${GUARD_CLASS}\" = 'Forbidden' ]
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 2: pass 正例 — NG 語を含まない text は GUARD_CLASS が空のまま
# =============================================================================

@test "pass: NG 語なし text → _block_if_ai_jargon は GUARD_CLASS を変更しない" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon 'テストを追加してバグを修正した。' 'commit message'

    # block なし → GUARD_CLASS が空のまま
    [ -z \"\${GUARD_CLASS}\" ]
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 3: warn-only 正例 — 断定語は exit 0 + warning ログが書き込まれる
# =============================================================================

@test "warn-only: '完了' を含む text → GUARD_CLASS は空 + ログに warn が記録される" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon 'デプロイ完了。' 'commit message'

    # warn-only → block しない (GUARD_CLASS 空のまま)
    [ -z \"\${GUARD_CLASS}\" ] || exit 1

    # warn ログが書き込まれている
    log_file=\"\${HOME}/.claude/logs/jp-quality-block.log\"
    [ -f \"\${log_file}\" ] || exit 1
    grep -q 'warn' \"\${log_file}\"
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 4: コード block 内 NG 語除外 — ``` で囲んだ語は検出しない
# =============================================================================

@test "code block 除外: fenced code block 内の NG 語は block しない" {
  _make_ng_dict "$TEST_TMPDIR"

  # fenced code block テキストをファイルに書き出してスクリプトに渡す
  # (bash -c 内でのバックティックエスケープ問題を回避)
  # 本文に NG 語 (クリーン等) が混入しないよう plain な文言を使う
  local text_file="${TEST_TMPDIR}/code_block_text.txt"
  printf '%s\n' \
    '以下のコードを参照。' \
    '```' \
    '# 鑑みる: この変数はレガシー実装' \
    'x = leverage(y)' \
    '```' \
    '本文は正常だ。' > "$text_file"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    text=\$(cat '${text_file}')
    _block_if_ai_jargon \"\$text\" 'commit message'

    # code block 内のみに NG 語 → block しない
    [ -z \"\${GUARD_CLASS}\" ]
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 5: 複数 category 同時 hit — 難読漢語 + 非日常英語が両方 MESSAGE に含まれる
# =============================================================================

@test "複数 category: 難読漢語 + 非日常英語が同時 hit → MESSAGE に両語が含まれる" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon '鑑みると leverage が必要だ。' 'commit message'

    # block hit
    [ \"\${GUARD_CLASS}\" = 'Forbidden' ] || exit 1

    # MESSAGE に両 category の語が含まれる
    printf '%s' \"\${MESSAGE}\" | grep -q '鑑みる' || exit 1
    printf '%s' \"\${MESSAGE}\" | grep -q 'leverage'
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 6: NG-DICTIONARY.md 不存在 → graceful fail (exit 0、block しない)
# =============================================================================

@test "NG-DICTIONARY.md 不存在: _check_term_list は graceful fail で exit 0" {
  # TEST_TMPDIR には NG-DICTIONARY.md を置かない (HOME = TEST_TMPDIR のまま)

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    # NG-DICTIONARY.md 不在 → _check_term_list は return 0
    _check_term_list '鑑みる leverage シームレス' 'AI定型語'
    rc=\$?
    [ \"\$rc\" -eq 0 ]
  "
  [ "$status" -eq 0 ]
}
