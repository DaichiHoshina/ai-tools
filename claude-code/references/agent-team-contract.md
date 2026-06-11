# Agent Team Contract

Canonical interface definitions for the `/flow` Team path (PO → Manager → Developer×N → Reviewer). Each agent file references this contract; no independent definitions allowed.

## Common Terms

- **parent**: Claude Code host (Opus). Only parent spawns subagents
- **field names**: snake_case throughout
- **path**: absolute path required (`~` not allowed, `$HOME` must be expanded)

## Interface Schema

### 1. PO → parent (decision)

PO returns a decision to parent. Return as **structured fields**, not Markdown.

```yaml
execution_mode: team  # /flow always team; direct is legacy schema only (unused)
decision_reason: "<1 line>"
worktree:
  path: <absolute path>
  branch: <branch name>
  base_branch: <main | etc>
reviewer_qa_criteria:
  p0: [type-safety, security, data-integrity]
  p1: [performance, test-coverage]
  refix_loop_limit: 1
manager_instruction:
  goal: "<1 line>"
  constraints: ["<constraint 1>", "<constraint 2>"]
  priority: ["<top task>", "<next>"]
```

### 2. parent → Manager (input)

parent embeds `manager_instruction` + `worktree` + `reviewer_qa_criteria` from PO decision directly into Manager prompt.

### 3. Manager → parent (allocation)

Manager returns allocation to parent. **Structured fields, not Markdown.**

```yaml
execution_mode: parallel  # parallel | staged | sequential
parallelism: 4
worktree_required: true
impl_notes:
  dir: <absolute path>  # ~/.claude/plans/impl-notes/YYYY-MM-DD_HHMMSS_<feature-slug>/
tasks:
  - developer_id: dev1
    task:
      id: task-001
      title: "<1 line>"
      description: "<3 lines max>"
      files: ["<path>"]
      dependencies: []
    verify:  # parent must embed in subagent prompt
      lint: "<lint cmd>"
      typecheck: "<typecheck cmd>"
      test: "<test cmd>"
    dod: "<1-line success criteria>"  # required
  - developer_id: dev2
    ...
stages:  # staged execution only
  - stage: 1
    devs: [dev1, dev2]
  - stage: 2
    devs: [dev3]
```

### 4. parent → Developer (context)

parent embeds 1 task from Manager allocation into Developer prompt, firing **N tool_use in 1 message** in parallel.

```json
{
  "developer_id": "dev1",
  "worktree": {
    "path": "<absolute path>",
    "branch": "<branch name>",
    "base_branch": "main"
  },
  "task": {
    "id": "task-001",
    "title": "<1 line>",
    "description": "<3 lines max>",
    "files": ["<path>"],
    "dependencies": []
  },
  "verify": {
    "lint": "<cmd>",
    "typecheck": "<cmd>",
    "test": "<cmd>"
  },
  "dod": "<1 line>",
  "constraints": {
    "timeout_minutes": 30,
    "max_retries": 2
  },
  "impl_notes": {
    "dir": "<absolute path>"
  }
}
```

### 5. Developer → parent (completion report)

Max 300 words. Checkboxes: `✓` (done) / `✗` (failed) / `—` (N/A). `[ ]` prohibited.

```yaml
status: success  # success | partial | failure | dep_unresolved
task_id: task-001
changed_files:
  - path: <path>
    change: "<add | modify | delete>"
verification:
  lint: ✓
  typecheck: ✓
  test: ✓
impl_notes_path: <absolute path>  # Team flow only, omit otherwise
```

On failure: add `remaining` + `manager_decision_required` fields.

### 6. parent → Reviewer (input)

```yaml
diff_target: <git diff command or file paths>
change_summary: "<Manager integration result summary, 1 paragraph>"
po_qa_criteria:
  p0: [...]
  p1: [...]
merged_md_path: <absolute path>  # Team flow only
review_mode: default  # default | codex | adversarial | deep
is_reverify: false  # boolean
```

### 7. Reviewer → parent (review result)

P0/P1/P2/P3 aggregation; format follows `agents/reviewer-agent.md` Output template (this contract defines schema only).

```yaml
p0:
  - viewpoint: type-safety
    location: <file:line>
    issue: "<1 line>"
    fix: "<suggestion>"
p1: [...]
p2: [...]
codex_available: true  # false → include fallback WARN line
```

## Field Name Canonicalization

| Old | Canonical |
|-----|-----------|
| `Reviewer QA criteria` / `Reviewer criteria` | `reviewer_qa_criteria` |
| `Worktree info` / `Worktree path` / `worktree.path` | `worktree.path` (JSON/YAML structure) |
| `IMPL_NOTES dir` / `impl_notes.dir` | `impl_notes.dir` |
| `re-verify flag` / `re-verify or first-time flag` | `is_reverify` (boolean) |

## Markdown Output Relationship

Each agent file's Markdown output template (PO Return format / Manager Allocation plan / Dev Completion report / Reviewer Output template) is **human-readable form**. Contract YAML/JSON is **machine-readable schema**. Both are equivalent; parent holds YAML as internal state and converts to Markdown when needed.

## Revision Procedure

1. Edit this file (`agent-team-contract.md`) first
2. Align each agent file's relevant section to match the contract
3. Smoke test with `/flow` (PO → Manager → Dev×1, 1 task)
