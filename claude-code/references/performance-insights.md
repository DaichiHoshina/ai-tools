# Claude Code Performance Insights

Measurement-based (initial 2026-04-22, re-measured 2026-05-18). Hook/agent cost structure, measurement pitfalls, re-measurement commands.

## Hook Measurement Pitfalls

**First run is 5-7× slower due to cold cache.**

| hook | First run (misleading) | Warm 5-sample avg |
|------|-----------------------|------------------|
| subagent-start.sh | 520ms | **98ms** |
| session-start.sh | 660ms | **90ms** |
| pre-tool-use.sh | — | 30ms |
| post-tool-use.sh | — | 52ms |
| user-prompt-submit.sh | — | 50ms |
| subagent-stop.sh | — | 100ms |

**Lesson**: Always measure with warmup + 5+ sample average. Judging from first-run values only is misleading.

## Hook New Baseline (measured 2026-05-18)

`hook-bench.sh` (warmup=5, runs=15). bash spawn baseline = 33ms.

| hook | median | p95 | vs 2026-04-22 |
|------|--------|-----|--------------|
| pre-tool-use.sh | 64ms | 89ms | +34ms |
| setup.sh | 63ms | 81ms | — |
| permission-denied.sh | 72ms | 84ms | — |
| teammate-idle.sh | 79ms | 106ms | — |
| post-tool-use.sh | 84ms | 101ms | +32ms |
| user-prompt-submit.sh | 98ms | 136ms | +48ms |
| post-tool-use-failure.sh | 98ms | 131ms | — |
| task-completed.sh | 106ms | 122ms | — |
| subagent-start.sh | 112ms | 145ms | +14ms |
| session-end.sh | 117ms | 134ms | — |
| subagent-stop.sh | 120ms | 155ms | +20ms |
| session-start.sh | 125ms | 157ms | +35ms |
| post-compact-reload.sh | 127ms | 181ms | — |

**+30–50ms heavier vs 04-22**, but absolute values are all p95 < 200ms. Does not reach perceptible lag threshold (>300ms). **True cost source is agent LLM time** — unchanged. Regression threshold: p95 > 300ms.

Perceived lightness improvement (user report 2026-05-18) is estimated to be driven by **`name-only` skill definition (settings.json 16 entries) + MCP deferred initialization** reducing initial token consumption, not the hook layer.

## Cost Structure (hook vs agent) (small sample, reference values)

ms-level vs minute-level — orders of magnitude apart.

| Layer | Actual time | Notes |
|-------|-------------|-------|
| All hooks (warm) | 30–100ms | N≥15, high confidence |
| developer-agent | **median 101s** (n=31, p25=58s p75=137s) | n=31, high confidence |
| manager-agent | ~42s | n=2, reference only |
| reviewer-agent | ~82s | n=27 |
| po-agent | ~96s | n=9, reference only |
| Explore (built-in) | ~99s | n=79 |
| **general-purpose** | **115s (max 501s)** | n=21 |
| explore-agent | ~123s | n=7, reference only |

> **Note**: developer-agent updated to 2026-05-23 actual measurement n=31 median=101s / avg=113s. Old value (n=4 avg=60s) is a past reference. **n<10 values require re-measurement.**

**True cost source is agent LLM time.** Hook optimization (shaving <100ms) has poor ROI. Improve by reducing agent launch frequency.

## Agent Measurements and Sample Confidence (small sample, reference values)

subagent-events.log aggregation (2026-04-06–2026-04-22) + 2026-05-23 additional measurements.

| agent | N | avg | max | Notes |
|-------|---|-----|-----|-------|
| Explore (built-in) | 79 | 99s | 310s | Highest usage frequency |
| reviewer-agent | 27 | 82s | 161s | Opus + comprehensive-review |
| general-purpose | 21 | **115s** | **501s** | **Avoid** |
| po-agent | 9* | 96s | 365s | Strategic decision-making |
| explore-agent | 7* | 123s | 289s | Haiku but broad task scope |
| manager-agent | 2* | 42s | 68s | Planning only, lightweight |
| developer-agent (haiku) | 17 | 291s | 739s | haiku avg, 2026-04 measurement |
| developer-agent (sonnet) | **31** | **113s** | **451s** | **2026-05-23 actual, median 101s / p25 58s / p75 137s** |

`*` = N<10 (or n<10 equivalent) reference values (small sample, values may change with more data). Prefer N≥20 for operational decisions.

## Operational Rules (abuse prevention)

