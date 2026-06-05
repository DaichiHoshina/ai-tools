#!/usr/bin/env python3
"""developer-agent の成功率 / cost / latency 計測。
成功判定: 最終 assistant が text content で締めていれば成功 (stop_reason は欠落あり、
値に依存しない)。stop_reason='end_turn' は明示成功、tool_use のみで末尾 text 無しは途中切断。
引数: <from> <to(exclusive)>、省略時は内蔵 default 日付。
"""
import glob, json, os, sys, statistics
from datetime import datetime, timezone

PROJ = os.path.expanduser("~/.claude/projects")
FROM = sys.argv[1] if len(sys.argv) > 1 else "2026-05-27"
TO = sys.argv[2] if len(sys.argv) > 2 else "2026-06-04"
df = datetime.fromisoformat(FROM).replace(tzinfo=timezone.utc)
dt = datetime.fromisoformat(TO).replace(tzinfo=timezone.utc)

# Anthropic API 概算単価 (sonnet, USD per token)
P_IN = 3.0 / 1e6
P_OUT = 15.0 / 1e6
P_CACHE_W = 3.75 / 1e6   # 5m write
P_CACHE_R = 0.30 / 1e6

files = sorted(set(glob.glob(f"{PROJ}/**/subagents/agent-*.jsonl", recursive=True)))

def ts_parse(s):
    if not s: return None
    try: return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except: return None

def has_tail_text(msg):
    c = msg.get("content")
    if isinstance(c, str): return bool(c.strip())
    if isinstance(c, list):
        for b in c:
            if isinstance(b, dict) and b.get("type") == "text" and b.get("text", "").strip():
                return True
    return False

calls = []  # 1 file = 1 call
for fp in files:
    try:
        rows = []
        agent_type = None
        for line in open(fp):
            try: d = json.loads(line)
            except: continue
            if d.get("attributionAgent"):
                agent_type = d["attributionAgent"]
            rows.append(d)
        if agent_type != "developer-agent":
            continue
        # 時刻 filter: file 内の最初の timestamp
        first_t = None
        for d in rows:
            t = ts_parse(d.get("timestamp"))
            if t: first_t = t; break
        if not first_t or not (df <= first_t < dt):
            continue
        # token 集計: 全 assistant 行の usage を add
        tin = tout = tcw = tcr = 0
        last_assistant = None
        times = []
        for d in rows:
            t = ts_parse(d.get("timestamp"))
            if t: times.append(t)
            if d.get("type") == "assistant":
                m = d.get("message", {})
                u = m.get("usage", {}) or {}
                tin += u.get("input_tokens", 0) or 0
                tout += u.get("output_tokens", 0) or 0
                tcw += u.get("cache_creation_input_tokens", 0) or 0
                tcr += u.get("cache_read_input_tokens", 0) or 0
                last_assistant = m
        if last_assistant is None:
            continue
        # 成功判定: 最終 assistant が text で締めていれば正常完了 (stop_reason は欠落あり)。
        # end_turn は明示的成功。tool_use のみで text 無しは途中切断とみなす。
        sr = last_assistant.get("stop_reason")
        success = (sr == "end_turn") or has_tail_text(last_assistant)
        # latency: file 内 timestamp の min-max 差
        lat = (max(times) - min(times)).total_seconds() if len(times) >= 2 else 0.0
        cost = tin*P_IN + tout*P_OUT + tcw*P_CACHE_W + tcr*P_CACHE_R
        calls.append({
            "fp": os.path.basename(fp), "success": success, "stop_reason": sr,
            "cost": cost, "lat": lat,
            "tin": tin, "tout": tout, "tcw": tcw, "tcr": tcr,
        })
    except Exception:
        continue

n = len(calls)
print(f"=== developer-agent 再計測 range={FROM}〜{TO}(excl) ===")
print(f"n (call) = {n}")
if n == 0:
    print("該当なし"); sys.exit(0)

succ = sum(1 for c in calls if c["success"])
print(f"成功率: {succ}/{n} ({succ/n*100:.1f}%)")
# stop_reason 内訳
from collections import Counter
srcnt = Counter(c["stop_reason"] for c in calls)
print(f"stop_reason 内訳: {dict(srcnt)}")
fails = [c for c in calls if not c["success"]]
if fails:
    print(f"  非成功 {len(fails)} 件 (stop_reason): {[c['stop_reason'] for c in fails]}")

def stats(key, fmt="{:.3f}"):
    vals = sorted(c[key] for c in calls)
    mean = statistics.mean(vals)
    med = statistics.median(vals)
    p95 = vals[min(len(vals)-1, int(len(vals)*0.95))]
    mx = vals[-1]
    return f"mean {fmt.format(mean)} / median {fmt.format(med)} / p95 {fmt.format(p95)} / max {fmt.format(mx)}"

print(f"cost (USD): {stats('cost', '${:.3f}')}")
print(f"latency (s): {stats('lat', '{:.0f}s')}")
print()
print("token mean/call:")
for k, lbl in [("tin","in"),("tcw","cache_w"),("tcr","cache_r"),("tout","out")]:
    print(f"  {lbl:<9} {statistics.mean(c[k] for c in calls):>12,.0f}")
print()
print("=== cost top 5 (outlier 確認) ===")
for c in sorted(calls, key=lambda x:-x["cost"])[:5]:
    print(f"  ${c['cost']:.2f}  lat={c['lat']:.0f}s  cache_r={c['tcr']:,}  {c['fp']}")
