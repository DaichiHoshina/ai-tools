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

**AI定型語**: 効果的に / シームレスに / 革新的な / 素晴らしい / 強力な / より良い / 〜を実現します / 〜を提供します / 〜を可能にします / 〜することができます / ご紹介します / ご覧ください / 〜いただけます / 重要なポイント / 注目すべき点 / 本機能は / 本ドキュメントは / 本記事では / 本稿では〜について述べる / 包括的な / 堅牢な / 柔軟な / スケーラブルな / 最適化 / 影響なし / 収まる / 外挿 / 余裕大 / 無視可 / 無視可能 / 懸念解消 / 全観点 / 判定確定 / 漸近

**断定語 (warn-only)**: 完了 / 解消 / 見込み / クリア / 問題なし

**難読漢語 (block)**: 鑑みる / 勘案 / 斟酌 / 慮る / 忖度 / 俯瞰 / 俯瞰的 / 概観 / 敷衍 / 援用 / 惹起 / 奏功 / 踏襲 / 看做す / 然るに / 喫緊 / 肝要 / 要諦 / 蓋し

**弱い表現 (block)**: かもしれない / と思います / と思われる / 可能性がある

**冗長表現 (block)**: することができる / することが可能 / を行う / ということになる / であると言えます

**非日常英語 (block)**: leverage / utilize / facilitate / mitigate / comprehensive / robust / seamless / holistic / granular / rationale / paradigm

**AI段取り定型 (block)**: まず / まずは / 次に / 最後に / 続いて / 加えて / さらに / それでは / では〜していきます / まず〜しましょう / 次に〜します / 最後に〜します / 続いて〜します / 加えて〜します / さらに〜します / それでは〜していきましょう

**ヘッジ濫用 (block)**: 念のため / 一応 / 改めて確認 / 念のために / 改めまして / なお念のため / 一応念のため

**過剰丁寧 (block)**: ご確認ください / ご確認をお願いします / お手数ですが / 恐れ入りますが / お気軽に / ご不明な点 / お気軽にご相談 / ご一読いただけますと

**カタカナ造語禁止**: シームレス / シームレスに / ロバスト / スケーラブル / 直感的 / 直感的に / 革新的 / 革新的な / 包括的 / 包括的な / 堅牢 / 堅牢な / フレキシブル / インテリジェント / スマート / リッチ / モダン / クリーン / ハイレベル / ローレベル / クリティカル / クリティカルに / セキュア

**置換候補 (頻出)**: 踏襲→引き継ぐ / 鑑みる→踏まえる / 喫緊→直近 / leverage→活かす / utilize→使う / mitigate→緩和する
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

