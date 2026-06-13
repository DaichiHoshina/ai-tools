#!/usr/bin/env bash
# JP文章品質チェック関数群
# pre-tool-use.sh から抽出: AI定型語 / カタカナ造語 / NG語 block 系
# source してから使用する。GUARD_CLASS / MESSAGE / ADDITIONAL_CONTEXT / TOOL_NAME を参照・変更する。

# 多重 source 防止
if [[ "${_JP_QUALITY_CHECK_LOADED:-}" == "1" ]]; then
    return 0
fi
_JP_QUALITY_CHECK_LOADED=1

# shellcheck source=../hooks/lib/thresholds.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/thresholds.sh"

# ====================================
# AI定型語 / カタカナ造語 block 関数
# NG-DICTIONARY.md から動的抽出 → 外向き text に grep → hit で exit 2
# ====================================
_principles_file="$HOME/.claude/guidelines/writing/NG-DICTIONARY.md"

# _extract_term_list の per-process cache (同一プロセス内で同 key の grep を1回に削減)
declare -A _term_list_cache=()
_assert_required_keys_done=${_assert_required_keys_done:-0}

# block ログ出力関数
# 引数: tool_name, hit_term, block|warn
_append_jp_quality_log() {
  local tool_name="$1"
  local hit_term="$2"
  local action="$3"
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-block.log"
  # mkdir は -p で安全に
  mkdir -p "$log_dir" 2>/dev/null || true
  # ファイルサイズ rotation: 1MB 超えたら mv してから新規
  if [[ -f "$log_file" ]]; then
    local fsize
    fsize=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
    if [[ "${fsize}" -gt ${_TH_LOG_MAX_BYTES} ]]; then
      local _bak_ts; printf -v _bak_ts '%(%Y%m%d%H%M%S)T' -1
      mv "$log_file" "${log_file}.${_bak_ts}.bak" 2>/dev/null || true
    fi
  fi
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  printf '%s | %s | %s | %s\n' "$ts" "$tool_name" "$hit_term" "$action" >> "$log_file" 2>/dev/null || true
}

