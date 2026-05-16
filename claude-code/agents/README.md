# Agents - Agent List

Description and mapping of agents (autonomous sub-processes) used by Claude Code.

> **CLI command**: `claude agents` displays configured agents (v2.1.47+)

## Agent list

| Agent | Model | Role | Primary use |
|-------|-------|------|-------------|
| **reviewer-agent** | opus | Review owner | Code quality, security, test review |
| **root-cause-analyzer** | opus | RCA specialist | 5Whys analysis, structural fixes |
| **po-agent** | sonnet | Strategy decider | Product strategy, worktree mgmt, decision return |
| **manager-agent** | sonnet | Task decomposition & allocation | Large task allocation, integration verify |
| **developer-agent** | haiku | Implementer | Code impl, fix, add |
| **explore-agent** | haiku | Explorer/analyzer | Codebase investigation, parallel search |
| **verify-app** | haiku | Verifier | Build, test, lint integration check |

## Agent startup cost (subagent-events.log actual measurement)

| Agent | N | Avg time | Max | Note |
|-------|---|----------|-----|------|
| developer-agent | 2* | 17s | 23s | Fastest, clear task |
| manager-agent | 2* | 42s | 68s | Planning only, lightweight |
| reviewer-agent | 27 | 82s | 161s | Opus + comprehensive-review |
| po-agent | 9* | 96s | 365s | Strategy decision expands |
| Explore (built-in) | 79 | 99s | 310s | Most frequent |
| general-purpose | 21 | **115s** | **501s** | **Avoid** |
| explore-agent | 7* | 123s | 289s | Haiku but broad task scope, long |

`*` = reference values for N<10 (small sample, variance with larger N). Operations prioritize high-frequency agents (N≥20) trends.

**Recalculate**: Process `~/.claude/hooks/subagent-events.log` via script in `references/performance-insights.md` (last update: `git log -1 --format=%cs agents/README.md`).

Operations rule (table): `claude-code/CLAUDE.md` "exploration/investigation split". Measurement method & hook vs agent cost structure: [`references/performance-insights.md`](../references/performance-insights.md).

---

## Command → Agent mapping

| Command | Agent launched | Flow |
|---------|----------------|------|
| `/flow` | po-agent (skip light task, else launch) | Parent: PO → Manager → Dev×N sequential (Team default) |
| `/dev` | None (direct) | No agent. Need Team? Use `/flow` |
| `/review` | reviewer-agent | Auto review |
| `/plan` | po-agent + manager-agent | Strategy + task split |
| `/explore` | explore-agent (parallel) | Concurrent multi-perspective search |

---

## Auto-launched agents

When user runs command, agents launch internally:

### `/flow` workflow (parent-handling)

Claude Code sub-agent spec: sub-agents cannot spawn other sub-agents. **Parent (Claude Code) launches each layer sequentially**.

```
1. Parent → Task(po-agent)
   ↓ PO: judge exec mode, QA criteria → return decision
   ↓
2. Parent → Task(manager-agent) (if Team)
   ↓ Manager: return allocation plan
   ↓
3. Parent → Task(developer-agent)×N in 1 message (parallel)
   ↓ All Devs complete
   ↓
4. Parent → Task(manager-agent) relaunch (integrate)
   ↓ Manager: return integration result
   ↓
5. Parent → Task(reviewer-agent, --codex) (comprehensive-review + codex parallel, prioritize common findings)
   ↓ Reviewer: return P0/P1 classified
   ↓ P0 exists → Parent → Task(manager-agent) reallocate → Task(developer-agent)×M → Task(reviewer-agent, --codex) re-verify (max 1 loop)
   ↓ P0 = 0
   ↓
6. Parent → /lint-test → /git-push --pr
```

**Direct recommended**: PO returns decision to parent, parent launches `/dev` (skip Step 2-4).

---

## Agent characteristics

### 1. developer-agent (dev1-4)

- **Trigger**: `/flow` (Team use, via Manager)
- **Role**: Implement, fix, create tests
- **Feature**: Serena MCP required (symbol ops)

### 2. reviewer-agent

- **Trigger**: `/review`, final step of `/flow`
- **Role**: Review in Writer/Reviewer parallel pattern
- **Feature**: Auto-launch after impl complete

### 3. explore-agent (explore1-4)

- **Trigger**: `/explore`, investigation tasks
- **Role**: Read-only parallel search
- **Feature**: Serena MCP required, multi-perspective

### 4. manager-agent

- **Trigger**: Parent launches when PO decides Team use
- **Role**: Task split, allocation creation, integration verify (no impl; parent starts Devs)
- **Feature**: Return allocation format; parent spawns `Task(developer-agent)` parallel

### 5. po-agent

- **Trigger**: `/flow` (skip light task, else launch), `/plan`
- **Role**: Judge exec mode, decide strategy, manage worktree, create Manager instruction (no impl)
- **Feature**: Return decision (mode, worktree, Manager instruction). Parent launches next layer

