# Agents - Agent List

Description and mapping of agents (autonomous sub-processes) used by Claude Code.

> **CLI command**: `claude agents` displays configured agents (v2.1.47+)

## Agent list

| Agent | Model | Role | Primary use |
|-------|-------|------|-------------|
| **reviewer-agent** | sonnet 5 | Review owner | Code quality, security, test review |
| **root-cause-analyzer** | sonnet 5 | RCA specialist | 5Whys analysis, fix-strategy proposal |
| **po-agent** | fable 5 | Strategy decider | Product strategy, worktree mgmt, decision return |
| **manager-agent** | sonnet 5 | Task decomposition & allocation | Large task allocation, integration verify |
| **developer-agent** | sonnet 5 | Implementer | Code impl, fix, add |
| **explore-agent** | sonnet 5 | Explorer/analyzer | Codebase investigation, parallel search |
| **verify-app** | sonnet 5 | Verifier | Build, test, lint integration check |
| **design-review-agent** | sonnet 5 | UI/UX reviewer | Live design review via Playwright |

> Model canonical は各 agent frontmatter の `model:`。この表は frontmatter 導出 — 更新時は `grep -H "^model:" agents/*.md` で一致を検証する。決定 log: `references/model-selection.md` (2026-07-11: po = Fable 5 / 他は Sonnet 5、Opus 4.7 pin 解除)。

## External agents (agents/ に定義なし)

- **claude-code-guide**: plugin 由来。Claude Code CLI / SDK / API の仕様質問に使う (CLAUDE.global.md Discovery Routing 参照)
- **silent-failure-hunter** 等: `pr-review-toolkit` plugin 由来 (6 agents)。`/review --deep` / `/goal --checker` で使う (`references/review-modes-advanced.md` 参照)。plugin 未導入環境では unknown subagent_type になる

## Agent 定義編集の検証

既存 session の Agent tool は session 開始時の定義 snapshot を使い続ける (編集は反映されない)。agent file 編集後の動作確認は新 session または headless (`claude -p`) で行う。

## Agent startup cost (highlights)

- **Avoid**: `general-purpose` ~115s avg / 501s max

Full table & recalc method: [`references/performance-insights.md`](../references/performance-insights.md) (single source). Operations rule: `claude-code/CLAUDE.global.md` "## Discovery / Investigation Routing (anti-overuse)".

---

## Command → Agent mapping

| Command | Agent launched | Flow |
|---------|----------------|------|
| `/flow` | po-agent (required; cannot skip) | Parent: PO → Manager → Dev×N sequential (Team default) |
| `/dev` | developer-agent (default) / None (`--inline`) | Default delegation. `--inline` = direct exec |
| `/review` | reviewer-agent | Auto review |
| `/plan` | po-agent | Strategy only (Manager は `/flow` 側) |
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

全 agent 共通 default: All responses in English (preserve technical terms, tool names)。

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
- [design-review-agent.md](./design-review-agent.md)