# code block (``` ... ``` および ` ... `) を除去したテキストを返す
_strip_code_blocks() {
  local text="$1"
  # fenced code block (``` ... ```) を除去 (POSIX awk 互換)
  local stripped
  stripped=$(printf '%s' "$text" | awk '
    /^```/ { in_block = !in_block; next }
    !in_block { print }
  ')
  # inline code (` ... `) を除去
  stripped=$(printf '%s' "$stripped" | sed "s/\`[^\`]*\`/ /g")
  printf '%s' "$stripped"
}

# 指定 key の list を NG-DICTIONARY.md から抽出 (「**<key>**: 語1 / 語2 / ...」行)
# per-process cache: 同 file+key の grep を1回に削減
_extract_term_list() {
  local file="$1"
  local key="$2"
  [[ -f "$file" ]] || return 0
  local cache_key="${file}::${key}"
  if [[ -v "_term_list_cache[${cache_key}]" ]]; then
    local cached="${_term_list_cache[${cache_key}]}"
    [[ -n "$cached" ]] && printf '%s\n' "${cached}"
    return 0
  fi
  local line
  line=$(grep -m1 "^\*\*${key}\*\*:" "$file" 2>/dev/null || true)
  if [[ -z "$line" ]]; then
    _term_list_cache["${cache_key}"]=""
    return 0
  fi
  local body="${line#*: }"
  local result
  result=$(printf '%s' "$body" | tr '/' '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | grep -v '^$' || true)
  _term_list_cache["${cache_key}"]="${result}"
  [[ -n "$result" ]] && printf '%s\n' "${result}"
  return 0
}

# AI定型語を NG-DICTIONARY.md から抽出 (後方互換 wrapper)
_extract_ai_jargon() {
  local file="$1"
  _extract_term_list "$file" "AI定型語"
}

# 必須 key sanity check: hook が exact match 参照する key が抽出 0 件なら fail-loud
# NG-DICTIONARY.md key rename / 記法破壊を早期検出して silent pass を防ぐ
# session+mtime 単位 flag file cache: 同セッション内の 7 grep を skip、dict 編集時は mtime 変化で再検査
# SESSION_ID は caller (pre-tool-use.sh) が export して渡す想定、未設定時は $$ で代替
_assert_required_keys() {
  # per-process 変数での早期 return (同一プロセス内の2回目以降)
  [[ "${_assert_required_keys_done:-0}" -eq 1 ]] && return 0

  # session+mtime 単位 flag file: /tmp/claude-ngdict-keys-ok-<SESSION_ID>-<mtime>
  # NG-DICTIONARY.md を同 session 内で編集した場合も mtime 変化で再検査する
  local _dict_mtime
  _dict_mtime=$(stat -c '%Y' "$_principles_file" 2>/dev/null \
    || stat -f '%m' "$_principles_file" 2>/dev/null \
    || echo "0")
  local _flag_path="/tmp/claude-ngdict-keys-ok-${SESSION_ID:-$$}-${_dict_mtime}"
  # 古いキャッシュ (同セッション・異なる mtime) のみ削除 — _flag_path 自体は残す
  for _old_flag in "/tmp/claude-ngdict-keys-ok-${SESSION_ID:-$$}"-*; do
    [[ -e "$_old_flag" ]] || continue
    [[ "$_old_flag" = "$_flag_path" ]] && continue
    rm -f "$_old_flag" 2>/dev/null || true
  done
  if [[ -f "$_flag_path" ]]; then
    _assert_required_keys_done=1
    return 0
  fi

  _assert_required_keys_done=1
  # NG-DICTIONARY.md 不在時は別経路で既に silent pass → この検査はスキップ
  [[ -f "$_principles_file" ]] || return 0
  local required_keys=("AI定型語" "カタカナ造語禁止" "断定語 (warn-only)" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)")
  local key
  for key in "${required_keys[@]}"; do
    local result
    result=$(_extract_term_list "$_principles_file" "$key")
    if [[ -z "$result" ]]; then
      printf '[hook-error] PRINCIPLES.md key '"'"'%s'"'"' 抽出 0 件 — rename or 記法破壊の可能性。silent pass 防止のため exit 2 で fail-loud。\n' "$key" >&2
      exit 2
    fi
  done
  # 検査成功: flag file を touch して次回 session 内 skip を有効化
  touch "$_flag_path" 2>/dev/null || true
}

# inject byte size log 出力関数
# 引数: tool_name, bytes, status(ok|over)
_append_jp_quality_inject_log() {
  local tool_name="$1"
  local bytes="$2"
  local status_str="$3"
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-inject.log"
  mkdir -p "$log_dir" 2>/dev/null || true
  # ファイルサイズ rotation: 1MB 超えたら mv してから新規
  if [[ -f "$log_file" ]]; then
    local fsize
    fsize=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
    if [[ "${fsize}" -gt ${_TH_LOG_MAX_BYTES} ]]; then
      local _bak_ts; printf -v _bak_ts '%(%Y%m%d%H%M%S)T' -1
      mv "$log_file" "${log_file}.${_bak_ts}.bak" 2>/dev/null || true
    fi
  fi
  local ts
  printf -v ts '%(%Y-%m-%dT%H:%M:%S%z)T' -1
  printf '%s | tool=%s | bytes=%s | threshold=1500 | status=%s\n' \
    "$ts" "$tool_name" "$bytes" "$status_str" >> "$log_file" 2>/dev/null || true
}

# 外向き text に対して指定 key の list を grep し、hit 語を stdout に出力
# 返り値: hit あり=1, なし=0
_check_term_list() {
  local text="$1"
  local key="$2"
  [[ -z "$text" ]] && return 0
  [[ -f "$_principles_file" ]] || return 0
  # code block を除去してからチェック
  local clean_text
  clean_text=$(_strip_code_blocks "$text")
  # 語リストを配列に収集
  local words=()
  while IFS= read -r word; do
    [[ -z "$word" ]] && continue
    words+=("$word")
  done < <(_extract_term_list "$_principles_file" "$key")
  [[ ${#words[@]} -eq 0 ]] && return 0

  # 全語を1回の grep -ioFf で hit 語を列挙 (N×fork → 1 fork)
  # -i: 英語 NG 語 (leverage / Leverage / LEVERAGE 等) の大文字小文字差を取りこぼさない。JP 語は無影響
  local found
  found=$(printf '%s' "$clean_text" | grep -ioFf <(printf '%s\n' "${words[@]}") | sort -u || true)
  if [[ -n "$found" ]]; then
    printf '%s\n' "$found"
    return 1
  fi
  return 0
}

# 後方互換: AI定型語チェック
_check_ai_jargon() {
  local text="$1"
  _check_term_list "$text" "AI定型語"
}

# 構造的可読性の機械検出 (連続漢字≥5 / 読点≥4)。warn-only、block しない。
# PRINCIPLES.md `## 文単位の品質規約` (連続漢字 4 文字上限 / 読点 3 個まで) を機械検出に接続。
# 固有名詞・技術用語で誤検知しうるため warn 止まり。出力: warn 文字列 (検出ゼロなら空)。
# 表示は count + 漢字 sample のみ (UTF-8 truncation による mojibake を避ける)。
_check_structural_quality() {
  local text="$1"
  [[ -z "$text" ]] && return 0
  local clean
  clean=$(_strip_code_blocks "$text")
  local out=""
  # 連続漢字 5 文字以上。grep '[一-龯]' は C locale で byte 範囲マッチに化けるため python3 で Unicode 正確判定。
  # python3 不在なら graceful skip (読点 check は継続)。outward text 時のみ呼ばれるため fork 1 本は許容。
  if command -v python3 &>/dev/null; then
    local kanji kc ksample
    kanji=$(printf '%s' "$clean" | python3 -c 'import sys,re
h=sorted(set(re.findall(r"[一-龯]{5,}", sys.stdin.read())))
print(f"{len(h)}\t"+" ".join(h[:3]))' 2>/dev/null || printf '0\t')
    IFS=$'\t' read -r kc ksample <<< "$kanji"
    if [[ "${kc:-0}" =~ ^[0-9]+$ ]] && (( kc > 0 )); then
      out="連続漢字≥5: ${kc}種 (${ksample}) → 助詞挿入/訓読み開く; "
    fi
  fi
  # 読点 4 個以上の文 (。区切り、、を gsub で数える。byte-safe)
  local tc
  tc=$(printf '%s' "$clean" | awk 'BEGIN{RS="。"} { n=gsub(/、/,"x"); if(n>=4)c++ } END{ print c+0 }')
  [[ "${tc:-0}" -gt 0 ]] && out="${out}読点≥4の文: ${tc}個 → 文分割; "
  [[ -n "$out" ]] && printf '%s' "${out%; }"
  return 0
}

# 外向き text を AI語 + カタカナ造語チェックし、hit 時に Forbidden block をセットする
# 全 block category を一括収集して exit 2 + まとめて提示する (逐次 block 廃止)
# 呼び出し元: tool ごとの case 節
_block_if_ai_jargon() {
  local text="$1"
  local context_label="$2"  # "commit message" / "PR body" 等
  # 必須 key sanity check (session 内 cache 済なら即 return)
  _assert_required_keys

  # inject byte size 計測: 全 block list の合計抽出 byte 数を計算してログ出力
  local _inject_keys=("AI定型語" "カタカナ造語禁止" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)")
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

  # 構造的可読性 warn (連続漢字 / 読点)。block しない、additionalContext に追記
  local _struct_warn
  _struct_warn=$(_check_structural_quality "$text")
  local _struct_msg=""
  if [[ -n "$_struct_warn" ]]; then
    _append_jp_quality_log "$context_label" "structural: ${_struct_warn}" "warn"
    _struct_msg="${ICON_WARNING:-▲} 可読性 warn (${context_label}): ${_struct_warn}"
  fi

  # block なし → return (構造 warn があれば additionalContext に載せる)
  if [[ "$_has_block" -eq 0 ]]; then
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
      _detail_lines="${_detail_lines}  ${_cat_label}: [${_wl}] → ${_cat_guidance}"$'\n'
    fi
  done

  # log は全 hit 用語をカンマ区切りで1行
  _append_jp_quality_log "$context_label" "$_all_terms_list" "block"

  # systemMessage: 検出用語一覧
  MESSAGE="${ICON_CRITICAL} NG用語 block (${context_label}): [${_all_terms_list}]"

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
