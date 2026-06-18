# Agents - Agent List

Description and mapping of agents (autonomous sub-processes) used by Claude Code.

> **CLI command**: `claude agents` displays configured agents (v2.1.47+)

## Agent list

| Agent | Model | Role | Primary use |
|-------|-------|------|-------------|
| **reviewer-agent** | sonnet 4.6 | Review owner | Code quality, security, test review |
| **root-cause-analyzer** | opus 4.7 | RCA specialist | 5Whys analysis, structural fixes |
| **po-agent** | opus 4.7 | Strategy decider | Product strategy, worktree mgmt, decision return |
| **manager-agent** | opus 4.7 | Task decomposition & allocation | Large task allocation, integration verify |
| **developer-agent** | sonnet 4.6 | Implementer | Code impl, fix, add |
| **explore-agent** | sonnet 4.6 | Explorer/analyzer | Codebase investigation, parallel search |
| **verify-app** | sonnet 4.6 | Verifier | Build, test, lint integration check |

> Judgment role (PO / Manager / RCA) は opus 4.7 強制 (`references/model-selection.md` 2026-06-16〜、opus 4.8 regression 回避)。

## Agent startup cost (highlights)

- **Avoid**: `general-purpose` ~115s avg / 501s max

Full table & recalc method: [`references/performance-insights.md`](../references/performance-insights.md) (single source). Operations rule: `claude-code/CLAUDE.md` "exploration/investigation split".

---

## Command → Agent mapping

| Command | Agent launched | Flow |
|---------|----------------|------|
| `/flow` | po-agent (skip light task, else launch) | Parent: PO → Manager → Dev×N sequential (Team default) |
| `/dev` | developer-agent (default) / None (`--inline`) | Default delegation (Sonnet). `--inline` = direct exec |
| `/review` | reviewer-agent | Auto review |
| `/plan` | po-agent + manager-agent | Strategy + task split |
| (natural lang / Claude judgment) | explore-agent (parallel) | Concurrent multi-perspective search. Trigger: 3+ query broad search, ambiguous large investigation |

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

Per-agent Trigger / Role / Feature 詳細は各 `.md` 参照 (重複防止)。

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

> **⚠️ Read before changing design**: Agent Team is parent-handled (ADR 0001) — revert to self-running violates official docs. CI guards via bats test `tests/integration/agent-frontmatter.bats`.

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
| `list_memories` / `read_memory` | Read existing Serena memories | All agents |
| `write_memory` / `edit_memory` / `rename_memory` / `delete_memory` | **Forbidden** (2026-06-10) — write to Claude Code auto-memory (`~/.claude/projects/.../memory/`) via `Write` instead, avoid dual management | — |

### Onboarding

| Tool | Purpose |
|------|---------|
| `initial_instructions` | Get Serena manual (required at task start) |
| `onboarding` | Run project onboarding (state auto-attached to activate response) |
| `serena_info` (v1.2.0) | On-demand usage info (version/context/active project) |

### Usage principles

- **Symbol edit**: Prefer `replace_symbol_body` family over Edit for tighter side-effect scope
- **Rename**: Use `rename_symbol` over grep→Edit for lower ref-miss risk
- **Delete**: Use `safe_delete_symbol` to pre-detect dangling refs
- **Memory write**: Serena memory writes forbidden (2026-06-10) — write to Claude Code auto-memory (`~/.claude/projects/.../memory/`) via `Write`. Serena memory is read-only (`list_memories` / `read_memory`)

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
