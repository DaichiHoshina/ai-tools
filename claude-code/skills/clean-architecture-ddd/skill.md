---
name: clean-architecture-ddd
description: Clean arch & DDD: layer sep, domain model, deps. Use for design decisions.
requires-guidelines:
  - common
  - clean-architecture
  - ddd
---

# clean-architecture-ddd - Clean Architecture & DDD Design

## Layer Structure

```
Dependency: outer → inner only

┌─────────────────────────────────────┐
│  Infrastructure (DB, API, Framework)│ ← outermost
├─────────────────────────────────────┤
│  Interface (Controller, Presenter)  │ ← user IF layer
├─────────────────────────────────────┤
│  Application (UseCase, Service)     │ ← business flow
├─────────────────────────────────────┤
│  Domain (Entity, ValueObject, Repo) │ ← innermost (no deps)
└─────────────────────────────────────┘
```

## DDD Tactical Patterns

| Pattern | Responsibility | Layer |
|---------|------|--------|
| Entity | ID identity, lifecycle, business logic | Domain |
| Value Object | Immutable, value equality, no side-effects | Domain |
| Aggregate | Consistency boundary, root entity | Domain |
| Repository | IF=Domain / Impl=Infra | Domain/Infra |
| UseCase | App-specific logic | Application |
| Domain Event | Past-tense naming, loose coupling | Domain |

---

## Antipatterns (Forbidden)

- **Domain → Infrastructure dependency** (e.g. embed `gorm.Model` in Domain): Couples to DB tech. Define ID/CreatedAt yourself.
- **Anemic domain model**: Entity with getter/setter only. Place business logic in Entity/UseCase.
- **Repository IF in Infra**: IF must always be in Domain layer.

> Implementation examples: see `guidelines/design/clean-architecture.md`.

---

## Checklist

### Layer Design
- [ ] Domain layer has no external deps
- [ ] Dependency direction outer→inner
- [ ] Repository IF in Domain layer

### Domain Modeling
- [ ] Business logic in Domain/UseCase
- [ ] Business rules in Entity
- [ ] Value Objects are immutable
- [ ] Aggregates small (1-3 entities)

### Dependencies
- [ ] No circular deps
- [ ] Controllers thin (input conversion → UseCase → output)
- [ ] No ORM/Framework types leak into Domain

---

## Output Format

Normal case:

```
📋 **Layer Structure**
- Domain: [entity list]
- Application: [UseCase list]
- Infrastructure: [impl list]

🔴 **Critical**: file:line - violation - fix
🟡 **Warning**: file:line - improvement - refactor
```

Zero findings / No layer structure (before CA/DDD):

```
📋 **Layer Structure**
> [WARN] CA/DDD layers not detected (no Domain/Application/Infrastructure dirs)
> Existing code treated as "monolith". Layer split proposal only.

🔴 **Critical**: 0
🟡 **Warning**: 0 (not applicable yet)

### Recommended Actions
- Create Domain/Application/Infrastructure dirs
- Propose responsibility-based placement (separate output)
```

---

## Related Guidelines / Context7

- `guidelines/design/clean-architecture.md`, `design/domain-driven-design.md`
- Context7: "repository pattern", "dependency injection", "aggregate root", "value object immutable"
