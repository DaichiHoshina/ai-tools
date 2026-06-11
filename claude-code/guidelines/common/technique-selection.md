# Technique Auto-Selection

> **Purpose**: Automatically select the optimal technique based on task characteristics

---

## Task Classification (4 Dimensions)

| Dimension | Values |
|-----------|--------|
| Purpose | CRUD / Logic / Concurrency / Security / Performance |
| Complexity | 1-10 |
| Difficulty | 1-10 |
| Volume | Small / Medium / Large |

---

## Technique Selection Matrix

| Technique | Condition | Effect | Token Cost |
|-----------|-----------|--------|------------|
| **Result/Either type** | Always required | Type-safe error handling | +500 |
| **CQS** | Always required | Explicit side effects | +200 |
| **Pure functions** | Logic OR difficulty ≥ 4 | Testability, referential transparency | +400 |
| **Immutability** | Concurrency OR complexity ≥ 5 OR volume != Small | Eliminate race conditions | +300 |
| **Property-based testing** | difficulty ≥ 5 OR complexity ≥ 6 OR Logic | Auto-discover edge cases | +800 |
| **State machine** | Logic OR (complexity ≥ 6 AND CRUD) | Type-safe state transitions | +700 |
| **Design by contract** | difficulty ≥ 6 OR Security OR complexity ≥ 7 | Explicit pre/post conditions | +600 |
| **DDD tactical patterns** | complexity ≥ 7 OR volume == Large OR (Logic AND difficulty ≥ 6) | Organize domain logic | +1.5K |
| **Category theory** | complexity ≥ 7 OR (Logic AND difficulty ≥ 6) | Abstraction and composability | +2K |
| **Formal methods** | Concurrency OR (Security AND difficulty ≥ 8) OR complexity ≥ 9 | Verify correctness of concurrency | +1K |

### Property-based Testing Libraries
- TypeScript: fast-check / Python: hypothesis / Go: gopter

### Formal Methods Tools
- TLA+: distributed systems / Alloy: data model verification

---

## Auto-selection Logic

**Step 1**: Result/Either type and CQS are always required

**Steps 2-5 criteria**:

| Axis | Threshold | Additional Techniques |
|------|-----------|----------------------|
| complexity | ≥9 / ≥7 / ≥6 / ≥5 | Formal methods / Category theory+DDD / PBT+state machine / Immutability |
| difficulty | ≥8 / ≥6 / ≥5 / ≥4 | Formal methods / Category theory+contract / PBT / Pure functions |
| purpose | Concurrency / Security / Logic | Formal methods+Immutability / Contract / PBT+pure functions+state machine+DDD |
| volume | Large | DDD tactical patterns |

**Step 6**: Remove duplicates; when token budget (10K) exceeded, reduce by effect/cost ratio

---

## Selection Examples

| Scenario | purpose/complexity/difficulty/volume | Selected Techniques | Cost |
|----------|--------------------------------------|---------------------|------|
| Simple CRUD API | CRUD/3/2/Small | Result/Either + CQS | 700 |
| Payment processing system | Logic,Security/8/7/Medium | Above + Category theory+DDD+PBT+state machine+contract+immutability+pure functions | 6.6K |
| Distributed transaction | Concurrency,Logic/10/9/Large | All techniques | 8.5K |

---

## Progressive Disclosure Integration

| Level | Content |
|-------|---------|
| 1 | Auto-analyze task characteristics; generate applicable technique list |
| 2 | Load overview of selected techniques only |
| 3 | Load details only when needed during implementation |

---

**Analyze task characteristics and auto-select optimal techniques. Produce mathematically correct, efficient code.**
