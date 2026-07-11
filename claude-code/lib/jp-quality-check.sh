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
# shellcheck source=../hooks/lib/portable-stat.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/portable-stat.sh"
# shellcheck source=../hooks/lib/log-rotation.sh
source "${BASH_SOURCE[0]%/*}/../hooks/lib/log-rotation.sh"

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
  # bats unit test 実行中はログ汚染を防ぐため skip
  [[ -n "${BATS_TEST_FILENAME:-}" ]] && return 0
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-block.log"
  # mkdir は -p で安全に
  mkdir -p "$log_dir" 2>/dev/null || true
  _rotate_log_if_needed "$log_file" 3
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

# 辞書全 key を 1 pass の builtin parse で cache へ載せる (key 数 × 5 fork → 0 fork)
# _extract_term_list と同じ抽出結果になるよう「**key**: 語1 / 語2」行を / 区切りで分解して trim する
_preload_term_lists() {
  [[ -f "$_principles_file" ]] || return 0
  [[ "${_term_lists_preloaded:-0}" == "1" ]] && return 0
  _term_lists_preloaded=1
  local nl=$'\n'
  local line key body result word cache_key
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "**"*"**:"* ]] || continue
    key="${line:2}"
    key="${key%%\*\**}"
    cache_key="${_principles_file}::${key}"
    # grep -m1 相当: 同 key の重複行は先勝ち
    [[ -v "_term_list_cache[${cache_key}]" ]] && continue
    body="${line#*: }"
    result=""
    while IFS= read -r word; do
      word="${word#"${word%%[![:space:]]*}"}"
      word="${word%"${word##*[![:space:]]}"}"
      [[ -z "$word" ]] && continue
      result="${result:+${result}${nl}}${word}"
    done <<< "${body//\//${nl}}"
    _term_list_cache["${cache_key}"]="${result}"
  done < "$_principles_file"
  return 0
}