### 6. verify-app

- **Trigger**: Explicit request only (no auto). Standard checks use `/lint-test`
- **Role**: Comprehensive build/test/lint (when `/lint-test` insufficient for structural change)
- **Feature**: On fail, return to Developer (no auto-fix)

---

## Agent hierarchy

Large tasks execute in hierarchy. **Parent (Claude Code) launches each layer sequentially** — parent-handling (per sub-agent spec).

```
Parent (Claude Code)
  ├─ Task(po-agent)              # Strategy & Team decision → return
  ├─ Task(manager-agent)         # Allocation plan → return
  ├─ Task(developer-agent) dev1  ┐ 1 message
  ├─ Task(developer-agent) dev2  │ parallel
  ├─ Task(developer-agent) dev3  ┘
  ├─ Task(manager-agent)         # Integration verify (relaunch)
  ├─ /lint-test                  # Post-impl checks (verify-app explicit only)
  └─ Task(reviewer-agent)        # Final review
```

**Design principles**:
- Sub-agents cannot spawn other sub-agents (Claude Code spec)
- PO/Manager/Explore explicitly have `disallowedTools: Write, Edit, MultiEdit` to physically prevent implementation violations
- Parent launches multiple `Task`s in 1 message for parallelism
- Parallel patterns, worktree apply decision, responsibility separation: `references/PARALLEL-PATTERNS.md`

> **⚠️ Read before changing design**: [ADR 0001: Agent Team is parent-handled](../../docs/adr/0001-parent-handled-agent-hierarchy.md) — revert to self-running violates official docs. CI guards via bats test `tests/integration/agent-frontmatter.bats`.

---

## Serena MCP tool catalog

**Recommended usage patterns** available with `mcp__serena__*` wildcard in agent `tools:`. reviewer-agent only lists explicitly (`find_symbol`, `get_symbols_overview`) to narrow permissions. Final control: agent frontmatter `tools` / `disallowedTools`.

**v1.3.0 new tools**: `find_declaration`, `find_implementations`, `get_diagnostics_for_file`, `get_diagnostics_for_symbol` (Serena CHANGELOG v1.3.0 LSP Backend section. [oraios/serena GitHub CHANGELOG](https://github.com/oraios/serena/blob/main/CHANGELOG.md))

### Symbol search (read-only)

| Tool | Purpose | Recommended agent |
|------|---------|-------------------|
| `find_symbol` | Search by name/path/type | reviewer, explore, developer |
| `get_symbols_overview` | File symbol overview | reviewer, explore |
| `find_referencing_symbols` | Trace reverse refs | explore, developer |
| `find_declaration` (v1.3.0) | Locate declaration | explore, developer |
| `find_implementations` (v1.3.0) | Locate impl (interface→impl) | explore, developer |

### Symbol edit (write)

| Tool | Purpose | Recommended agent |
|------|---------|-------------------|
| `replace_symbol_body` | Replace function/class body | developer |
| `insert_before_symbol` / `insert_after_symbol` | Insert adjacent | developer |
| `rename_symbol` | Rename + bulk update refs | developer |
| `safe_delete_symbol` | Delete with ref check | developer |
| `replace_content` | Text replace (non-symbol) | developer |

### Diagnostics

| Tool | Purpose | Recommended agent |
|------|---------|-------------------|
| `get_diagnostics_for_file` (v1.3.0) | Get LSP diagnostics (type errors, warnings) | developer, verify-app |
| `get_diagnostics_for_symbol` (v1.3.0) | Specific symbol diagnostics | developer |

### Memory ops

| Tool | Purpose | Recommended agent |
|------|---------|-------------------|
| `list_memories` / `read_memory` | Read existing | All agents |
| `write_memory` | Write new | po, manager, developer |
| `edit_memory` | Partial update (diff not full replace) | po, manager |
| `rename_memory` | Rename key | po, manager |
| `delete_memory` | Delete | po, manager |

### Onboarding

| Tool | Purpose |
|------|---------|
| `initial_instructions` | Get Serena manual (required at task start) |
| `check_onboarding_performed` / `onboarding` | Check project init |
| `serena_info` (v1.2.0) | On-demand usage info (version/context/active project) |

### Usage principles

- **Symbol edit**: Prefer `replace_symbol_body` family over Edit for tighter side-effect scope
- **Rename**: Use `rename_symbol` over grep→Edit for lower ref-miss risk
- **Delete**: Use `safe_delete_symbol` to pre-detect dangling refs
- **Memory update**: Use `edit_memory` over `write_memory` to keep diffs visible

---

## Details

Per-agent details: see corresponding `.md` files

- [developer-agent.md](./developer-agent.md)
- [reviewer-agent.md](./reviewer-agent.md)
- [root-cause-analyzer.md](./root-cause-analyzer.md)
- [explore-agent.md](./explore-agent.md)
- [manager-agent.md](./manager-agent.md)
- [po-agent.md](./po-agent.md)
- [verify-app.md](./verify-app.md)
