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

Large tasks: PO → Manager → Developer×N → Reviewer (details: `/flow workflow` section above).

---

## Serena MCP tool catalog

Canonical: `references/serena-tool-map.md` (per-agent recommended Serena tools).

## Parallel execution

Canonical: `references/PARALLEL-PATTERNS.md` (formula / N_initial / worktree-applicability-flow).

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
