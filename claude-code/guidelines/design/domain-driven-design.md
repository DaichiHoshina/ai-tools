# DDD (Domain-Driven Design) Guidelines

> **Purpose**: Software design centered on business logic

## Core Principles

| Principle | Detail |
|-----------|--------|
| **Domain model first** | Express business rules in code |
| **Ubiquitous language** | Use shared team terminology |
| **Bounded context** | Divide domain appropriately |

---

## Strategic Design

### Bounded Context

- Each context has its own domain model
- Contexts interact via clear interfaces
- Example: "Order" and "Shipping" are separate contexts

### Context Map

| Pattern | Relationship | Use Case |
|---------|-------------|---------|
| **Shared Kernel** | Shared kernel | Common foundation code (use cautiously → see "Shared Kernel" section below) |
| **Customer-Supplier** | Upstream/downstream | Order system → Inventory system |
| **Anticorruption Layer** | Anti-corruption | Transformation layer with external systems |

---

## Tactical Design

| Element | Characteristics | Example | Notes |
|---------|-----------------|---------|-------|
| **Entity** | Identified by ID, has lifecycle, encapsulates business logic | `User`, `Order` | Has behavior, not just data structure |
| **Value Object** | Immutable, compared by value, no side effects | `Money`, `Email`, `Address` | Immutable after creation |
| **Aggregate** | Consistency boundary, access via root entity | `Order` (containing OrderItems) | Keep small (1-3 entities) |
| **Repository** | Persistence abstraction for aggregates; IF in Domain layer | `UserRepository` | DB details in Infrastructure layer |
| **Domain Event** | Past tense, immutable, loosely coupled | `UserRegistered`, `OrderPlaced` | Use for inter-context communication |

---

## Implementation Patterns

| Pattern | Purpose | Example |
|---------|---------|---------|
| **Factory** | Complex object creation, invariant guarantee | `UserFactory.create()` |
| **Specification** | Business rules as objects, combinable conditions | `IsAdultSpecification` |

---

## Layer Structure

DDD's Domain layer also holds Domain Event (in addition to Entity, ValueObject, Repository IF). Full layer table (incl. Interface/Infrastructure): `clean-architecture.md`

---

## Naming Conventions

| Element | Format | Example |
|---------|--------|---------|
| **Entity** | Noun | `User`, `Order`, `Product` |
| **Value Object** | Domain term | `Money`, `Email`, `OrderId` |
| **Domain Event** | Past tense | `UserRegistered`, `OrderCompleted` |
| **Repository** | `{Aggregate}Repository` | `UserRepository` |

---

## Test Strategy

Same as clean-architecture.md (Domain: unit test, no mocks / Application: mock Repository, verify flow). Full table (incl. Infrastructure layer): `clean-architecture.md`

---

## Anti-patterns vs Best Practices

| Case | NG | OK |
|------|----|----|
| **Domain model** | getter/setter only (anemic domain) | Encapsulate business logic |
| **Aggregate size** | Many entities in one aggregate | Small aggregates + ID references |
| **Domain Service** | Everything in Domain Service | Place logic in Entity / VO |
| **Cross-entity** | Implement in Domain Service | Coordinate in UseCase layer |
| **Technical details** | Mixed into Domain | Isolate in Infrastructure |
| **Transaction boundary** | Changes spanning aggregates | Complete within aggregate unit |
| **Invariants** | Ignored | Always satisfied |
| **Language** | Technical term-centric | Reflect ubiquitous language in code |
| **Events** | Tight coupling | Loosely couple with domain events |

---

## Shared Kernel

- Place only cross-context shared concepts (**last resort**, not the default)
- Dependency direction: Domain layer of each context → Shared Kernel (reverse is forbidden)
- **Forbidden**: infrastructure concerns (DB conversion etc.), context-specific logic
- Evaluation order before adding: context-local → ACL → Shared Kernel
- Rename/delete/meaning changes to existing types are treated as breaking changes
