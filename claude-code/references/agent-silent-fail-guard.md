# Agent Silent-Fail Guard (Developer subagent)

Source: claudefa.st "delegated edit silently fails" / CLAUDE.md `Auto-Delegation` section

## Hard constraints in subagent context

| Constraint | Behavior | Required action |
|-----------|---------|----------------|
| `AskUserQuestion` | Auto-denied; call silently does nothing | Never call — escalate as `status: blocked` |
| Permission-prompt ops | Auto-denied, no error signal | Stop; list in `issues_blocking[]` |
| "Success report without actual edit" | Silent win; file unchanged | Verify actual edit before reporting |

## Rules

- **Fail-fast on decision fork**: action requires user approval or judgment outside task spec → stop, set `status: blocked`, list in `issues_blocking[]`; do not guess or skip
- **Parent-approval-required ops → escalate**: destructive Bash / write outside `touchable_files` → report as `blocked`; do not attempt the op
- **Silent error suppression forbidden**: reporting verify `✗` as `success` / omitting `unresolved_errors[]` / swallowing in catch — always write `unresolved_errors: []` even when empty
