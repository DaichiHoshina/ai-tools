#!/usr/bin/env python3
"""churn pattern + noise 除去後「真 churn」集計 (2026-06-03)"""
import sys, json, glob, os, re, getpass
from collections import Counter
from datetime import datetime, timezone

PROJ = os.path.expanduser("~/.claude/projects")
# literal username を避け、実行 user から slug を導出する
_USER = getpass.getuser()
# ドット区切りをハイフンに変換 (例: first.last → first-last)
_USER_SLUG = _USER.replace(".", "-")
_HOME_SLUG = f"-Users-{_USER_SLUG}"
FROM = sys.argv[1] if len(sys.argv) > 1 else "2026-05-27"
TO = sys.argv[2] if len(sys.argv) > 2 else "2026-06-04"  # exclusive
SCOPE = sys.argv[3] if len(sys.argv) > 3 else "ai-tools"

dt_from = datetime.fromisoformat(FROM).replace(tzinfo=timezone.utc)
dt_to = datetime.fromisoformat(TO).replace(tzinfo=timezone.utc)

if SCOPE == "ai-tools":
    # CHURN_PROJ_DIR_AI_TOOLS env で個別 override 可 (CI 等で任意パス指定)
    # 注意: env 値に glob wildcard を含めない (default 値の末尾 `*` と二重展開 `*/**/*.jsonl` になり意図せぬ match を起こす)
    _dir = os.environ.get("CHURN_PROJ_DIR_AI_TOOLS", f"{PROJ}/{_HOME_SLUG}-ai-tools*")
    files = glob.glob(f"{_dir}/**/*.jsonl", recursive=True)
    files += glob.glob(f"{_dir}/*.jsonl")
else:
    files = glob.glob(f"{PROJ}/**/*.jsonl", recursive=True)
files = sorted(set(files))

patterns = {
    "再度/もう一度": re.compile(r"再度|もう一度|もう1度"),
    "修正/直して": re.compile(r"修正して|直して"),
    "違う/そうじゃない": re.compile(r"違う|そうじゃない|ちがう"),
    "勝手に": re.compile(r"勝手に"),
    "つまり？": re.compile(r"つまり[？?]|つまり$"),
    "どういうこと？": re.compile(r"どういうこと"),
    "/reload": re.compile(r"command-name>/reload<|^/reload\b"),
    "/dev": re.compile(r"command-name>/dev<|^/dev\b"),
    "/review": re.compile(r"command-name>/review<|^/review\b"),
    "/flow": re.compile(r"command-name>/flow<|^/flow\b"),
    "/memory-save": re.compile(r"command-name>/memory-save<|^/memory-save\b"),
}

# noise 除外用 regex
# 疑問形「何が〜違う」「と〜違う(の|か|?)」「とは〜違う」は比較疑問であり frustration でない
_re_chigau_noise = re.compile(r"何が.{0,8}違う|と.{0,4}違う[のか？?]|とは.{0,4}違う")
# 真の churn やり直し不満: 勝手に / リバート / 戻して / 一旦戻 を含む場合のみ
_re_fix_true = re.compile(r"勝手に|リバート|戻して|一旦戻")
# command 呼び出し or assistant 引用 (先頭リスト/結論/長文) は理解 churn でない
_re_doco_quote = re.compile(r"^(結論:|[-•] )", re.MULTILINE)

def is_noise_chigau(txt: str) -> bool:
    return bool(_re_chigau_noise.search(txt))

def is_true_fix_churn(txt: str) -> bool:
    # 修正/直して pattern が hit した message の真 churn 判定
    return bool(_re_fix_true.search(txt))

def is_noise_dokodoco(txt: str, is_cmd: bool) -> bool:
    # コマンド呼び出し or assistant 引用 (引用構造 or 120 字超) は除外
    if is_cmd:
        return True
    if len(txt) > 120:
        return True
    if _re_doco_quote.search(txt):
        return True
    return False

counts = Counter()
true_churn = Counter()  # noise 除去後
total_user = 0
short_msgs = []
short_counter = Counter()
seen_uuid = set()

def text_of(msg):
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        out = []
        for b in c:
            if isinstance(b, dict) and b.get("type") == "text":
                out.append(b.get("text", ""))
        return "\n".join(out)
    return ""