@test "warn-only: '完了' を含む text → GUARD_CLASS は空 + _check_term_list で hit 語が返る" {
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

    # warn-only 検出は _check_term_list が hit 語を stdout に返すこと自体で確認する
    # (_append_jp_quality_log は bats 実行中 log 汚染回避のため skip 設計、log 不在で正)
    hit=\$(_check_term_list 'デプロイ完了。' '断定語 (warn-only)') || true
    [[ \"\$hit\" = '完了' ]]
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

# =============================================================================
# Case 7: cache flag 自己削除 bug 修正 — 2 回目呼出で flag が存在し grep skip される
# =============================================================================

@test "cache: 2 回目の _assert_required_keys 呼出で flag file が存在したまま残る" {
  _make_ng_dict "$TEST_TMPDIR"
  # SESSION_ID を固定値にして bash -c サブシェル内と一致させる
  local sid='bats-cache-selfdelete-test'

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    export SESSION_ID='${sid}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    # 1 回目呼出 — flag file を生成させる
    _assert_required_keys

    # flag file が存在することを確認
    flag_count=\$(ls /tmp/claude-ngdict-keys-ok-${sid}-* 2>/dev/null | wc -l | tr -d ' ')
    [ \"\$flag_count\" -eq 1 ] || { echo \"1st call: flag_count=\$flag_count (expected 1)\" >&2; exit 1; }

    # 2 回目呼出 — per-process 変数 guard で即 return するが、flag も残っていること
    _assert_required_keys

    flag_count2=\$(ls /tmp/claude-ngdict-keys-ok-${sid}-* 2>/dev/null | wc -l | tr -d ' ')
    [ \"\$flag_count2\" -eq 1 ] || { echo \"2nd call: flag_count=\$flag_count2 (expected 1)\" >&2; exit 1; }
  "
  [ "$status" -eq 0 ]

  # cleanup
  rm -f "/tmp/claude-ngdict-keys-ok-${sid}-"*
}

@test "cache: mtime 更新後は旧 flag が削除され新 flag が生成される" {
  _make_ng_dict "$TEST_TMPDIR"
  local dict_path="${TEST_TMPDIR}/.claude/guidelines/writing/NG-DICTIONARY.md"
  local sid='bats-cache-mtime-test'

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    export SESSION_ID='${sid}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    # 1 回目: 初期 mtime で flag 生成
    _assert_required_keys
    old_flags=(\$(ls /tmp/claude-ngdict-keys-ok-${sid}-* 2>/dev/null))
    [ \"\${#old_flags[@]}\" -eq 1 ] || { echo \"initial flag count: \${#old_flags[@]}\" >&2; exit 1; }
    old_flag=\"\${old_flags[0]}\"

    # dict ファイルの mtime を未来に更新 (sleep 不要、touch -t で確実に変化)
    touch -t 203001010000 '${dict_path}'

    # per-process 変数をリセットして再呼出
    unset _assert_required_keys_done 2>/dev/null || true
    _assert_required_keys

    # 旧 flag が消えて新 flag が 1 つだけ存在する
    new_flags=(\$(ls /tmp/claude-ngdict-keys-ok-${sid}-* 2>/dev/null))
    [ \"\${#new_flags[@]}\" -eq 1 ] || { echo \"new flag count: \${#new_flags[@]}\" >&2; exit 1; }
    [ \"\${new_flags[0]}\" != \"\$old_flag\" ] || { echo 'flag unchanged after mtime update' >&2; exit 1; }
  "
  [ "$status" -eq 0 ]

  # cleanup
  rm -f "/tmp/claude-ngdict-keys-ok-${sid}-"*
}

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

# =============================================================================
# Case 8: 置換候補提示 — 踏襲を含む外向き text が block され ADDITIONAL_CONTEXT に引き継ぐ が含まれる
# =============================================================================

@test "置換候補: '踏襲' を含む text → block + ADDITIONAL_CONTEXT に '引き継ぐ' が含まれる" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon '前回の設計を踏襲した。' 'commit message'

    # block hit
    [ \"\${GUARD_CLASS}\" = 'Forbidden' ] || { echo \"GUARD_CLASS=\${GUARD_CLASS}\" >&2; exit 1; }

    # ADDITIONAL_CONTEXT に置換候補 '引き継ぐ' が含まれる
    printf '%s' \"\${ADDITIONAL_CONTEXT}\" | grep -q '引き継ぐ' || { echo \"ADDITIONAL_CONTEXT=\${ADDITIONAL_CONTEXT}\" >&2; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 9: AI 段取り定型 block — まず〜しましょう を含む text は block される
# =============================================================================

@test "block: AI段取り定型 'まず〜しましょう' を含む text → GUARD_CLASS=Forbidden" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon 'まず〜しましょう、次の手順に進む。' 'commit message'

    [ \"\${GUARD_CLASS}\" = 'Forbidden' ] || { echo \"GUARD_CLASS=\${GUARD_CLASS}\" >&2; exit 1; }
    printf '%s' \"\${MESSAGE}\" | grep -q 'まず〜しましょう' || { echo \"MESSAGE=\${MESSAGE}\" >&2; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 9b: AI 段取り定型 block — prefix 単体 'まず' を含む text は block される
# =============================================================================

@test "block: AI段取り定型 prefix 単体 'まず' を含む text → GUARD_CLASS=Forbidden" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon 'まず確認する。次に編集する。' 'commit message'

    [ \"\${GUARD_CLASS}\" = 'Forbidden' ] || { echo \"GUARD_CLASS=\${GUARD_CLASS}\" >&2; exit 1; }
    printf '%s' \"\${MESSAGE}\" | grep -q 'まず' || { echo \"MESSAGE=\${MESSAGE}\" >&2; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 10: ヘッジ濫用 block — 念のため を含む text は block される
# =============================================================================

@test "block: ヘッジ濫用 '念のため' を含む text → GUARD_CLASS=Forbidden" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon '念のため確認した。' 'commit message'

    [ \"\${GUARD_CLASS}\" = 'Forbidden' ] || { echo \"GUARD_CLASS=\${GUARD_CLASS}\" >&2; exit 1; }
    printf '%s' \"\${MESSAGE}\" | grep -q '念のため' || { echo \"MESSAGE=\${MESSAGE}\" >&2; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case 11: 過剰丁寧 block — ご確認ください を含む text は block される
# =============================================================================

@test "block: 過剰丁寧 'ご確認ください' を含む text → GUARD_CLASS=Forbidden" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon '修正済み、ご確認ください。' 'commit message'

    [ \"\${GUARD_CLASS}\" = 'Forbidden' ] || { echo \"GUARD_CLASS=\${GUARD_CLASS}\" >&2; exit 1; }
    printf '%s' \"\${MESSAGE}\" | grep -q 'ご確認ください' || { echo \"MESSAGE=\${MESSAGE}\" >&2; exit 1; }
  "
  [ "$status" -eq 0 ]
}

# =============================================================================
# Case: hyphen 連結識別子は NG 語の部分一致で block しない
# =============================================================================

@test "pass: hyphen 識別子 'comprehensive-review' を含む text → GUARD_CLASS を変更しない" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon 'comprehensive-review skill に coverage 規範を追加する。' 'commit message'

    [ -z \"\${GUARD_CLASS}\" ]
  "
  [ "$status" -eq 0 ]
}

@test "block: 裸の 'comprehensive' (非日常英語) は識別子除去後も block する" {
  _make_ng_dict "$TEST_TMPDIR"

  run bash -c "
    export HOME='${TEST_TMPDIR}'
    unset _assert_required_keys_done 2>/dev/null || true
    # shellcheck disable=SC1090
    source '${LIB_FILE}'

    GUARD_CLASS='' MESSAGE='' ADDITIONAL_CONTEXT='' TOOL_NAME=''
    _block_if_ai_jargon 'a comprehensive check を追加する。' 'commit message'

    [ \"\${GUARD_CLASS}\" = 'Forbidden' ]
  "
  [ "$status" -eq 0 ]
}