# 置換候補 (頻出) key から word に対応する置換先を返す
# 引数: word (踏襲 / leverage 等)
# 返値: 置換先文字列 (stdout)。対応なしなら空文字
_lookup_suggestion() {
  local word="$1"
  local pairs
  pairs=$(_extract_term_list "$_principles_file" "置換候補 (頻出)" 2>/dev/null || true)
  [[ -z "$pairs" ]] && return 0
  local pair
  while IFS= read -r pair; do
    [[ -z "$pair" ]] && continue
    local src dst
    # split on → (U+2192)
    src="${pair%%→*}"
    dst="${pair#*→}"
    src="${src# }"; src="${src% }"
    dst="${dst# }"; dst="${dst% }"
    if [[ "$src" = "$word" ]]; then
      printf '%s' "$dst"
      return 0
    fi
  done <<< "$pairs"
  return 0
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
  _dict_mtime=$(portable_stat_mtime "$_principles_file")
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
  local required_keys=("AI定型語" "カタカナ造語禁止" "断定語 (warn-only)" "英語jargon (warn-only)" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)" "AI段取り定型 (block)" "ヘッジ濫用 (block)" "過剰丁寧 (block)")
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
  [[ -n "${BATS_TEST_FILENAME:-}" ]] && return 0
  local log_dir="$HOME/.claude/logs"
  local log_file="${log_dir}/jp-quality-inject.log"
  mkdir -p "$log_dir" 2>/dev/null || true
  _rotate_log_if_needed "$log_file" 3
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
  # hyphen 連結の ASCII 識別子 (skill / file / branch 名等) を除去する。
  # 例: comprehensive-review が「comprehensive」に部分一致して誤 block するのを防ぐ。
  # 英語 NG 語は識別子内で使われても文章表現ではないため除去して問題ない。
  clean_text=$(printf '%s' "$clean_text" | sed -E 's/[A-Za-z0-9_.]+(-[A-Za-z0-9_.]+)+/ /g')
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
  # 読点 4 個以上の文 (。で改行分割してから行=文として数える。byte-safe)
  # macOS awk はマルチバイト RS 非対応のため sed で改行化してから処理する
  # 。を改行へ置換 (BSD/GNU sed 両対応の $'\n' 形式)。SC1003 は誤検出のため抑止
  local tc
  # shellcheck disable=SC1003
  tc=$(printf '%s' "$clean" | sed 's/。/\'$'\n''/g' | awk '{ n=gsub(/、/,"x"); if(n>=4)c++ } END{ print c+0 }')
  [[ "${tc:-0}" -gt 0 ]] && out="${out}読点≥4の文: ${tc}個 → 文分割; "
  [[ -n "$out" ]] && printf '%s' "${out%; }"
  return 0
}

# 文構造の機械検出 (体言止め bullet / 矢印チェーン / 同一文末3連続 / 100字超文 / 敬体混入)。warn-only。
# 引数: text, polite_check (1 で です/ます 混入も検査。外向き doc は敬体が正のケースがあるため default 0),
#       include_readability (1 で連続漢字≥5 / 読点≥4 も同じ python 1 fork で検査。
#       chat 経路用: _check_structural_quality との 2 重 fork を避ける。外向き経路は既存関数のまま)
# 出力: warn 文字列 (検出ゼロなら空)。python3 不在なら graceful skip。
# 体言止め suffix は NG-DICTIONARY.md「体言止め末尾 (structural)」key から取得 (欠落時は builtin fallback)。
_check_sentence_structure() {
  local text="$1"
  local polite_check="${2:-0}"
  local include_readability="${3:-0}"
  [[ -z "$text" ]] && return 0
  command -v python3 &>/dev/null || return 0
  local clean
  clean=$(_strip_code_blocks "$text")
  local _taigen_suf
  _taigen_suf=$(_extract_term_list "$_principles_file" "体言止め末尾 (structural)" 2>/dev/null | paste -sd'|' - || true)
  local result
  result=$(printf '%s' "$clean" | TAIGEN_SUF="$_taigen_suf" POLITE_CHECK="$polite_check" INCLUDE_READABILITY="$include_readability" python3 -c '
import sys, os, re
text = sys.stdin.read()
lines = text.splitlines()

suf = os.environ.get("TAIGEN_SUF") or "済|済み|完了|可能|必要|対応|中|なし|あり|予定|実施|確認|追加|削除|修正|更新|化"
suffixes = tuple(s for s in suf.split("|") if s)
verb_end = re.compile(r"(する|した|して|している|だ|である|ます|ました|です|ない|いる|ある|なる|なった|れる|れた|られる|られた|できる|できた)$")
bullet = re.compile(r"^\s*([-*・]|\d+\.)\s+(.+)$")
taigen = 0
for ln in lines:
    m = bullet.match(ln)
    if not m:
        continue
    body = m.group(2)
    if "|" in body:
        continue
    body = body.rstrip().rstrip("。)）`").rstrip()
    if body.endswith((":", "：")):
        continue
    if verb_end.search(body):
        continue
    if body.endswith(suffixes):
        taigen += 1

arrow = 0
for ln in lines:
    if any(re.search(r"→.*→", seg) for seg in ln.split("/")):
        arrow += 1

sents = [s.strip() for s in re.split(r"。", text) if s.strip()]
tail = re.compile(r"(した|する|です|ます|ました|ません|ない|だ|である|いる|ある)$")
labels = [(m.group(1) if (m := tail.search(s)) else "") for s in sents]
rep = 0
run = 1
for i in range(1, len(labels)):
    if labels[i] and labels[i] == labels[i - 1]:
        run += 1
        if run == 3:
            rep += 1
    else:
        run = 1

long_cnt = sum(1 for s in sents if len(s.replace("\n", "")) >= 100)

polite = 0
if os.environ.get("POLITE_CHECK") == "1":
    pol = re.compile(r"(です|ます|でした|ました|ましょう|ません)$")
    polite = sum(1 for s in sents if pol.search(s))

kanji_cnt = 0
kanji_sample = ""
touten = 0
if os.environ.get("INCLUDE_READABILITY") == "1":
    runs = sorted(set(re.findall(r"[一-龯]{5,}", text)))
    kanji_cnt = len(runs)
    kanji_sample = " ".join(runs[:3])
    touten = sum(1 for s in sents if s.count("、") >= 4)

print(f"{taigen}\t{arrow}\t{rep}\t{long_cnt}\t{polite}\t{kanji_cnt}\t{kanji_sample}\t{touten}")
' 2>/dev/null || printf '0\t0\t0\t0\t0\t0\t\t0')
  local _tg _ar _rp _lg _pl _kc _ks _tt
  IFS=$'\t' read -r _tg _ar _rp _lg _pl _kc _ks _tt <<< "$result"
  local out=""
  [[ "${_kc:-0}" =~ ^[0-9]+$ ]] && (( _kc > 0 )) && out="連続漢字≥5: ${_kc}種 (${_ks}) → 助詞挿入/訓読み開く; "
  [[ "${_tt:-0}" =~ ^[0-9]+$ ]] && (( _tt > 0 )) && out="${out}読点≥4の文: ${_tt}個 → 文分割; "
  [[ "${_tg:-0}" =~ ^[0-9]+$ ]] && (( _tg > 0 )) && out="${out}体言止めbullet: ${_tg}行 → 文として閉じる (〜する/〜した); "
  [[ "${_ar:-0}" =~ ^[0-9]+$ ]] && (( _ar > 0 )) && out="${out}矢印チェーン: ${_ar}行 → 文章に展開; "
  [[ "${_rp:-0}" =~ ^[0-9]+$ ]] && (( _rp > 0 )) && out="${out}同一文末3連続: ${_rp}箇所 → 文末を変える; "
  [[ "${_lg:-0}" =~ ^[0-9]+$ ]] && (( _lg > 0 )) && out="${out}100字超文: ${_lg}文 → 文分割; "
  [[ "${_pl:-0}" =~ ^[0-9]+$ ]] && (( _pl > 0 )) && out="${out}敬体混入: ${_pl}文 → 常体に統一; "
  [[ -n "$out" ]] && printf '%s' "${out%; }"
  return 0
}

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
  # 文構造 warn (体言止め bullet / 矢印チェーン / 文末反復 / 100字超)。敬体 check は外向き doc で off
  local _sent_warn
  _sent_warn=$(_check_sentence_structure "$text" 0)
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

# chat 応答 (stop hook 経路) の文体検査。高精度 5 key のみ block し、低精度 key + 構造検査は warn に降格する。
# 出力契約: _CHAT_BLOCK_REASON (block hit 時のみ非空) / _CHAT_WARN_MSG (warn hit 時のみ非空) の 2 変数。
# _assert_required_keys は呼ばない (exit 2 が stop hook では block に化けるため)。dict 不在は graceful return。
_chat_quality_check() {
  local text="$1"
  _CHAT_BLOCK_REASON=""
  _CHAT_WARN_MSG=""
  [[ -z "$text" ]] && return 0
  [[ -f "$_principles_file" ]] || return 0
  _preload_term_lists

  local _cq_block_keys=("AI定型語" "カタカナ造語禁止" "難読漢語 (block)" "非日常英語 (block)" "冗長表現 (block)")
  local _cq_warn_keys=("弱い表現 (block)" "AI段取り定型 (block)" "ヘッジ濫用 (block)" "過剰丁寧 (block)" "断定語 (warn-only)" "英語jargon (warn-only)")

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

  local _cq_block_terms="" _cq_detail="" _cq_warn_terms=""
  if [[ -n "$_cq_any" ]]; then
    local _cq_hits _cq_list
    for _cq_key in "${_cq_block_keys[@]}"; do
      if ! _cq_hits=$(_check_term_list "$text" "$_cq_key"); then
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

  # 構造検査 (常に warn)。chat は常体規範なので敬体 check on + 可読性 (連続漢字/読点) 同梱で python 1 fork
  local _cq_struct
  _cq_struct=$(_check_sentence_structure "$text" 1 1)

  if [[ -n "$_cq_block_terms" ]]; then
    _append_jp_quality_log "chat" "$_cq_block_terms" "block"
    _CHAT_BLOCK_REASON="chat 応答に NG 用語がある: ${_cq_detail%; } — 直前の応答本文だけを NG 用語なしの plain JP に書き直して再送する。source: guidelines/writing/NG-DICTIONARY.md"
  fi
  local _cq_warn_out=""
  if [[ -n "$_cq_warn_terms" ]]; then
    _append_jp_quality_log "chat" "$_cq_warn_terms" "warn"
    _cq_warn_out="語: ${_cq_warn_terms}"
  fi
  if [[ -n "$_cq_struct" ]]; then
    _append_jp_quality_log "chat" "structural: ${_cq_struct}" "warn"
    _cq_warn_out="${_cq_warn_out:+${_cq_warn_out}; }${_cq_struct}"
  fi
  if [[ -n "$_cq_warn_out" ]]; then
    _CHAT_WARN_MSG="${ICON_WARNING:-▲} chat 文体 warn: ${_cq_warn_out} — 次の応答は plain JP 規範 (rules/plain-jp.md) に沿って直す"
  fi
  return 0
}
