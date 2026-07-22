#!/usr/bin/env bash
# 文構造の機械検出関数群 (jp-quality-check.sh から抽出)
# source してから使用する。term-extraction.sh の _strip_code_blocks / _extract_term_list に依存する。

# 多重 source 防止
if [[ "${_JP_QUALITY_STRUCTURAL_CHECKS_LOADED:-}" == "1" ]]; then
    return 0
fi
_JP_QUALITY_STRUCTURAL_CHECKS_LOADED=1

# shellcheck source=term-extraction.sh
source "${BASH_SOURCE[0]%/*}/term-extraction.sh"

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

# 文構造の機械検出の count 版。検出数を global 変数 8 個にセットする (出力なし)。
# chat 経路 (_chat_quality_check) が体言止め / 矢印 / 100字超を block 判定に使うため、
# warn 文字列でなく数値で返す。warn 文字列が要る経路は wrapper の _check_sentence_structure を使う。
# 引数: text, polite_check (1 で です/ます 混入も検査。外向き doc は敬体が正のケースがあるため default 0),
#       include_readability (1 で連続漢字≥5 / 読点≥4 も同じ python 1 fork で検査。
#       chat 経路用: _check_structural_quality との 2 重 fork を避ける。外向き経路は既存関数のまま)
# python3 不在なら全 count 0 で graceful skip。
# 体言止め suffix は NG-DICTIONARY.md「体言止め末尾 (structural)」key から取得 (欠落時は builtin fallback)。
_check_sentence_structure_counts() {
  local text="$1"
  local polite_check="${2:-0}"
  local include_readability="${3:-0}"
  _SS_TAIGEN=0 _SS_ARROW=0 _SS_REP=0 _SS_LONG=0 _SS_POLITE=0 _SS_KANJI_CNT=0 _SS_KANJI_SAMPLE="" _SS_TOUTEN=0 _SS_LONG_SAMPLE=""
  _SS_FLAT=0 _SS_TIME=0 _SS_TIME_SAMPLE="" _SS_STUFF=0 _SS_STUFF_SAMPLE=""
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
bullet = re.compile(r"^(\s*)([-*・]|\d+\.)\s+(.+)$")
taigen = 0
for ln in lines:
    m = bullet.match(ln)
    if not m:
        continue
    body = m.group(3)
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

# 改行も文境界に含める。句点なしの行 (commit subject + trailer / bullet 列) が
# 1 文に連結カウントされて 100 字超に誤爆するのを防ぐ (2026-07-18)。
sents = [s.strip() for s in re.split(r"[。\n]", text) if s.strip()]
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

# inline code span (`...`) と裸 URL は path/link 由来の長文誤爆源のため、100 字カウントのみ除去してから測る
# 「 / 」3 個以上の行は辞書・列挙の data 行 (NG-DICTIONARY 等) で散文でないため、100 字判定から除外する
# 機械 directive (Go `//go:` / lint 抑制 / build tag) は散文でなく分割不能なため 100 字判定から除外する
# marker (`//` / `#`) は optional: comment 抽出経路 (_extract_comment_body_text) は marker を剥がした後に判定する
_directive_re = re.compile(r"^\s*(?://|#)?\s*(go:(generate|build|embed|linkname|nosplit|noinline|noescape|cgo_|name)|\+build|nolint|lint:ignore|eslint-(disable|enable)|shellcheck\s+(disable|source|enable)|noqa|prettier-ignore|@ts-(ignore|expect-error)|SPDX-License-Identifier)")
_long_src = [re.sub(r"`[^`]*`|https?://\S+", "", s) for s in sents if s.count(" / ") < 3 and not _directive_re.search(s)]
_long_hits = [s.replace("\n", "").replace("\t", " ") for s in _long_src if len(s.replace("\n", "")) >= 100]
long_cnt = len(_long_hits)
long_sample = " ⧸ ".join(h[:32] for h in _long_hits[:2]) or "-"

polite = 0
if os.environ.get("POLITE_CHECK") == "1":
    pol = re.compile(r"(です|ます|でした|ました|ましょう|ません)$")
    polite = sum(1 for s in sents if pol.search(s))

kanji_cnt = 0
kanji_sample = "-"
touten = 0
if os.environ.get("INCLUDE_READABILITY") == "1":
    runs = sorted(set(re.findall(r"[一-龯]{5,}", text)))
    kanji_cnt = len(runs)
    kanji_sample = " ".join(runs[:3]) or "-"
    touten = sum(1 for s in sents if s.count("、") >= 4)

# 階層 warn: 同一インデント (連続) の bullet が 11 個以上並び、うち 1 個以上に理由語 (〜ので/〜ため/〜だから/〜なので) を含む状態を検出する。
# 閾値 ≥11 で既存 pattern 集 (list of N items) の誤爆を抑える。連続 group で判定するため途中で親子が挟まればリセットする。
# 理由語は文中どこでも match してよい (bullet 末尾に限らない)。code fence 内は _strip_code_blocks で除去済のため考慮しない。
reason_re = re.compile(r"(ので|ため|だから|なので)")
flat = 0
cur_indent = None
cur_group = []
def check_group(g):
    if len(g) < 11:
        return 0
    return 1 if any(reason_re.search(b) for b in g) else 0
for ln in lines:
    m = bullet.match(ln)
    if not m:
        if cur_group:
            flat += check_group(cur_group)
            cur_group = []
            cur_indent = None
        continue
    indent = len(m.group(1).replace("\t", "  "))
    body = m.group(3)
    if cur_indent is None or indent != cur_indent:
        if cur_group:
            flat += check_group(cur_group)
        cur_indent = indent
        cur_group = [body]
    else:
        cur_group.append(body)
if cur_group:
    flat += check_group(cur_group)

# 時限マーカー warn: merge / 投稿後の読み手が解決できない時制参照を検出する。誤爆抑制のため保守的 pattern に絞る。
# 対象 pattern は下 time_patterns の 5 種のみ (PR 番号 + 以降 / 「本 PR で新設」等 / 相対日付 + 合意) に限定する。
# code fence 内 pattern (`Depends on #123`) は _strip_code_blocks 済のため素の text だけ match する。
time_patterns = [
    r"#\d+\s*以降",
    r"本\s*PR\s*で\s*(新設|追加|導入|削除)",
    r"本\s*commit\s*で\s*(新設|追加|導入|削除)",
    r"本\s*issue\s*で\s*(新設|追加|導入|削除)",
    r"(先週|昨日|一昨日|先月|直近)\s*(合意|決定|議論|の\s*incident)",
]
time_re = re.compile("|".join(time_patterns))
time_hits = list(dict.fromkeys(m.group(0) for m in time_re.finditer(text)))
time_cnt = len(time_hits)
time_sample = " / ".join(time_hits[:3]) or "-"

# 括弧詰め込み warn: 読点 2 個以上 + 動詞なしの括弧は書き手 memo の圧縮で、初読で意味が取れない。
# 「(A、B、C)」の名詞羅列だけを拾い、動詞を含む補足文の括弧は対象外にして誤爆を抑える。
paren_verb = re.compile(r"(する|した|して|される|された|とする|になる|使う|返す|できる|残す|だ|です|ない)")
stuff_hits = []
for m in re.finditer(r"[（(]([^（）()]{1,120})[）)]", text):
    inner = m.group(1)
    if inner.count("、") >= 2 and not paren_verb.search(inner):
        stuff_hits.append(inner[:24])
stuff_cnt = len(stuff_hits)
stuff_sample = " / ".join(stuff_hits[:2]) or "-"

print(f"{taigen}\t{arrow}\t{rep}\t{long_cnt}\t{polite}\t{kanji_cnt}\t{kanji_sample}\t{touten}\t{flat}\t{time_cnt}\t{time_sample}\t{stuff_cnt}\t{stuff_sample}\t{long_sample}")
' 2>/dev/null || printf '0\t0\t0\t0\t0\t0\t-\t0\t0\t0\t-\t0\t-\t-')
  local _tg _ar _rp _lg _pl _kc _ks _tt _fl _tc _ts _sc _ss _lgs
  IFS=$'\t' read -r _tg _ar _rp _lg _pl _kc _ks _tt _fl _tc _ts _sc _ss _lgs <<< "$result"
  [[ "${_tg:-0}" =~ ^[0-9]+$ ]] && _SS_TAIGEN="$_tg"
  [[ "${_ar:-0}" =~ ^[0-9]+$ ]] && _SS_ARROW="$_ar"
  [[ "${_rp:-0}" =~ ^[0-9]+$ ]] && _SS_REP="$_rp"
  [[ "${_lg:-0}" =~ ^[0-9]+$ ]] && _SS_LONG="$_lg"
  [[ "${_pl:-0}" =~ ^[0-9]+$ ]] && _SS_POLITE="$_pl"
  [[ "${_kc:-0}" =~ ^[0-9]+$ ]] && _SS_KANJI_CNT="$_kc"
  _SS_KANJI_SAMPLE="${_ks:-}"
  [[ "$_SS_KANJI_SAMPLE" == "-" ]] && _SS_KANJI_SAMPLE=""
  [[ "${_tt:-0}" =~ ^[0-9]+$ ]] && _SS_TOUTEN="$_tt"
  [[ "${_fl:-0}" =~ ^[0-9]+$ ]] && _SS_FLAT="$_fl"
  [[ "${_tc:-0}" =~ ^[0-9]+$ ]] && _SS_TIME="$_tc"
  _SS_TIME_SAMPLE="${_ts:-}"
  [[ "$_SS_TIME_SAMPLE" == "-" ]] && _SS_TIME_SAMPLE=""
  [[ "${_sc:-0}" =~ ^[0-9]+$ ]] && _SS_STUFF="$_sc"
  _SS_STUFF_SAMPLE="${_ss:-}"
  [[ "$_SS_STUFF_SAMPLE" == "-" ]] && _SS_STUFF_SAMPLE=""
  _SS_LONG_SAMPLE="${_lgs:-}"
  [[ "$_SS_LONG_SAMPLE" == "-" ]] && _SS_LONG_SAMPLE=""
  return 0
}

