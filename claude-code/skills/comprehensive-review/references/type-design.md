# Type Design Perspective

Express state & constraints via types, prevent invalid ops at compile time. Detect primitive (string/boolean/number) abuse.

## Checklist

| Check | Bad example | Level |
|-------|-------------|-------|
| **string for state** | `status: string` ("pending"/"done") | Warning |
| **boolean flag abuse** | `isActive`/`isDeleted`/`isArchived` in parallel (state explosion) | Warning |
| **null/undefined overuse** | Missing Optional/Maybe, `T \| null \| undefined` | Warning |
| **Invariant not typed** | "positive number" as `number`, no Branded type | Warning |
| **Large union** | String literal union with 10+ elements (use discriminated union) | Warning |
| **Result/Either missing** | Errors thrown as exceptions (not in type signature) | Warning |
| **Primitive over-trust** | UserId/OrderId as `string` (swappable) | Critical (finance/PII) |
| **Shared mutable objects** | API response type missing readonly/Immutable | Warning |

## Design patterns

- **enum / discriminated union**: Explicit state set
- **branded type / newtype**: Type-level domain separation (UserId ≠ OrderId)
- **Result<T, E> / Either<E, T>**: Type-level error expression
- **readonly / Immutable**: Prevent unintended mutations
