---
name: groove
description: Lightweight multi-agent orchestrator. Execute agents in coordination per YAML workflow. No external deps.
---

# /groove - Multi-agent orchestrator

> When to use vs `/flow` (imperative detection): `references/flow-vs-groove.md`

## Usage

```text
/groove <task>                    # auto-select workflow
/groove <workflow> <task>         # specify workflow
/groove --auto <task>             # auto mode (commit+push post-COMPLETE)
/groove list                      # list workflows
```

## Workflow auto-selection

| Keyword | Workflow |
|---------|----------|
| VSDD, vsdd, quality-first, spec-driven test | `vsdd` |
| test, TDD, test | `tdd` |
| else | `spec-driven` |

## Path resolution (project priority → home fallback)

| Type | 1st | 2nd |
|------|-----|-----|
| Workflow | `.groove/workflows/` | `~/.groove/workflows/` |
| Agent definition | `.groove/agents/` | `~/.groove/agents/` |

## Execution procedure

Main Agent directly runs loop. No external CLI. Schema spec: see `~/.groove/schema.md`.

### 1. Initialize

Read YAML, start from first step.

- Check `version` field (unspecified = v0, warn only)
- Extract `defaults`. Apply to unspecified step fields (step value priority)
- Manage state w/ internal vars (step_count, loop_count, retry_count)

### 2. Step execution loop

```text
WHILE current_step != COMPLETE && current_step != ABORT:
  1. step_count >= max_steps → ABORT
  2. loop_count[step] >= loop_limit → ABORT
  3. Read Agent definition
  4. Launch Agent (rules below, w/ defaults-applied values)
  5. Extract GROOVE_RESULT from output
     - On Agent fail/timeout → goto retry handling
  6. Determine next step via rules matching
  7. step_count++, loop_count[step]++
```

### 2a. retry / error handling

```text
ON agent_error OR timeout:
  IF retry_count[step] < step.retry:
    retry_count[step]++
    → re-execute same step
  ELSE:
    GROOVE_RESULT = error, evaluate rules
    → transition to next matching rules.on:error
    → if no matching rule, ABORT
```

v0 compat behavior detail: see `~/.groove/schema.md#migration-rules-v0--v1`.

### 3. Agent launch rules

**Normal (sequential step):**

```text
Extract model from Agent definition frontmatter.
Agent(
  subagent_type: "general-purpose",
  model: frontmatter.model (haiku/sonnet/opus), omit if absent,
  mode: edit→"bypassPermissions" / readonly→"default",
  prompt: "{Agent definition body (sans frontmatter)}\n\n## Task\n{task}\n\n## Prior step result\n{prev_result}"
)
```

Sequential step: don't use isolation (need to reference prior step changes).

**`general-purpose` use policy**:
- Conclusion: groove permits `general-purpose` exceptionally (prefer `/flow` if `/flow` completes it)
- Reason: YAML dynamically composes arbitrary agent defs, specialist agents (po/manager/developer/reviewer/explore) can't handle

**parallel:**

Launch multiple Agents parallel in single message. edit-mode substeps auto-get `isolation: "worktree"`. Aggregate adopts first match from `aggregate.priority`:

```yaml
aggregate:
  priority: [spec_issue, any_fail, all_pass]
```

- `spec_issue`: any output is spec_issue
- `any_fail`: any fail
- `all_pass`: all pass

Default priority when `aggregate` undefined: `[spec_issue, any_fail, all_pass]`.

If changes remain in worktree, merge/cherry-pick to parent. No changes: auto-cleanup.

**provider: codex:**

Run `codex` command w/ Bash tool. If uninstalled: error (follow rules.on:error).

**ask_user: true:**

On needs_input, AskUserQuestion to ask, append answer & re-execute.

### 4. Parse result

Search for `GROOVE_RESULT: {value}`. If not found:

- edit → `done`
- readonly → `pass`
- agent error/timeout → `error`

### 5. Complete

- COMPLETE → display execution history. On `--auto`, run `/git-push --pr` → PushNotification
- ABORT → display failure reason → PushNotification

## References

- Schema spec & field definitions: `~/.groove/schema.md`
- Available workflow list: `~/.groove/README.md` (or `/groove list`)
