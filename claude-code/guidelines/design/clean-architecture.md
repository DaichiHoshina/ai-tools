# Clean Architecture Guidelines

> **Purpose**: Framework-independent, testable software design

## Core Principles

| Principle | Detail |
|-----------|--------|
| **Direction of dependency** | Outer → inner (inner knows nothing about outer) |
| **Separation of concerns** | Separate responsibilities per layer |
| **Framework independence** | Business logic is independent of technical details |

---

## Layer Structure

| Layer | Responsibility | Contains | Depends On |
|-------|----------------|----------|------------|
| **Domain** | Business rules | Entity, ValueObject, Repository IF | None |
| **Application / UseCase** | Application logic | UseCase, ApplicationService, DTO | Domain only |
| **Interface / Presentation** | I/O handling | Controller, Presenter | Application, Domain |
| **Infrastructure** | Technical details | Repository impl, API Client, ORM | All layers |

---

## Dependency Inversion Principle (DIP)

| Element | Role | Example |
|---------|------|---------|
| **Interface** | Defined in upper layer | `UserRepository` (Domain) |
| **Implementation** | Implemented in lower layer | `PostgresUserRepository` (Infrastructure) |
| **Injection** | Connected via DI | Inject implementation at startup |

---

## Directory Structure

| Pattern | Example Structure | Characteristics |
|---------|-------------------|-----------------|
| **Feature-based (recommended)** | `features/user/{domain,application,infrastructure}/` | Feature-unit separation, scalable |
| **Layer-based** | `{domain,application,infrastructure}/` | Layer-unit separation, simple |

---

## Data Flow

```
Controller (request→DTO) → UseCase (business logic) → Repository (persistence) → Presenter (response)
```

**Data crossing boundaries**: passed via DTO; Domain entities must not leak externally

---

## Test Strategy

| Layer | Test Type | Mock | Characteristics |
|-------|-----------|------|-----------------|
| **Domain** | Unit test | Not needed | Verify business logic |
| **Application** | Unit test | Mock Repository | Verify flow |
| **Infrastructure** | Integration test | Use real DB | Verify technical details |

---

## Anti-patterns vs Best Practices

| Case | NG | OK |
|------|----|----|
| **Framework coupling** | Framework-specific code in Domain | Use framework in Infrastructure |
| **Penetrating architecture** | Controller → DB direct access | Access via UseCase |
| **Over-abstraction** | Interfaces everywhere | Abstract only necessary boundaries |
| **Business logic placement** | Complex logic in Controller | Consolidate in Domain / UseCase |
| **Technical details** | Framework-specific processing in UseCase | Isolate in Infrastructure |
| **Testability** | No DI | Ensure testability with DI |
| **Layer boundary** | Ambiguous boundaries | Define clear boundaries |
