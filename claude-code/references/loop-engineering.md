# Loop Engineering

> **Source**: @0xCodez "Loop engineering: 14-step roadmap from prompter to loop designer" (X, 2026-06-10, 4.36M views). Thread cites Anthropic engineering docs (December 2024 "Building Effective Agents" evaluator-optimizer pattern), Addy Osmani long-form on loop engineering, AlphaSignal analysis, and Geoffrey Huntley ("Ralph Wiggum loop" naming).

For two years, leverage in coding agents lived at the prompt. Loop engineering moves it one floor up: the system that decides what agents work on, when, with what gate, and what state survives the session boundary. Anthropic engineers report an "8x merge rate" on looped CI triage and dependency-bump tasks — not from better prompts, but from structured iteration with objective gates.

---

## When to build a loop (4-condition test)

| Condition | Why it matters | Fail mode |
|---|---|---|
| Task repeats (weekly+) | Setup cost amortizes across runs | One-time job → good prompt is faster |
| Verification is automated | Loop fails work without you in the room | Manual review → back in the chair |
| Token budget absorbs waste | Loops re-read context, retry, explore | Metered plan → surprise invoice |
| Agent has senior tools (logs / repro env / run code) | Iteration with feedback | Blind iteration → quiet fail |

Miss one condition → don't build the loop.

## 30-second loop check (per task)

Before launching any loop, verify all 5:

1. ☐ Task happens at least weekly
2. ☐ Test / type / build / linter can reject bad output
3. ☐ Agent can run the code it changes (repro env)
4. ☐ Hard stop exists (token budget / iteration cap / time limit)
5. ☐ Human reviews irreversible actions (merge / deploy / dep change)

**Good first loops vs. bad first loops**

| Good | Bad |
|---|---|
| CI triage (failing test → PR) | Architecture rewrites |
| Dependency bumps (bot-style) | Auth / payments code |
| Lint-and-fix | Production deploys |
| Flaky test repro + isolation | Vague product work |
| Issue-to-PR on tested code | Judgment calls with no automated signal |

## 5 Building Blocks

### Automation

Cadence startup: schedule / event / trigger. In Claude Code: `/loop` (session-scoped, ends on session end) / Desktop scheduled tasks (restart-survival) / Routines (cloud) / hooks (lifecycle events).

`/loop` vs `/goal` distinction:
- `/loop` — cadence-driven ("every push", "every hour")
- `/goal` — stop-condition-driven ("keep iterating until all tests pass")

For objective-gate enforcement, `/goal` is the primary defense against the Ralph Wiggum loop (see § Failure modes). `commands/goal.md` for spec.

### Worktree

Parallel branches without collision. In ai-tools, `[[ai-tools-worktree-workflow]]` is canonical (CLAUDE.md §Quick Reference). Each worktree is a fully isolated checkout; N agents can mutate separate file groups simultaneously without lock contention. Details: `references/PARALLEL-PATTERNS.md`.

### Skill

Project knowledge as a compounding asset. A `SKILL.md` (or equivalent) is re-read at loop start each run, eliminating repeated context re-derivation. In ai-tools: `skills/` is the canonical skill registry (run `ls skills/` for current count); the `/flow` hierarchy reloads them per-session via session-start hook. Skill files are the primary defense against goal drift across sessions.

### Connector (MCP)

External tools that close the feedback loop: GitHub / Linear / Slack / Sentry. In ai-tools: Serena / context7 / playwright are configured; GitHub interaction goes through `gh` CLI (not GitHub MCP — see § ai-tools mapping). Connectors let the loop read real state (CI status, open issues, error alerts) rather than operating on assumptions.

### Sub-agent (maker/checker separation)

Anthropic 2024-12 "evaluator-optimizer" pattern: separate the agent that produces work (maker) from the agent that rejects or approves it (checker). Checker must not see maker reasoning — only the output. Where possible, use a different model for checker to avoid shared bias. In Claude Code: `.claude/agents/` for agent definitions. In Codex: `.codex/agents/`.

In ai-tools: `developer-agent` (maker) + `reviewer-agent` Stage A 7-observation gate (checker). See `references/auto-delegation-detailed.md` for delegation protocol.

