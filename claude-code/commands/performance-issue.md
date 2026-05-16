---
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, AskUserQuestion
description: Performance improvement issue management — measure → pprof → iterative improve → load test
---

# /performance-issue - Performance improvement flow

Manage measure → analyze → iteratively improve → load test. Accumulate work logs in issue comments.

## Input

Get issue number or task summary from `$ARGUMENTS`. If none, confirm w/ AskUserQuestion.

## Flow

| Phase | Action | Deliverable |
|-------|---------|--------|
| 1. Gather info | Read issue/ticket, explore related resources | Link collection |
| 2. Benchmark foundation | Identify target code, document run command・profile-capture method | Command + measure conditions |
| 3. Pre-improve measure | Run benchmark, save raw log | Results + bottleneck analysis |
| 4. pprof analysis | Capture profile → analyze → declare next actions | CPU/IO judgment + improve priority |
| 5. Iterative improve | **1 improve = 1 measure**. Compare before/after | Checklist + verify effect |
| 6. Scope judge | Judge "do / send to different ticket" w/ evidence | Decision + Design Doc draft |
| 7. Load test | Run load test in dev env | Result link |
| 8. Release task | Checklist: DesignDoc/BE/FE/test/release | PR# ・estimate |

## Phase 4: pprof分析（詳細）

### Profile capture command (Go)

```bash
go test -tags serial \
  -bench={benchmark-name} -benchmem -benchtime=1x \
  -cpuprofile /tmp/{name}.cpu.pprof \
  -blockprofile /tmp/{name}.block.pprof \
  -trace /tmp/{name}.trace \
  -run='^$' ./{package}/
```

### Analysis commands

```bash
# CPU: which functions consume CPU time
go tool pprof -top -cum {file}.cpu.pprof
go tool pprof -top -flat {file}.cpu.pprof

# Block: where goroutines block
go tool pprof -top {file}.block.pprof
```

### Decision criteria

| CPU sample rate | Judgment | Next action |
|-------------|------|--------------|
| High (>20%) | CPU bound | Improve algorithm, reduce computation |
| Medium (10-20%) | Mixed | Block profile + trace re-judge I/O wait vs CPU ratio, both improveable |
| Low (<10%) | I/O bound | Reduce DB round-trips, bulk, optimize query |

| flat top high | Meaning |
|-------------|------|
| syscall/runtime | DB I/O wait center. No Go-side CPU improve room |
| App code function | That function is hotspot. Code improve target |

### Issue comment format

```markdown
## Profile analysis ({method name})

### Measure conditions
- Benchmark: `{name}`
- Results: `{time} / {memory} / {allocs}`
- Machine: {CPU} / {DB env}

<details>
<summary>CPU Profile analysis</summary>

{flat top table + cumulative top + findings}

</details>

<details>
<summary>Block Profile analysis</summary>

{wait time breakdown + findings}

</details>

### Conclusion
{CPU bound / I/O bound judgment, bottleneck identify, next actions}
```

## Principles

1. **Measure-first**: Always benchmark before & after improvement
2. **Iterative improve**: Verify effect per 1 improvement. Don't do all at once
3. **Work log aggregate**: Record all consideration・measure・analysis・judgment in issue/ticket
4. **Raw data attached**: Body = summary + analysis, raw log = separate file
5. **Use `<details>`**: Fold long analysis
6. **Scope judgment explicit**: Declare "do / send" w/ evidence

## Fail behavior

| Scenario | Action |
|------|------|
| Issue # get fail | AskUserQuestion request issue URL, if no response, proceed Phase 1 w/ local summary only |
| pprof capture fail (compile fail・bench absent) | Propose ad-hoc measure cmd, re-try after user confirm |
| Post-improve measure worse detected | Propose rollback, defer cause analysis back to Phase 4 |

ARGUMENTS: $ARGUMENTS
