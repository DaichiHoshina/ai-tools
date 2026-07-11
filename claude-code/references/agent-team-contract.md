# Agent Team Contract

Canonical interface definitions for the `/flow` Team path (PO → Manager → Developer×N → Reviewer). Each agent file references this contract; no independent definitions allowed.

## Common Terms

- **parent**: Claude Code host (session model、`references/model-selection.md` canonical). Only parent spawns subagents
- **field names**: snake_case throughout
- **path**: absolute path required (`~` not allowed, `$HOME` must be expanded)

## Interface Schema

### 1. PO → parent (decision)

PO returns a decision to parent. Return as **structured fields**, not Markdown.

```yaml
execution_mode: team  # /flow always team; direct is legacy schema only (unused)
task_type: impl  # enum: impl | refactor | fix | test | docs | investigation
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

### 1.1. parent → PO (Manager allocation oversight callback)

Sent **once per `/flow` run**, after Manager allocation but before fan-out. Parent re-spawns PO with the initial `manager_instruction` + Manager output for strategy alignment check (single-shot, no loop).

```yaml
oversight_trigger: manager_allocation
manager_instruction:  # echo from initial §1 PO output (verbatim)
  goal: "<1 line>"
  constraints: ["..."]
  priority: ["..."]
allocation:  # Manager §3 output, full YAML
  execution_mode: parallel
  tasks: [...]
  formula_trace: {...}
```

PO returns:

```yaml
verdict: pass  # pass | fail | modify
reason: "<1 line; required for fail/modify>"
fix_request:  # required for modify, omit for pass/fail
  modify_target_task_ids: ["<task.id>", ...]   # tasks Manager MUST modify; required, non-empty
  unchanged_task_ids: ["<task.id>", ...]       # tasks Manager MUST literal-preserve (developer_id / files / scope unchanged); required, may be empty list
  modify_reason: "<1 line>"                    # why fix is needed; required
  concrete_change: "<concrete change to allocation, 1-3 lines>"  # required
```

`pass` → parent proceeds to fan-out (step 7). `fail` → parent stops `/flow`, escalates to user with `reason`. `modify` → parent calls Manager back with `fix_request` (re-allocation, 1 loop max; same budget as Reviewer P0 path). On `modify`, Manager MUST touch only `modify_target_task_ids[]` and literal-preserve `unchanged_task_ids[]` (no `developer_id` shuffle, no scope shrink, no file path rename). Missing `modify_target_task_ids` → parent re-requests PO output (fail-fast).

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

### 3.1. parent → Manager (Dev failure reallocation input)

Sent when ≥1 Dev returns `status ∈ {failure, partial, dep_unresolved}`. Parent injects this on Manager re-spawn (skips PO, reuses `worktree` + `reviewer_qa_criteria` from initial PO output).

```yaml
reallocation_trigger: dev_failure  # dev_failure | reviewer_p0
loop_iteration: 1  # 1 = first re-fix; 2 → forbidden (parent must escalate to user instead)
failed_devs:
  - dev_id: dev2
    task_id: task-002
    status: failure  # failure | partial | dep_unresolved
    unresolved_errors:
      - location: "<file:line>"
        error: "<message>"
        why_unresolved: "<1 line>"
    blocker: "<root cause, 1 line; required for partial/failure>"
    impl_notes_path: <absolute path or null>
success_devs: [dev1, dev3]  # do not re-touch their files
```

Manager output schema unchanged from §3; `tasks[]` contains only re-fix tasks with `task.id` suffixed `-fix1`.

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
status: success  # success | partial | failure | dep_unresolved | blocked
task_id: task-001
changed_files:
  - path: <path>
    change: "<add | modify | delete>"
verification:
  lint: ✓
  typecheck: ✓
  test: ✓
self_review:                              # required (agents/developer-agent.md §Self-Review Gate canonical)
  diagnostics_clean: ✓                    # get_diagnostics_for_file 全 edited file で error 0
  diagnostics_lines: 0                    # LSP 出力 line 数 literal
  scope_match: ✓                          # changed_files[] ⊆ touchable_files literal
  verify_cmd: "<literal cmd or 'N/A (none provided)'>"
  report_schema: ✓                        # §5 schema 準拠 (no custom keys, no prose after YAML)
unresolved_errors: []  # required; [] when none, else list `{location, error, why_unresolved}` literal
impl_notes_path: <absolute path>  # Team flow only, omit otherwise
```

`unresolved_errors` is **required and non-omittable** (empty list `[]` allowed only when truly zero). Suppressing or silently dropping errors here is a contract violation — parent will discard report.

`self_review` is **required and non-omittable**. Missing block → parent treats report as `failure` and re-runs. Any ✗ inside → cannot return `status: success` (downgrade to `partial`).

On `status: partial` (timeout / blocker): add `remaining` + `blocker` + `progress_pct` fields (see §5.1).
On `status: failure`: add `manager_decision_required` (trailing spec).

### 5.1 Partial / failure detail fields

```yaml
status: partial
remaining:
  - "<work item not yet done, 1 line each>"
blocker: "<single root cause that prevented completion, 1 line>"
progress_pct: 60  # 0-100 integer estimate
```

`partial` is **not a free pass**: agent must have actively attempted retry within budget and report the specific blocker. `partial` without a concrete `blocker` line is rejected by parent as `failure`.

`blocked` = user 判断が必要な decision fork で停止 (subagent silent-fail guard 発火)。parent は Manager 再割当 loop に入れず、`issues_blocking` の内容を即 user に escalate する (`dep_unresolved` は agent/環境依存、`blocked` は user 判断待ちで区別する)。

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
