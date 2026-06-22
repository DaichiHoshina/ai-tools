# Code Quality and Design Philosophy

> **Purpose**: Quality criteria and review perspectives for consistency, readability, and testability. Reference during code reviews and design decisions.

## Quick Reference

### Quality Standards

| Item | Rule |
|------|------|
| Consistency | Follow existing code style and design patterns |
| Readability | No self-indulgent coding |
| Magic numbers | Always extract as named constants |
| Naming | Care about function and variable names |

### Comment Principles

| Rule | Description |
|------|-------------|
| Language | Japanese (no formal tone needed) |
| No obvious comments | Skip comments for self-evident code |
| Explain intent/reason | Document the "why" and "purpose" of complex logic |

### Design Philosophy

| Principle | Description |
|-----------|-------------|
| Layered architecture | Flexible design prioritizing ease of change |
| Readable code | Split hard-to-read code; avoid long functions |
| Dependencies | Keep loosely coupled; do not use components from other pages |
| API responses are raw data | Return raw data without UI-specific aggregations; enables reuse across multiple UIs and reduces server-side spec changes |
| Single point of change | Design so spec changes require changes in only one place; extract and consolidate any duplication |

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| `const name = "太郎"; // 名前を設定` | `const name = "太郎";` | Obvious comment unnecessary |
| `const MAX = 100;` | `const MAX_RETRY_COUNT = 100;` | Name expresses intent |
| 200-line function | Split into 10-50-line functions | Improves readability and testability |
| Importing components from other pages | Commonalize or copy | Maintains loose coupling |

**Good comment example**:
```ts
// conform-to/reactの自動バリデーションを無効化しているため手動で実装
```

**Why**: Explains intent and reason
