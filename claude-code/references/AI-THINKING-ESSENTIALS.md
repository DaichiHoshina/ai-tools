# AI Thinking Essentials

Core thinking patterns for Claude agents.

## 3 Core Concepts

### 1. Operation Guard (3-tier classification)

Canonical: `guidelines/common/guardrails.md` (Safe/Boundary/Forbidden → Allow/AskUser/Deny)。tier 定義表はそちらを参照し、本 file では再掲しない (Safety Theorems と flow 図は本 file 固有の運用手順として残す)。本 file の "Confirm" は guardrails の Boundary tier を指す。

Confirm flow: detect → afplay (notification) → wait approval → execute or cancel.

### 2. Complexity Check

`ComplexityCheck : UserRequest → {Simple, TaskDecomposition, AgentHierarchy}`

| Condition | Result | Action |
|------|------|----------|
| files<5 AND lines<300 | Simple | Direct impl |
| files≥5 OR independent features≥3 OR lines≥300 | TaskDecomposition | Tasks + 5 phases |
| Cross-project OR strategic judgment | AgentHierarchy | PO/Manager/Developer hierarchy |

Tasks: TaskCreate/TaskUpdate/TaskList/TaskGet. Order via `addBlockedBy`/`addBlocks`. Share across sessions via `CLAUDE_CODE_TASK_LIST_ID`. Details: `commands/flow.md`.

### 3. 5-Phase Workflow (enforced)

Required process for TaskDecomposition.

| Phase | Purpose | Invariant |
|-------|------|---------|
| 0. Requirement analysis | Prevent omissions | Required items have description + acceptance criteria |
| 1. Task decomposition | Coverage guarantee | Coverage = 100% |
| 2. File creation | Traceability | Complete |
| 3. Dependency ordering | Parallel execution plan | No circular dependencies |
| 4. Agent launch | Parallel execution | All tasks succeed |
| 5. Integration verify | Completeness | Unimplemented requirements = ∅ |

Execution guard: InvariantCheck at each phase completion. Violation → forced stop + auto-fix or question.

## 5 Operating Principles

1. **Complexity check**: Receive task → Simple/TaskDecomposition/AgentHierarchy → select appropriate file
2. **Completion monad**: `complete(task) = (afplay notify, write_auto_memory(result))` (Claude Code auto-memory; Serena `write_memory` forbidden — 2026-06-10)
3. **Confirm notify**: `confirm(boundary) = (afplay confirm sound, wait_user_approval())`
4. **Code of conduct**: clean → careful → cooperative
5. **Response format**: quote user input → state execution mode → commutative diagram (current → next step)

## Guardrails

### Denied Operations (absolute)

- System destruction: `rm -rf /`, `shutdown -h now`, `mkfs.*`
- Security: `chmod 777 -R /`, committing/pushing secrets or .env, arbitrary code eval from user input
- Git danger: `git push --force` / `git reset --hard` remote / `git clean -fdx` (without permission)
- YAGNI: generating unused code, implementing "just in case" or "might use later"

### Confirm Flow

1. explain_impact
2. afplay confirm sound
3. wait_user_approval()
4. approved → execute / else cancel
5. log(action, result)

## Safety Theorems

- **Theorem 1**: Safe operations are always safe — `∀f ∈ Mor(safe ops), ¬causes_harm(f)`
- **Theorem 2**: Confirm operations are safe with user approval — `user_approval(f) ⟹ ¬causes_harm(f)`
- **Theorem 3**: Denied operations cannot be executed — `f ∉ Mor(Claude) ⟹ ¬executable(f)`
- **Completeness**: invariant check at each phase ∧ forced stop on violation ⟹ zero omissions ∧ quality assured

```
Task received → complexity check
  ├─ Simple → direct impl (operation guard applied)
  ├─ TaskDecomposition → 5-phase workflow
  └─ AgentHierarchy → PO/Manager/Developer hierarchy

Before each operation → operation guard
  ├─ Safe → execute
  ├─ Confirm → sound + approval + execute
  └─ Deny → refuse + explain reason

On complete → complete(task) → notify + memory save
```
