#!/usr/bin/env bash
# jp-textlint — 日本語 prose の機械可読性チェック (textlint 相当、手動起動)
# PRINCIPLES.md `## 文単位の品質規約` + NG-DICTIONARY.md を grep / python3 ベースで検査する。
# hook (pre-tool-use) は warn-only の軽量版 (連続漢字 / 読点) だが、本 script は文長も含む全観点を出す。
#
# 使い方:
#   ./scripts/jp-textlint.sh <file>
#   cat draft.md | ./scripts/jp-textlint.sh
#
# 終了コード: 検出ありでも 0 (informational)。固有名詞・技術用語の誤検知は無視可。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGDICT="${SCRIPT_DIR}/../guidelines/writing/NG-DICTIONARY.md"

if [[ $# -ge 1 && -f "$1" ]]; then
  text=$(cat "$1"); src="$1"
else
  text=$(cat); src="(stdin)"
fi

# code block / inline code を除去
# Bug1: 0-3sp インデント fence も対象 / Bug2: 未閉じ fence は prose 扱いに倒す (後続 drop 防止)
# Bug3: 2連 backtick ``foo`` を先に除去してから単一 `foo` を除去
# shellcheck disable=SC2016
_awk_fenceclean='{lines[NR]=$0} END{
  b=0; last_open=0
  for(i=1;i<=NR;i++){if(lines[i]~/^[[:space:]]{0,3}```/){b=!b;if(b)last_open=i}}
  unclosed_start=(b==1)?last_open:0; b=0
  for(i=1;i<=NR;i++){
    is_fence=(lines[i]~/^[[:space:]]{0,3}```/)
    if(is_fence&&i!=unclosed_start){b=!b}
    else if(i==unclosed_start){b=0;print lines[i]}
    else if(!b){print lines[i]}
  }}'
# shellcheck disable=SC2016
clean=$(printf '%s' "$text" | awk "$_awk_fenceclean" | sed -E 's/``[^`]*``/ /g; s/`[^`]*`/ /g')

issues=0
echo "## jp-textlint: ${src}"

# 1. 連続漢字 5 文字以上 (python3 で Unicode 正確判定)
if command -v python3 >/dev/null 2>&1; then
  kanji=$(printf '%s' "$clean" | python3 -c '
import sys, re, collections
c = collections.Counter(re.findall(r"[一-龯]{5,}", sys.stdin.read()))
for w, n in c.most_common():
    print(f"  {n:>3}  {w}")
' 2>/dev/null || true)
  if [[ -n "$kanji" ]]; then
    echo ""; echo "### 連続漢字 ≥5 (助詞挿入 / 訓読み開く で分割。固有名詞は除外可)"
    printf '%s\n' "$kanji"
    issues=$(( issues + $(printf '%s\n' "$kanji" | grep -c .) ))
  fi
fi

# 2. 読点 4 個以上の文 (。で改行分割してから行=文として数える、byte-safe)
# macOS awk はマルチバイト RS 非対応のため sed で改行化してから処理する
# 。を改行へ置換 (BSD/GNU sed 両対応の $'\n' 形式)。SC1003 は誤検出のため抑止
# shellcheck disable=SC1003
ten=$(printf '%s' "$clean" | sed 's/。/\'$'\n''/g' | awk '{ s=$0; n=gsub(/、/,"、"); if(n>=4){ gsub(/^[ \t\r]+/,"",s); print "  読点"n"個: " s "。" } }' || true)
if [[ -n "$ten" ]]; then
  echo ""; echo "### 読点 ≥4 の文 (文分割)"
  printf '%s\n' "$ten"
  issues=$(( issues + $(printf '%s\n' "$ten" | grep -c .) ))
fi

# 3. 文長 >100 字 (python3 で文字数カウント)
# heading 行 (^#) と空行を除去してから。で分割する。除去しないと heading が
# 直近句点までのブロックに巻き込まれ、1 文の字数が過大計上される。
if command -v python3 >/dev/null 2>&1; then
  longs=$(printf '%s' "$clean" | python3 -c '
import sys, re
lines = [l for l in sys.stdin.read().splitlines() if l.strip() and not l.lstrip().startswith("#")]
for s in re.split("。", "\n".join(lines)):
    s = s.strip()
    if len(s) > 100:
        print(f"  {len(s)}字: {s[:45]}…")
' 2>/dev/null || true)
  if [[ -n "$longs" ]]; then
    echo ""; echo "### 文長 >100 字 (分割の合図。短文媒体は 60 字)"
    printf '%s\n' "$longs"
    issues=$(( issues + $(printf '%s\n' "$longs" | grep -c .) ))
  fi
fi

# 4. 受身 2 連 /「の」3 連鎖 (文単位、references/writing-sentence-rules.md 準拠)
if command -v python3 >/dev/null 2>&1; then
  gram=$(printf '%s' "$clean" | python3 -c '
import sys, re
lines = [l for l in sys.stdin.read().splitlines() if l.strip() and not l.lstrip().startswith("#")]
for s in re.split("。", "\n".join(lines)):
    s = s.strip().replace("\n", " ")
    if not s:
        continue
    n = len(re.findall(r"(?:され|られ)(?:、|て|た|る|ます)", s))
    if n >= 2:
        print(f"  受身{n}回: {s[:45]}…" if len(s) > 45 else f"  受身{n}回: {s}")
    if re.search(r"の[^、。\s]{1,7}の[^、。\s]{1,7}の", s):
        print(f"  「の」3連鎖: {s[:45]}…" if len(s) > 45 else f"  「の」3連鎖: {s}")
' 2>/dev/null || true)
  if [[ -n "$gram" ]]; then
    echo ""; echo "### 受身 2 連 /「の」3 連鎖 (能動化 / 語順・動詞化で言い換え)"
    printf '%s\n' "$gram"
    issues=$(( issues + $(printf '%s\n' "$gram" | grep -c .) ))
  fi
fi

# 5. NG-DICTIONARY 語 hit (case-insensitive)
if [[ -f "$NGDICT" ]]; then
  ng_out=""
  for key in "AI定型語" "カタカナ造語禁止" "難読漢語 (block)" "非日常英語 (block)" "弱い表現 (block)" "冗長表現 (block)" "断定語 (warn-only)"; do
    line=$(grep -m1 "^\*\*${key}\*\*:" "$NGDICT" 2>/dev/null || true)
    [[ -z "$line" ]] && continue
    body="${line#*: }"
    terms=$(printf '%s' "$body" | tr '/' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' || true)
    [[ -z "$terms" ]] && continue
    hit=$(printf '%s' "$clean" | grep -ioFf <(printf '%s\n' "$terms") | sort -u | tr '\n' ',' | sed 's/,$//' || true)
    if [[ -n "$hit" ]]; then
      ng_out="${ng_out}  ${key}: ${hit}"$'\n'
      issues=$(( issues + 1 ))
    fi
  done
  if [[ -n "$ng_out" ]]; then
    echo ""; echo "### NG-DICTIONARY hit (削除 / 置換: guidelines/writing/PRINCIPLES-word-replace.md)"
    printf '%s' "$ng_out"
  fi
fi

echo ""
if [[ "$issues" -eq 0 ]]; then
  echo "✓ 機械検出 0 件 (連続漢字 / 読点 / 文長 / NG語)"
else
  echo "検出 ${issues} 件。固有名詞・技術用語の誤検知は無視可。詳細規範: guidelines/writing/PRINCIPLES.md"
fi
