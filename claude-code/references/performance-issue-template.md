---
name: performance-issue-template
description: Template for performance improvement issues — measure → pprof → incremental fix → load test flow.
type: reference
---

# Performance Issue Template

Template for what to record in an issue. Uses Go `pprof` as example; the measure→analyze→incremental-fix→load-test flow is language-agnostic.

## Phase 1: Research & information gathering

Paste links to design notes, prior load test records, and discussion threads in issue comments.

```markdown
Design notes: {URL}
Prior load test records: {Datadog Notebook / Grafana / internal wiki}
Discussion threads: {chat URL}
```

Key: always search for similar past tests / consolidate exploratory info in issue.

## Phase 2: Benchmark infrastructure

Set up measurement environment before starting; document run instructions in issue.

```markdown
## Benchmark command
{command}

### Profile capture
{cpuprofile / blockprofile / trace command}

## Benchmark code
Based on code with changes from #{PR number}.

### Reading notes
{what is being measured / local measurement / relative comparison, not absolute values}
```

Key: document measurement conditions and assumptions (parallelism, delay, machine) / explain "what number this is" / reproducible commands.

## Phase 3: Record pre-improvement baseline

```markdown
## Pre-improvement benchmark
{results}
- Raw log: [bench-00-before-improvement.log](attachment)

### State analysis
#### Overall assessment
- {primary bottleneck}
#### {condition} analysis
- {condition A}: {observation}
```

Key: attach raw log (body shows result rows only) / include assessment + analysis, not just numbers.

## Phase 4: pprof analysis (Go example)

Substitute equivalent profiler for other languages (Python: cProfile / Node: --prof / Ruby: stackprof).

### Capture command

```bash
go test -tags serial \
  -bench={bench-name} -benchmem -benchtime=1x \
  -cpuprofile /tmp/{name}.cpu.pprof \
  -blockprofile /tmp/{name}.block.pprof \
  -trace /tmp/{name}.trace \
  -run='^$' ./{package}/
```

### Analysis commands

```bash
go tool pprof -top -cum {file}.cpu.pprof    # cumulative (includes callers)
go tool pprof -top -flat {file}.cpu.pprof   # flat (self consumption)
go tool pprof -top {file}.block.pprof       # goroutine block
```

### Decision criteria

| CPU sample rate | Meaning | Next action |
|---|---|---|
| High >20% | CPU bound | App optimization (algorithm improvement) |
| Low <10% | I/O bound | Reduce DB round-trips, batching, query optimization |

| flat top | Meaning |
|---|---|
| syscall / runtime | DB I/O wait dominant, no CPU optimization margin |
| App code functions | Hotspot, target for improvement |

### Comment format

```markdown
## Profile analysis ({method} {scale})

### Measurement conditions
- Benchmark: `{name}`
- Result: `{time} / {memory} / {allocs}`
- Machine: {CPU} / Docker DB {version}

<details><summary>CPU Profile</summary>{flat top + cumulative + findings}</details>
<details><summary>Block Profile</summary>{wait time breakdown + findings}</details>

### Conclusion
{CPU/I/O bound determination, bottleneck identification, next action}
```

Key: **capture twice — before and after improvement** (before: identify culprit / after: remaining issues) / collapse with `<details>` / include prompt when using AI analysis / declare next action in 1 line.

## Phase 5: Incremental improvement and measurement

**1 improvement = 1 comment**. Split small, measure after each step.

```markdown
## {improvement category}
- [x] {target 1}
- [ ] {not started}

### 1st: {specific improvement}
{results}
{analysis (comparison to prior, per-condition changes, side effects)}
Raw log: [bench-01-{name}.log](attachment)

### 2nd: {next improvement}
{same format}

## Assessment
{results so far and next decision}
```

Key: measure one at a time / explicitly note effect (positive/negative) at each step / include separate-issue decision in assessment.

## Phase 6: Scope decision & design doc

```markdown
{initiative name} summary:
- {relationship to other issues}
- {backward compatibility}
- {coverage of current fix}

{scope decision conclusion}

<details><summary>Design Doc draft</summary>
### {design name}
{table design / query design / compatibility}
#### Rejected options
- {rejected option and reason}
</details>
```

Key: clearly separate "do now" from "next issue" / leave future design proposals as DesignDoc draft / document decision basis.

## Phase 7: Load test

```markdown
## Load test results
{Datadog Notebook / Grafana URL}
```

Key: record results in monitoring tool, issue holds link only / run in dev environment separate from local bench.

## Phase 8: Release tasks

```markdown
## Release tasks
- DesignDoc: [ ] write {URL} / [ ] review
- Backend: [ ] {task 1} ({estimate}) #{PR} / [ ] review
- Frontend: [ ] {task} ({estimate}) #{PR} / [ ] review
- Test: [ ] dev environment
- Release: [ ] Backend / [ ] Frontend

### Notes
- DB schema change: {yes/no}
- Backward compatibility: {details}
```

Key: link PR number per task / include estimates / checklist review items / note schema changes and compatibility in notes.
