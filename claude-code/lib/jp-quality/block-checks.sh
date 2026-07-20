#!/usr/bin/env bash
# NG 語 block / chat 文体検査関数群 (jp-quality-check.sh から抽出)
# source してから使用する。GUARD_CLASS / MESSAGE / ADDITIONAL_CONTEXT / TOOL_NAME を参照・変更する。
# term-extraction.sh / structural-checks.sh に依存する。

# 多重 source 防止
if [[ "${_JP_QUALITY_BLOCK_CHECKS_LOADED:-}" == "1" ]]; then
    return 0
fi
_JP_QUALITY_BLOCK_CHECKS_LOADED=1

# shellcheck source=structural-checks.sh
source "${BASH_SOURCE[0]%/*}/structural-checks.sh"

# 外向き text を AI語 + カタカナ造語チェックし、hit 時に Forbidden block をセットする
# 全 block category を一括収集して exit 2 + まとめて提示する (逐次 block 廃止)
# 呼び出し元: tool ごとの case 節
_block_if_ai_jargon() {
  local text="$1"
  local context_label="$2"  # "commit message" / "PR body" 等
  # 辞書全 key を 1 pass で cache 化してから sanity check (以降の _extract_term_list は fork 0)
  _preload_term_lists
  # 必須 key sanity check (session 内 cache 済なら即 return)
  _assert_required_keys

  # inject byte size 計測: 全 block list の合計抽出 byte 数を計算してログ出力
  local _inject_keys=("AI定型語" "カタカナ造語禁止" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)" "AI段取り定型 (block)" "ヘッジ濫用 (block)" "過剰丁寧 (block)")
  local _inject_total=0
  local _inject_key
  for _inject_key in "${_inject_keys[@]}"; do
    local _inject_terms
    _inject_terms=$(_extract_term_list "$_principles_file" "$_inject_key" 2>/dev/null || true)
    _inject_total=$(( _inject_total + ${#_inject_terms} ))
  done
  local _inject_status="ok"
  [[ "$_inject_total" -gt 1500 ]] && _inject_status="over"
  _append_jp_quality_inject_log "$context_label" "$_inject_total" "$_inject_status"

  # --- block category 定義 ---
  # 各要素: "key|label|guidance"
  # label: bats テスト互換の表示名 (例: "難読漢語 block")
  local _block_categories=(
    "AI定型語|AI定型語 block|AI定型語を削除または具体表現に置換してください"
    "カタカナ造語禁止|カタカナ造語 block|カタカナ造語を削除または説明的表現に置換してください"
    "難読漢語 (block)|難読漢語 block|難読漢語を平易な語に置換してください"
    "非日常英語 (block)|非日常英語 block|日常で使う英語または日本語に置換してください"
    "弱い表現 (block)|弱い表現 block|弱い表現を断定または「検証が必要」に置換してください"
    "冗長表現 (block)|冗長表現 block|冗長表現を短縮形に置換してください (例: することができる → できる、を行う → する)"
    "AI段取り定型 (block)|AI段取り定型 block|段取り定型を削除して内容を直接書いてください (まず/次に/最後に は番号 list で代替)"
    "ヘッジ濫用 (block)|ヘッジ濫用 block|ヘッジ語を削除して断定で書いてください (念のため/一応 は不要)"
    "過剰丁寧 (block)|過剰丁寧 block|過剰丁寧を削除して直接的に書いてください (ご確認ください → 確認する)"
  )

  # block hit: key → hit_words の連想配列
  declare -A _hit_by_key=()
  local _hit_words
  local _cat_entry _cat_key _cat_label _cat_guidance
  local _has_block=0

  for _cat_entry in "${_block_categories[@]}"; do
    _cat_key="${_cat_entry%%|*}"
    if ! _hit_words=$(_check_term_list "$text" "$_cat_key"); then
      _hit_by_key["${_cat_key}"]="${_hit_words}"
      _has_block=1
    fi
  done

  # warn-only チェック (block 有無に関係なく実行)
  local _warn_words=""
  if ! _warn_words=$(_check_term_list "$text" "断定語 (warn-only)"); then
    local _warn_list
    _warn_list=$(printf '%s' "$_warn_words" | tr '\n' ',' | sed 's/,$//')
    _append_jp_quality_log "$context_label" "$_warn_list" "warn"
  fi

  # 英語jargon warn-only: log に加えて additionalContext で書き直しを促す (block はしない)
  local _jargon_words=""
  local _jargon_msg=""
  if ! _jargon_words=$(_check_term_list "$text" "英語jargon (warn-only)"); then
    local _jargon_list
    _jargon_list=$(printf '%s' "$_jargon_words" | tr '\n' ',' | sed 's/,$//')
    _append_jp_quality_log "$context_label" "jargon: ${_jargon_list}" "warn"
    _jargon_msg="${ICON_WARNING:-▲} 英語jargon warn (${context_label}): ${_jargon_list} — 日本語で言える一般語は日本語化、識別子として使うなら backtick で囲む (NG-DICTIONARY.md §英語jargon)"
  fi

  # 構造的可読性 warn (連続漢字 / 読点)。block しない、additionalContext に追記
  local _struct_warn
  _struct_warn=$(_check_structural_quality "$text")
  # counts 版を直接呼ぶ ($() subshell だと _SS_* が親に残らないため wrapper は使えない)
  _check_sentence_structure_counts "$text" 0 0
  local _sent_warn=""
  (( _SS_TAIGEN > 0 )) && _sent_warn="${_sent_warn}体言止めbullet: ${_SS_TAIGEN}行 → 文として閉じる (〜する/〜した); "
  (( _SS_ARROW > 0 )) && _sent_warn="${_sent_warn}矢印チェーン: ${_SS_ARROW}行 → 文章に展開; "
  (( _SS_REP > 0 )) && _sent_warn="${_sent_warn}同一文末3連続: ${_SS_REP}箇所 → 文末を変える; "
  (( _SS_FLAT > 0 )) && _sent_warn="${_sent_warn}平坦 bullet ≥11 + 理由語含み: ${_SS_FLAT}group → 親子に組み替え (PRINCIPLES.md ## 箇条書き階層化); "
  (( _SS_TIME > 0 )) && _sent_warn="${_sent_warn}時限マーカー: ${_SS_TIME}件 (${_SS_TIME_SAMPLE}) → 時制中立表現に (pr-description.md ### 時限マーカー禁止); "
  (( _SS_STUFF > 0 )) && _sent_warn="${_sent_warn}括弧詰め込み: ${_SS_STUFF}件 (${_SS_STUFF_SAMPLE}) → 括弧の名詞羅列を本文の文に開く (PRINCIPLES.md ### 圧縮文を開く); "
  _sent_warn="${_sent_warn%; }"
  # 100字超文のみ block へ昇格 (2026-07-18)。改行 = 文境界修正で trailer / bullet 連結の誤爆源を除去済のため chat 経路と基準を揃えた
  local _struct_block=""
  (( _SS_LONG > 0 )) && _struct_block="100字超文: ${_SS_LONG}文 (冒頭: ${_SS_LONG_SAMPLE}…) → 句点で 2 文以上に分割する (修正例: 「Aを削り、Bを追加した」→「Aを削った。加えて Bを追加した。」)"
  if [[ -n "$_sent_warn" ]]; then
    _struct_warn="${_struct_warn:+${_struct_warn}; }${_sent_warn}"
  fi
  local _struct_msg=""
  if [[ -n "$_struct_warn" ]]; then
    _append_jp_quality_log "$context_label" "structural: ${_struct_warn}" "warn"
    _struct_msg="${ICON_WARNING:-▲} 可読性 warn (${context_label}): ${_struct_warn}"
  fi
  if [[ -n "$_jargon_msg" ]]; then
    if [[ -n "$_struct_msg" ]]; then
      _struct_msg="${_struct_msg}"$'\n'"${_jargon_msg}"
    else
      _struct_msg="${_jargon_msg}"
    fi
  fi

  # block なし → return (構造 warn があれば additionalContext に載せる)
  if [[ "$_has_block" -eq 0 && -z "$_struct_block" ]]; then
    if [[ -n "$_struct_msg" ]]; then
      if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
        ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_struct_msg}"
      else
        ADDITIONAL_CONTEXT="${_struct_msg}"
      fi
    fi
    return
  fi

  # --- 全 hit を一括集計してメッセージ構築 ---
  GUARD_CLASS="Forbidden"

  # 全 hit 用語をカンマ区切りで結合 (log 用)
  local _all_terms_list=""
  local _detail_lines=""
  for _cat_entry in "${_block_categories[@]}"; do
    _cat_key="${_cat_entry%%|*}"
    # label: 2番目フィールド (key|label|guidance から抽出)
    local _rest="${_cat_entry#*|}"
    _cat_label="${_rest%%|*}"
    _cat_guidance="${_rest#*|}"
    if [[ -v "_hit_by_key[${_cat_key}]" ]]; then
      local _wl
      _wl=$(printf '%s' "${_hit_by_key[${_cat_key}]}" | tr '\n' ',' | sed 's/,$//')
      if [[ -n "$_all_terms_list" ]]; then
        _all_terms_list="${_all_terms_list},${_wl}"
      else
        _all_terms_list="${_wl}"
      fi
      # _detail_lines に label を使う (bats テスト "難読漢語 block" 等と互換)
      # hit 語ごとに置換候補を調べて候補があれば "語 → 候補" を列挙する
      local _suggestion_lines=""
      local _sw
      while IFS= read -r _sw; do
        [[ -z "$_sw" ]] && continue
        local _sugg
        _sugg=$(_lookup_suggestion "$_sw")
        if [[ -n "$_sugg" ]]; then
          _suggestion_lines="${_suggestion_lines}    ${_sw} → ${_sugg}"$'\n'
        fi
      done < <(printf '%s\n' "${_hit_by_key[${_cat_key}]}")
      if [[ -n "$_suggestion_lines" ]]; then
        _detail_lines="${_detail_lines}  ${_cat_label}: [${_wl}] → ${_cat_guidance}"$'\n'"${_suggestion_lines}"
      else
        _detail_lines="${_detail_lines}  ${_cat_label}: [${_wl}] → ${_cat_guidance}"$'\n'
      fi
    fi
  done

  # log は全 hit 用語をカンマ区切りで1行
  [[ -n "$_all_terms_list" ]] && _append_jp_quality_log "$context_label" "$_all_terms_list" "block"
  if [[ -n "$_struct_block" ]]; then
    _append_jp_quality_log "$context_label" "structural: ${_struct_block}" "block"
    _detail_lines="${_detail_lines}  構造 block: ${_struct_block}"$'\n'
  fi

  # systemMessage: 検出用語一覧 (構造 block 単独時は構造理由を表示)
  if [[ -n "$_all_terms_list" ]]; then
    MESSAGE="${ICON_CRITICAL} NG用語 block (${context_label}): [${_all_terms_list}]${_struct_block:+ + ${_struct_block}}"
  else
    MESSAGE="${ICON_CRITICAL} NG構造 block (${context_label}): ${_struct_block}"
  fi

  # additionalContext: category 別詳細 + source
  ADDITIONAL_CONTEXT="以下のNG用語を修正して再実行してください。source: guidelines/writing/NG-DICTIONARY.md
${_detail_lines}"

  # 各 block category の block list も表示 (回避参考)
  local _ref_lines=""
  for _cat_entry in "${_block_categories[@]}"; do
    _cat_key="${_cat_entry%%|*}"
    if [[ -v "_hit_by_key[${_cat_key}]" ]]; then
      local _full_list
      _full_list=$(_extract_term_list "$_principles_file" "$_cat_key" 2>/dev/null | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g' || true)
      _ref_lines="${_ref_lines}  ${_cat_key} block list: ${_full_list}"$'\n'
    fi
  done
  if [[ -n "$_ref_lines" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}
block list (この session で全て回避):
${_ref_lines}"
  fi

  # block 時も構造 warn を併記 (修正ついでに可読性も直す)
  if [[ -n "$_struct_msg" ]]; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT}"$'\n'"${_struct_msg}"
  fi
}

# chat 応答 (stop hook 経路) の文体検査。誤爆の低い語彙 8 key + 構造 3 種 (体言止め bullet 連発 / 矢印 / 100字超≥2) を block し、
# 誤爆リスクのある key + 残りの構造検査は warn に降格する。
# 出力契約: _CHAT_BLOCK_REASON (block hit 時のみ非空) / _CHAT_WARN_MSG (warn hit 時のみ非空) の 2 変数。
# _assert_required_keys は呼ばない (exit 2 が stop hook では block に化けるため)。dict 不在は graceful return。
# turn 締め語 (完了/次に/済/済み) は行末に単独で現れる場合だけ block 対象にする。文中利用は対象外にする。
_check_turn_closing_tail() {
  local text="$1"
  local clean
  clean=$(_strip_code_blocks "$text")
  local words=("完了" "次に" "済み" "済")
  local hits="" w
  for w in "${words[@]}"; do
    if printf '%s\n' "$clean" | grep -qE "${w}。?[[:space:]]*\$"; then
      hits="${hits:+${hits},}${w}"
    fi
  done
  printf '%s' "$hits"
}

# 許可一覧に載らない小文字英単語 (3 字以上) を返す。denylist 追補でなく反転方式にしたのは語追いが終わらないためだ。
# 大文字含みの語と backtick 内と複合識別子は対象外にする。escape hatch: JP_EN_ALLOWLIST_CHECK=0
_allowed_en_terms_file="$HOME/.claude/guidelines/writing/allowed-en-terms.txt"
_check_unknown_en_terms() {
  local text="$1"
  [[ "${JP_EN_ALLOWLIST_CHECK:-1}" == "1" ]] || return 0
  [[ -f "$_allowed_en_terms_file" ]] || return 0
  local clean
  clean=$(_strip_code_blocks "$text")
  clean=$(printf '%s' "$clean" | sed -E 's#[A-Za-z0-9~]+([/._~-]+[A-Za-z0-9~]+)+# #g')
  printf '%s\n' "$clean" | tr -c 'A-Za-z0-9\n' '\n' | grep -E '^[a-z]{3,}$' | sort -u \
    | grep -Fxv -f "$_allowed_en_terms_file" || true
}

_chat_quality_check() {
  local text="$1"
  _CHAT_BLOCK_REASON=""
  _CHAT_WARN_MSG=""
  [[ -z "$text" ]] && return 0
  [[ -f "$_principles_file" ]] || return 0
  _preload_term_lists

  # 弱い表現 / AI段取り / ヘッジは外向き経路で block 実績があり誤爆が低いため chat でも block (2026-07-16 昇格)。
  # 断定語 (「完了」がタスク名引用で誤爆) / 英語jargon / 過剰丁寧 (UI コピー draft の正当用法) は warn 据え置き。
  local _cq_block_keys=("AI定型語" "カタカナ造語禁止" "難読漢語 (block)" "非日常英語 (block)" "冗長表現 (block)" "弱い表現 (block)" "AI段取り定型 (block)" "ヘッジ濫用 (block)")
  local _cq_warn_keys=("過剰丁寧 (block)" "断定語 (warn-only)" "英語jargon (warn-only)" "主体不明断定 (warn-only)")

  # fast path: 全 key の語 union を 1 回の grep で検査し、hit ゼロ (大多数) なら per-key loop を省く
  local _cq_clean
  _cq_clean=$(_strip_code_blocks "$text")
  _cq_clean=$(printf '%s' "$_cq_clean" | sed -E 's/[A-Za-z0-9_.]+(-[A-Za-z0-9_.]+)+/ /g')
  local _cq_key _cq_word
  local _cq_all_words=()
  for _cq_key in "${_cq_block_keys[@]}" "${_cq_warn_keys[@]}"; do
    while IFS= read -r _cq_word; do
      [[ -n "$_cq_word" ]] && _cq_all_words+=("$_cq_word")
    done < <(_extract_term_list "$_principles_file" "$_cq_key")
  done
  local _cq_any=""
  if [[ ${#_cq_all_words[@]} -gt 0 ]]; then
    _cq_any=$(printf '%s' "$_cq_clean" | grep -ioFf <(printf '%s\n' "${_cq_all_words[@]}") | sort -u || true)
  fi

  # turn 締め語 (完了/次に/済/済み) は文末 anchor 一致のみ block 対象。「次に」は AI段取り定型 の lead 判定より優先する。
  local _cq_tail_hits
  _cq_tail_hits=$(_check_turn_closing_tail "$text")

  local _cq_block_terms="" _cq_detail="" _cq_warn_terms=""
  if [[ -n "$_cq_any" ]]; then
    local _cq_hits _cq_list
    for _cq_key in "${_cq_block_keys[@]}"; do
      if ! _cq_hits=$(_check_term_list "$text" "$_cq_key"); then
        if [[ "$_cq_key" == "AI段取り定型 (block)" && "$_cq_tail_hits" != *"次に"* ]]; then
          _cq_hits=$(printf '%s\n' "$_cq_hits" | grep -v '^次に$' || true)
          [[ -z "$_cq_hits" ]] && continue
        fi
        _cq_list=$(printf '%s' "$_cq_hits" | tr '\n' ',' | sed 's/,$//')
        _cq_block_terms="${_cq_block_terms:+${_cq_block_terms},}${_cq_list}"
        # 置換候補を併記して自己修正の 1 発成功率を上げる
        local _cq_sugg _cq_sline=""
        while IFS= read -r _cq_word; do
          [[ -z "$_cq_word" ]] && continue
          _cq_sugg=$(_lookup_suggestion "$_cq_word")
          [[ -n "$_cq_sugg" ]] && _cq_sline="${_cq_sline} ${_cq_word}→${_cq_sugg}"
        done <<< "$_cq_hits"
        _cq_detail="${_cq_detail}${_cq_key}: [${_cq_list}]${_cq_sline:+ (置換候補:${_cq_sline})}; "
      fi
    done
    for _cq_key in "${_cq_warn_keys[@]}"; do
      if ! _cq_hits=$(_check_term_list "$text" "$_cq_key"); then
        _cq_list=$(printf '%s' "$_cq_hits" | tr '\n' ',' | sed 's/,$//')
        _cq_warn_terms="${_cq_warn_terms:+${_cq_warn_terms},}${_cq_list}"
      fi
    done
  fi

  # 構造検査。chat は常体規範なので敬体 check on + 可読性 (連続漢字/読点) 同梱で python 1 fork。
  # 語彙 hit ゼロでも構造 block は発生するため fast path (_cq_any) の外で判定する。
  # 矢印チェーン / 100字超文は誤爆源を潰した上で block へ昇格済だから block 側で扱う。
  # 体言止め bullet は連発 (2 行以上) のみ block し、単発は warn に留める (natural-japanese 分析で 2026-07-18 に緩和した)。
  # 同一文末 / 敬体 / 連続漢字・読点は UI コピーや固有名詞で誤爆するため warn に据え置く。
  _check_sentence_structure_counts "$text" 1 1
  local _cq_struct_block="" _cq_struct_warn=""
  (( _SS_TAIGEN > 1 )) && _cq_struct_block="体言止めbullet ${_SS_TAIGEN}行 (連発。大半の bullet を「〜する/〜した/〜だ」の文で閉じる); "
  (( _SS_TAIGEN == 1 )) && _cq_struct_warn="${_cq_struct_warn}体言止めbullet 1行 (単発は許容。羅列にはしない); "
  (( _SS_ARROW > 0 )) && _cq_struct_block="${_cq_struct_block}矢印チェーン ${_SS_ARROW}行 (矢印列を動詞を持つ文章に展開する); "
  (( _SS_LONG > 0 )) && _cq_struct_block="${_cq_struct_block}100字超文 ${_SS_LONG}文 (冒頭: ${_SS_LONG_SAMPLE}… 句点で 2 文以上に分割する。修正例: 「Aを削り、Bを追加した」→「Aを削った。加えて Bを追加した。」); "
  (( _SS_KANJI_CNT > 0 )) && _cq_struct_warn="${_cq_struct_warn}連続漢字≥5: ${_SS_KANJI_CNT}種 (${_SS_KANJI_SAMPLE}) → 助詞挿入/訓読み開く; "
  (( _SS_TOUTEN > 0 )) && _cq_struct_warn="${_cq_struct_warn}読点≥4の文: ${_SS_TOUTEN}個 → 文分割; "
  (( _SS_REP > 0 )) && _cq_struct_warn="${_cq_struct_warn}同一文末3連続: ${_SS_REP}箇所 → 文末を変える; "
  (( _SS_POLITE > 0 )) && _cq_struct_warn="${_cq_struct_warn}敬体混入: ${_SS_POLITE}文 → 常体に統一; "
  (( _SS_FLAT > 0 )) && _cq_struct_warn="${_cq_struct_warn}平坦bullet≥11+理由語: ${_SS_FLAT}group → 親子に組み替え (PRINCIPLES.md ## 箇条書き階層化); "
  (( _SS_TIME > 0 )) && _cq_struct_warn="${_cq_struct_warn}時限マーカー: ${_SS_TIME}件 (${_SS_TIME_SAMPLE}) → 時制中立表現 (pr-description.md ### 時限マーカー禁止); "
  (( _SS_STUFF > 0 )) && _cq_struct_warn="${_cq_struct_warn}括弧詰め込み: ${_SS_STUFF}件 (${_SS_STUFF_SAMPLE}) → 括弧の名詞羅列を本文の文に開く (PRINCIPLES.md ### 圧縮文を開く); "

  local _cq_block_detail=""
  if [[ -n "$_cq_block_terms" ]]; then
    _append_jp_quality_log "chat" "$_cq_block_terms" "block"
    _cq_block_detail="${_cq_detail%; }"
  fi
  if [[ -n "$_cq_struct_block" ]]; then
    _append_jp_quality_log "chat" "structural: ${_cq_struct_block%; }" "block"
    _cq_block_detail="${_cq_block_detail:+${_cq_block_detail}; }構造: ${_cq_struct_block%; }"
  fi
  if [[ -n "$_cq_tail_hits" ]]; then
    _append_jp_quality_log "chat" "turn締め語文末: ${_cq_tail_hits}" "block"
    _cq_block_detail="${_cq_block_detail:+${_cq_block_detail}; }turn締め語文末: ${_cq_tail_hits} (言い切って終えず、次の行に実際の内容を続けて書く。加えて 'superpowers:verification-before-completion' skill の Iron Law に従い、宣言前に検証 command を実行した evidence を書き込む)"
  fi
  if [[ -n "$_cq_block_detail" ]]; then
    _CHAT_BLOCK_REASON="chat 応答が plain JP 規範に反する: ${_cq_block_detail} — 直前の応答本文だけを規範に沿った開いた日本語に書き直して再送する。source: guidelines/writing/NG-DICTIONARY.md + rules/plain-jp.md"
  fi
  local _cq_warn_out=""
  if [[ -n "$_cq_warn_terms" ]]; then
    _append_jp_quality_log "chat" "$_cq_warn_terms" "warn"
    _cq_warn_out="語: ${_cq_warn_terms}"
  fi
  # 許可一覧外英単語 (反転方式)。上限 10 語で message 肥大を防ぐ
  local _cq_unknown_en
  _cq_unknown_en=$(_check_unknown_en_terms "$text" | head -10 | tr '\n' ',' | sed 's/,$//')
  if [[ -n "$_cq_unknown_en" ]]; then
    _append_jp_quality_log "chat" "unknown-en: ${_cq_unknown_en}" "warn"
    _cq_warn_out="${_cq_warn_out:+${_cq_warn_out}; }許可一覧外の英単語: ${_cq_unknown_en} → 日本語化するか backtick で囲む。定着語なら guidelines/writing/allowed-en-terms.txt に追加"
  fi
  if [[ -n "$_cq_struct_warn" ]]; then
    _append_jp_quality_log "chat" "structural: ${_cq_struct_warn%; }" "warn"
    _cq_warn_out="${_cq_warn_out:+${_cq_warn_out}; }${_cq_struct_warn%; }"
  fi
  if [[ -n "$_cq_warn_out" ]]; then
    _CHAT_WARN_MSG="${ICON_WARNING:-▲} chat 文体 warn: ${_cq_warn_out} — 次の応答は plain JP 規範 (rules/plain-jp.md) に沿って直す"
  fi
  return 0
}