for fp in files:
    try:
        with open(fp) as f:
            for line in f:
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if d.get("type") != "user":
                    continue
                if d.get("isMeta") or d.get("isSidechain"):
                    continue
                u = d.get("uuid")
                if u in seen_uuid:
                    continue
                ts = d.get("timestamp")
                if not ts:
                    continue
                try:
                    t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                except ValueError:
                    continue
                if not (dt_from <= t < dt_to):
                    continue
                txt = text_of(d.get("message", {})).strip()
                is_cmd = "<command-name>" in txt
                if not is_cmd and txt.startswith("<") and (
                    "caveat" in txt[:60].lower()
                    or "local-command" in txt[:60].lower()
                    or "tool_use" in txt[:60].lower()
                ):
                    continue
                if not txt:
                    continue
                seen_uuid.add(u)
                total_user += 1

                for name, pat in patterns.items():
                    if pat.search(txt):
                        counts[name] += 1
                        # noise 除去ロジック
                        if name == "違う/そうじゃない":
                            if not is_noise_chigau(txt):
                                true_churn[name] += 1
                        elif name == "修正/直して":
                            if is_true_fix_churn(txt):
                                true_churn[name] += 1
                        elif name in ("つまり？", "どういうこと？"):
                            if not is_noise_dokodoco(txt, is_cmd):
                                true_churn[name] += 1
                        else:
                            true_churn[name] += 1

                if len(txt) <= 20 and not is_cmd:
                    short_counter[txt] += 1
    except (OSError, UnicodeDecodeError) as e:
        # file open / read 失敗は silent skip でなく stderr に WARN を出す
        print(f"[WARN] skip {fp}: {type(e).__name__}: {e}", file=sys.stderr)
        continue

days = (dt_to - dt_from).days
print(f"=== scope={SCOPE} range={FROM}〜{TO}(excl) days={days} files={len(files)} ===")
print(f"total user msg (dedup, real): {total_user}")
print(f"短文 (<=20 chars): {sum(short_counter.values())} ({sum(short_counter.values())/max(total_user,1)*100:.1f}%)")
print()
print(f"{'pattern':<18}{'count':>7}{'per_day':>9}")
for name in patterns:
    c = counts[name]
    print(f"{name:<18}{c:>7}{c/max(days,1):>9.1f}")
print()
print("=== churn 重点 (frustration 系) ===")
frust = ["再度/もう一度","修正/直して","違う/そうじゃない","勝手に","つまり？","どういうこと？"]
for name in frust:
    print(f"  {name:<16} {counts[name]:>4}  ({counts[name]/max(days,1):.2f}/d)")
print(f"  つまり？+どういうこと？ 合計: {counts['つまり？']+counts['どういうこと？']} ({(counts['つまり？']+counts['どういうこと？'])/max(days,1):.2f}/d)")
print()
print("=== 短文 top 12 ===")
for txt, c in short_counter.most_common(12):
    print(f"  {c:>3}  {txt!r}")

# ── 真 churn (noise 除去後) ──────────────────────────────────────────────
# 再度/もう一度 は「再度出力」(正常反復) と「再度 PR 作成」(真 churn) の機械判別が
# 困難なため自動除外せず raw のまま。合計は手動分類が要る前提で再度を除外した値を出す。
auto_frust = [n for n in frust if n != "再度/もう一度"]
frust_true_total = sum(true_churn[n] for n in auto_frust)
frust_raw_total  = sum(counts[n] for n in auto_frust)
print()
print("=== 真 churn (noise 除去後、再度を除く自動分類) ===")
print(f"{'pattern':<18}{'raw':>6}{'true':>7}{'true/d':>9}")
for name in frust:
    raw = counts[name]
    tc  = true_churn[name]
    note = "  ← 手動分類要" if name == "再度/もう一度" else ""
    print(f"{name:<18}{raw:>6}{tc:>7}{tc/max(days,1):>9.2f}{note}")
print(f"  {'合計(再度除く)':<14}{frust_raw_total:>6}{frust_true_total:>7}{frust_true_total/max(days,1):>9.2f}")
