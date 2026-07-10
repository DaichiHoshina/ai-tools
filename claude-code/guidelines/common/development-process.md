# Development Process

> **Purpose**: Checklists for before / during / before review of implementation. Reference when starting a new task or before creating a PR.

## Pre-implementation Checklist

| Item | Check |
|------|-------|
| Requirements | Spec doc read completely |
| Task breakdown | Tasks derived from spec and broken down |
| Existing survey | Similar features surveyed |
| Data design | Data structures and API specs confirmed |
| Components | Component breakdown designed |
| Validation | Validation spec documented |
| Coordinates/calculations | Coordinate system and calculation logic detailed (for UI) |
| Impact scope | Impact scope identified and test plan created |
| Information | claude-code has all necessary information |
| **Confirm** | **Confirm task content with user before executing** |

---

## Required Rules During Implementation

| Forbidden | Required |
|-----------|----------|
| Commit without checking diff | Self-review: always check diff before commit |
| Save without running lint | Run lint + prettier on every save |

---

## Notes During Task Execution

| Item | Detail |
|------|--------|
| Quality check | Run quality check after task execution |
| Operation check | Done by user (do not execute yourself) |
| On error | Report error message and cause to user |

---

## Definition of Done

DoD canonical: CLAUDE.md §Definition of Done 参照。
