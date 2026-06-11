# ADR 0001: Build Agent Team with Parent-Handled Architecture

- **Status**: Accepted
- **Date**: 2026-04-22
- **Decision maker**: DaichiHoshina
- **Related commit**: `f3cb78a refactor(agents): revert self-orchestrating hierarchy to parent-handled`
- **Reverted target**: `42146e6 feat(agents): change team hierarchy to self-orchestrating`

## Context

When running the ai-tools Agent Team (PO → Manager → Developer × N → Manager(integration)) in Claude Code, commit `42146e6` changed to a "self-orchestrating" model where each layer spawns the next via `Task(next-agent)`. The intent was to prevent parent handling omissions and optimize parallel launch.

On 2026-04-22, during live behavior verification, we observed a violation where PO launched Write/Edit directly to complete implementation without spawning Manager. We discovered the following spec in the official documentation (https://code.claude.com/docs/en/sub-agents.md):

> **Subagents cannot spawn other subagents**, so `Agent(agent_type)` has no effect in subagent definitions.

Meaning: even if `Task(manager-agent)` is written in po-agent's `tools`, it has no effect — PO falls back to inherited default Write/Edit for direct implementation. Self-orchestrating architecture is fundamentally impossible with Claude Code's sub-agent mechanism.

## Decision

**Adopt parent-handled architecture where parent (Claude Code main thread) explicitly launches each layer — PO → Manager → Developer × N → Manager(integration) — sequentially.**

Additional defenses:

- Explicitly add `disallowedTools: [Write, Edit, MultiEdit]` to frontmatter of non-implementation agents (`po-agent`, `manager-agent`, `explore-agent`) to physically block implementation violations from tool inheritance
- Remove all `Task(xxx)` notation from agent `tools` (non-functional per spec)
- Document `/flow` command procedure as "parent launches each layer sequentially"
- Mechanically verify invariants in bats test `tests/integration/agent-frontmatter.bats`

## Consequences

### Benefits

- **Spec-compliant**: Aligns with the intended use of Claude Code's sub-agent mechanism
- **Physical violation blocking**: `disallowedTools` rejects Write/Edit if PO/Manager attempts implementation
- **Regression prevention**: bats tests guard invariants. Future change believing "self-orchestrating is more efficient" will be caught by CI
- **Parallelism preserved**: parent can call multiple `Task(developer-agent)` in 1 message for parallel launch

### Drawbacks / accepted tradeoffs

- **Increased parent responsibility**: Claude Code must track the entire flow and call each layer sequentially → mitigated by documenting in `commands/flow.md`
- **More messages**: parent → PO → parent → Manager → parent → Dev × N → parent → Manager = 5 round trips. Self-orchestrating was supposed to be 1 call → impossible per spec, so accepted

## Alternatives Considered

### 1. Self-orchestrating (sub-agent spawns sub-agent)

- **Not selected**: `Agent(agent_type)` has no effect in subagent definition per Claude Code spec. Verified PO commits Write/Edit violations in implementation testing

### 2. `claude --agent` main thread mode

- **Not selected**: main thread agent can spawn, but cost of aligning with `/flow` slash command UX is high. Operations complexity increase

### 3. Full migration to agent-teams feature

- **Not selected**: scale requiring parallel + mutual communication is not needed. High learning cost and rewrite scope

## References

- [Claude Code Sub-agents docs](https://code.claude.com/docs/en/sub-agents.md) - `tools` allowlist, `disallowedTools` denylist, sub-agent spawn impossible spec
- `claude-code/agents/README.md` - parent-handled hierarchy diagram
- `claude-code/commands/flow.md` - procedure where parent calls Task per step
- `claude-code/tests/integration/agent-frontmatter.bats` - mechanical invariant verification