## Minimum viable loop (MVL)

Four parts, strict order:

1. **One automation** (`/loop` or `/goal` — start with manual, then automate)
2. **One skill** (`SKILL.md` — project context persists across runs)
3. **One state file** (markdown or Linear / GitHub Issues — tomorrow's run resumes from here)
4. **One gate** (objective: test / type / build / lint exit code — no subjective verifiers)

**Order is fixed. Do not skip steps.**

```
manual run reliable → skill-ify → loop-ify → schedule
```

Attempting to schedule before a manual run is reliable means the loop runs reliably wrong.

**KPI**: cost per accepted change. If accepted-change rate < 50%, the loop costs more than it produces — revert to prompted runs and fix the gate first.

## State file pattern

| Placement | When | Notes |
|---|---|---|
| `STATE.md` at repo root or `.claude/` | Solo / small team | Version-controlled; loop reads on start, writes on end |
| Linear / GitHub Issues | Team-wide / production | Cross-team visibility; no file-level conflicts |

Minimal schema: `last_run`, `completed[]`, `in_progress`, `blocked[]`, `next`.

Long-running loops add `VISION.md` or `AGENTS.md` alongside state — state tracks *where*, vision tracks *where to go*. Without vision, goal drift erases "don't touch X" constraints at context-boundary summarization (see § Failure modes).

## Failure modes

| Failure | Symptom | Mitigation |
|---|---|---|
| **Ralph Wiggum loop** (Huntley naming) | Agent emits completion token early; loop exits half-done | Objective gate (test / build / lint exit code) — not a subjective verifier. `/goal` with hard stop condition |
| **Goal drift** | "Don't do X" disappears at turn 47 via lossy summarization | Standing `VISION.md` / `AGENTS.md` re-read each run; `hooks/post-compact-reload.sh` re-injects after `/compact` |
| **Self-preferential bias** | Maker grades own homework, always returns "A+" | Separate checker agent; no exposure to maker reasoning chain |
| **Agentic laziness** | Declares "done enough" at partial completion | `/goal` with objective stop-condition evaluated by fresh model instance |

## Comprehension debt and cognitive surrender

Osmani identifies two risks that compound silently:

- **Comprehension debt**: faster loop → larger gap between what the repo does and what you understand. Bill arrives the day you debug a system no-one has read.
- **Cognitive surrender**: stop forming an opinion about correctness; accept what the loop returns. Ends with unreadable architecture.

Both are process failures, not technical ones. Mitigations: read diffs; spot-check gates (they rot); block loops from architecture / auth / payments / judgment-call work; pair-design loops with a teammate.

## Security tax

Four threats every production loop must budget for:

| Threat | Countermeasure |
|---|---|
| **Unreviewed PR merge** | SAST + dependency audit + secret scanning in gate before any merge action |
| **Skill injection** | Skill descriptions can carry prompt injection. Audit source before install. (520 of 17,022 audited skills in AlphaSignal analysis leaked credentials.) |
| **Credentials in logs** | Disable verbose logging in production loops; sanitize state files before commit |
| **Permission scope creep** | Re-audit agent permissions every 30 days; remove write access for connectors no longer used |

In ai-tools: `hooks/pre-tool-use.sh` blocks private-name leakage (see `rules/public-repo-private-data-block.md`). Skill source credential scanning is not yet implemented — manual audit required for new skills.

## ai-tools mapping

| 14-step concept | ai-tools existing | Gap |
|---|---|---|
| Automation (`/loop` `/goal`) | `commands/workflow.md` (deterministic fan-out) + `commands/goal.md` (`/goal` single-task gate) + `commands/flow.md --until-gate-green` (P0 loop を objective gate に切替) | `/loop` (cadence) not yet implemented; cron-based scheduling fills the gap for now |
| Worktree parallel | `[[ai-tools-worktree-workflow]]` + EnterWorktree | OK |
| Skills as compounding | `skills/` registry deployed (count via `ls skills/`) | OK |
| MCP connectors | Serena / context7 / playwright + `gh` CLI | GitHub MCP not configured; `gh` CLI fills gap for most cases |
| Maker/checker separation | `developer-agent` + `reviewer-agent` (Stage A 7-observation) | Both default to same model (Opus 4.7); checker separate-model enforcement is weak |
| State file | `local-docs/` (HTML) + auto-memory (`~/.claude/projects/.../memory/`) | Loop-dedicated `STATE.md` template not yet available (M-scope, separate session) |
| Objective gate | `/verify-once` `/lint-test` | OK — must run at every loop iteration, not just on final output |
| Security: skill audit | `hooks/pre-tool-use.sh` (private-name block) | Skill source credential scan not implemented (L-scope, separate session) |

## When NOT to build a loop

Single well-aimed prompt wins for: architecture rewrites / auth / payments (`[[feedback_db_change_review_blind_spot]]`) / production deploys (`[[feedback_rollback_via_revert_pr]]`) / vague product work / any code without automated verification.

Rule of thumb: if a human would need to think deeply about each output before accepting it, don't loop it.

## Atomic vs holistic verification

> **Source**: syu-m-5151 "Loop engineering is rediscovery of cybernetics" (hatenablog, 2026-06-23). Maps loop verification to *Building Evolutionary Architectures* 2nd ed. (Ford et al., 2022) "fitness function" concept and Donella Meadows leverage-point ladder.

Objective gate (§Minimum viable loop, §Failure modes) catches *whether each output passes*. It does not catch *whether properties interact safely across outputs*. Atomic-only verification lets cross-cutting coupling (security × scalability, layer violation, side-effect drift) accumulate silently across loop iterations.

| Verification mode | What it measures | What it misses | When to use |
|---|---|---|---|
| **Atomic** | Single property of one output (test green, lint exit 0, type 0 errors) | Property interactions, layer violations, accumulated coupling | Per-iteration gate (every loop pass) |
| **Holistic** | Cross-cutting fitness across N outputs (perf × security, arch boundary, dependency direction) | Slow signal — not gate-grade per iteration | Periodic sweep (per N iterations / per merge / per session boundary) |

A production loop needs both. Atomic gate per iteration (cheap, blocks bad single outputs); holistic sweep at coarser cadence (catches what atomic gate cannot see, but too slow to run every loop). Run holistic via `/review` (12 dimensions, `skills/comprehensive-review/SKILL.md`) or layer-direction checks (e.g. CQRS guideline read-vs-write boundary).

**Holistic checks ai-tools ships**:

- `skills/comprehensive-review/` — 12-dimension review covering arch / quality / security / test cross-cuts
- `guidelines/design/cqrs.md` — read / write boundary, prevents silent inversion
- `guidelines/design/clean-architecture.md` — dependency direction (outer → inner)
- `references/PARALLEL-PATTERNS.md` — coupling-degree threshold for parallel safety

**When to run holistic sweep inside a loop**:

- After every N iterations (recommend N=5-10 for fast loops, N=1 for irreversible-action loops)
- Before any merge / push / deploy gate
- On `/compact` or session boundary (catches drift hidden by summarization)

Cross-ref: `[[feedback-db-change-review-blind-spot]]` (DB change 4-path holistic check), `[[feedback-no-derived-literals]]` (cross-file consistency = holistic property).

## Related

| File | Role |
|---|---|
| `commands/goal.md` | `/goal` implementation (Ralph Wiggum prevention, objective gate enforcement) |
| `references/boris-style-mapping.md` | Boris Cherny official best-practice 12-tip mapping table |
| `references/compounding-engineering-cycle.md` | Failure → record → auto-avoid cycle (loop analog for config) |
| `references/auto-delegation-detailed.md` | parent=Opus orchestrate / subagent=Sonnet delegation (maker/checker separation basis) |
| `references/PARALLEL-PATTERNS.md` | Parallel N adoption threshold, worktree pattern |
| CLAUDE.md §Quick Reference | ai-tools worktree workflow canonical |
| CLAUDE.md `[[feedback_no_retry_after_interrupt]]` | Interrupt → no auto-retry (loop hard stop reinforcement) |