# 文構造の機械検出 (体言止め bullet / 矢印チェーン / 同一文末3連続 / 100字超文 / 敬体混入)。warn-only。
# _check_sentence_structure_counts の wrapper。引数は counts 版と同一。
# 出力: warn 文字列 (検出ゼロなら空)。外向き経路 (_block_if_ai_jargon) はこちらを使う。
_check_sentence_structure() {
  _check_sentence_structure_counts "$1" "${2:-0}" "${3:-0}"
  local out=""
  (( _SS_KANJI_CNT > 0 )) && out="連続漢字≥5: ${_SS_KANJI_CNT}種 (${_SS_KANJI_SAMPLE}) → 助詞挿入/訓読み開く; "
  (( _SS_TOUTEN > 0 )) && out="${out}読点≥4の文: ${_SS_TOUTEN}個 → 文分割; "
  (( _SS_TAIGEN > 0 )) && out="${out}体言止めbullet: ${_SS_TAIGEN}行 → 文として閉じる (〜する/〜した); "
  (( _SS_ARROW > 0 )) && out="${out}矢印チェーン: ${_SS_ARROW}行 → 文章に展開; "
  (( _SS_REP > 0 )) && out="${out}同一文末3連続: ${_SS_REP}箇所 → 文末を変える; "
  (( _SS_LONG > 0 )) && out="${out}100字超文: ${_SS_LONG}文 → 文分割; "
  (( _SS_POLITE > 0 )) && out="${out}敬体混入: ${_SS_POLITE}文 → 常体に統一; "
  (( _SS_FLAT > 0 )) && out="${out}平坦 bullet ≥11 + 理由語含み: ${_SS_FLAT}group → 親子に組み替え (PRINCIPLES.md ## 箇条書き階層化); "
  (( _SS_TIME > 0 )) && out="${out}時限マーカー: ${_SS_TIME}件 (${_SS_TIME_SAMPLE}) → 時制中立表現に (pr-description.md ### 時限マーカー禁止); "
  (( _SS_STUFF > 0 )) && out="${out}括弧詰め込み: ${_SS_STUFF}件 (${_SS_STUFF_SAMPLE}) → 括弧の名詞羅列を本文の文に開く (PRINCIPLES.md ### 圧縮文を開く); "
  [[ -n "$out" ]] && printf '%s' "${out%; }"
  return 0
}
