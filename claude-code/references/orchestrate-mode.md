# Orchestrate Mode

Operation spec for parent agent launching N developer-agents in parallel to minimize makespan.

## Activation

Start with `/flow --orchestrate <task>`. Combination with `--auto` (`/flow --orchestrate --auto <task>`) is also valid.

User trigger examples:

- "並列実行で" → `/flow --parallel` (natural language trigger, see `natural-language-triggers.md`)
- "team で" / "agent team で" → `/flow` (PO→Manager→Dev hierarchy forced)
- Explicit `--orchestrate` flag → this mode applies directly
- "wt 分けて" → equivalent parallel launch

After activation, parent must complete all Pre-delegation steps before firing. Firing without completing steps causes in-subagent exploration, which is the primary cause of makespan increase.

## Pre-delegation steps (parent 必須)

Execute 4 steps in order and echo each output to chat.

1. **N calculation**: Count independent tasks, apply formula from `references/PARALLEL-PATTERNS.md`. Confirm N and output to chat (e.g., `N=3, formula PASS`). If N cannot be determined, downgrade to sequential.

2. **Target file:line echo**: Explicitly state file paths (absolute) and target lines for each subagent. Forbid passing "please explore" to subagents. If unidentified, parent runs `find_symbol` / `grep` first.

3. **Verify cmd echo**: Confirm the single verification command and output to chat (e.g., `bats tests/foo.bats` / `grep -c "^## " file.md`). For build/typecheck-required languages (TypeScript / Go), instruct subagent to run verify internally.

4. **DoD single-line echo**: Fix completion criteria in one sentence and output to chat (e.g., `6 sections present + 80-100 lines + formula duplication zero`).

Fire only after all 4 steps complete. Do not fire if any item is unconfirmed.


## Firing protocol

When parallel firing is decided, **write text 1 line + Task tool_use × N in the same assistant message**. This is the substance of parallelism — sending N tasks in separate messages waits for each previous agent's STOP, resulting in peak_concurrency=1.

Forbidden pattern:

- message 1: `Task(developer-agent, prompt=A)` → message 2: `Task(developer-agent, prompt=B)` (sequential firing)

Required pattern:

- message 1 contains both `Task(developer-agent, prompt=A)` and `Task(developer-agent, prompt=B)` simultaneously (parallel firing)

Details of parallelism formula (critical-path reduction formula): see `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula`. Not re-described here.

Same-file concurrent editing by multiple subagents is physically forbidden. Result dependency (B uses A's output) likewise requires sequential execution.

Before firing, self-review 3 points: "Are tasks independent?", "No same-file conflict?", "No result dependency?" — then place tool_use in message.

## Verify allocation

For build/typecheck-required languages (TypeScript / Go), run verify inside subagent. Otherwise parent runs inline verify after receiving each subagent's completion report.

Parent inline verify benefit: subagent A's verify and subagent B's launch can overlap, reducing makespan.

For commit-bearing tasks (pre-push confirmation required), run verify inside subagent as exception.

Criteria for verify ownership and exceptions: see `references/developer-agent-delegation-prompt.md` §2. Not re-described here.

## Fail behavior

| Case | Action |
|---|---|
| N calculation impossible (cannot determine independent task count) | Sequential downgrade + notify user ("N calculation impossible, switching to sequential") |
| Pre-delegation echo missing (file:line / verify cmd / DoD unconfirmed) | Stop firing; parent fills in unconfirmed items then re-execute |
| Subagent failure (timeout / retry exceeded) | Failed subagent only: sequential downgrade, parent runs inline; others continue in parallel |
| Non-parallel firing (N tool_use in separate messages) | Detect via `scripts/flow-baseline.sh --summary` `peak_concurrency distribution` skewed to 1; fix to same-message parallel on next firing |

Subagent failure retry limit follows developer-agent.md timeout/retry spec (Timeout 30min / Retry 2×).

If other subagents have already completed, parent runs failed subagent inline without delaying overall completion report.

After detecting sequential firing violation: add one self-review checklist on next similar task firing and enforce multiple tool_use in same message. On continued violation, measure peak_concurrency with `scripts/flow-baseline.sh --summary` and record.

## Related

- [`references/PARALLEL-PATTERNS.md`](PARALLEL-PATTERNS.md) — formula / N cap 8 / T_i estimation canonical definitions
- [`references/developer-agent-delegation-prompt.md`](developer-agent-delegation-prompt.md) — parent pre-delegation checklist + verify allocation details
- [`commands/flow.md`](../commands/flow.md) — `--orchestrate` activation entry and task type detection

> This file defines orchestrate mode operation spec only. Numerical criteria and formula details for parallelism are in canonical source (`PARALLEL-PATTERNS.md`).