- 1-2 query investigations: **use Bash grep/find/mcp__serena__find_symbol directly, no agent launch**
- 3+ query broad exploration only: `Task(explore-agent)` ×4 parallel launch
- Claude Code CLI/SDK/API spec questions: `claude-code-guide` agent
- `general-purpose`: not recommended in principle (N=21 measured, highest cost source)

Details: `claude-code/CLAUDE.md` "Discovery / Investigation Routing".

## Re-measurement Commands

### Agent actual time aggregation (all periods)

```bash
awk '
  /START/ { for(i=1;i<=NF;i++){if($i~/^agent_id=/){sub("agent_id=","",$i);id=$i};if($i~/^type=/){sub("type=","",$i);t=$i}}; gsub("\\[|\\]","",$1); cmd="date -j -f %Y-%m-%dT%H:%M:%SZ " $1 " +%s 2>/dev/null"; cmd|getline e; close(cmd); s[id]=e; ty[id]=t }
  /STOP/  { for(i=1;i<=NF;i++){if($i~/^agent_id=/){sub("agent_id=","",$i);id=$i}}; gsub("\\[|\\]","",$1); cmd="date -j -f %Y-%m-%dT%H:%M:%SZ " $1 " +%s 2>/dev/null"; cmd|getline e; close(cmd); if(id in s){d=e-s[id]; sum[ty[id]]+=d; cnt[ty[id]]++; if(d>max[ty[id]])max[ty[id]]=d} }
  END { for(t in cnt) printf "%-22s N=%d avg=%.1fs max=%ds\n", t, cnt[t], sum[t]/cnt[t], max[t] }
' ~/.claude/logs/subagent-events.log | sort -k3 -t= -rn
```

### Hook warm measurement (5-sample average)

```bash
INPUT='{"session_id":"test","cwd":"/tmp","agent_id":"a","agent_type":"t"}'
for h in subagent-start.sh session-start.sh pre-tool-use.sh post-tool-use.sh; do
  times=""
  for i in 1 2 3 4 5; do
    t=$({ /usr/bin/time -p bash -c "echo '$INPUT' | ~/.claude/hooks/$h >/dev/null 2>&1"; } 2>&1 | awk '/real/ {print $2}')
    times="$times $t"
  done
  avg=$(echo "$times" | awk '{for(i=1;i<=NF;i++)s+=$i; print s/NF}')
  printf "%-28s avg=%.3fs\n" "$h" "$avg"
done
```

### Team chain measurement (specific time range)

```bash
awk '/^\[2026-04-22T01:3[4-8]/' ~/.claude/logs/subagent-events.log
```

## Sonnet Delegation Overhead Measurement (2026-05-23 N=31 update)

`~/.claude/logs/subagent-events.log` actual (developer-agent sonnet launches N=31, 2026-05-23 same-day).

- Duration distribution: min=22s / p25=58s / median=101s / p75=137s / max=451s / avg=113s
- Lightweight task proxy (bottom 20%): 22, 27, 27, 39, 44, 56 seconds
- Delegate launch floor = 22s (startup overhead: Serena `activate_project` + prompt load). Tasks completing in <20s are clearly better inline
- vs haiku N=17 avg 291s: Sonnet switch **2.6× faster** (hypothesis that Sonnet is slower is rejected)
- Old value "avg 60s / max 91s" was n=2 outlier-based. N=31 shows significant upward revision. **n<10 values require re-measurement**
- Decision threshold: CLAUDE.md "Inline exceptions" threshold of "expected LLM execution <20s (1 symbol / 1 section fix)" is below delegate min (22s) — valid. 20-60s grey zone: maintain "when in doubt, delegate" principle. >60s: delegate is clearly better

## session-init-timing Log Measurement Infrastructure (since fbce383)

Infrastructure for continuous session startup time measurement. Used to accumulate 7–14 days of data to compare baseline against plugin count changes / Serena `~/.claude/projects/` count changes.

**Log / DB**:
- log: `~/.claude/logs/session-init-timing.log` (format: `[timestamp] session_id=X duration_ms=Y plugin_count=Z`, 1000-line circular)
- DB: `~/.claude/logs/analytics.db` `sessions` table, `init_duration_ms INTEGER DEFAULT 0` column

**Measurement hooks**:
- `claude-code/hooks/session-start.sh` L9 records `_SS_START_EPOCH=$(date +%s%N)`, L126 calculates elapsed ms and appends to log
- `claude-code/hooks/session-end.sh` greps duration from timing log and passes as 11th argument to `analytics_insert_session`

**Aggregation command**:

```bash
sqlite3 ~/.claude/logs/analytics.db 'SELECT AVG(init_duration_ms) FROM sessions GROUP BY DATE(start_ts)'
```
