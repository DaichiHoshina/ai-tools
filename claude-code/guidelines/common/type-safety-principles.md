# Type Safety Principles

Type safety is the most important principle for early bug detection and improved maintainability.

---

## Forbid any / interface{}

| Language | Forbidden | Recommended |
|----------|-----------|-------------|
| TypeScript | `any` | `unknown` + type guard / generics / union types |
| Go | `interface{}` | generics / `str, ok := data.(string)` pattern |

---

## Minimize Type Assertions / as

| Language | Forbidden | Recommended |
|----------|-----------|-------------|
| TypeScript | `data as User` | Narrow safely with type guard functions |
| Go | `data.(string)` | `str, ok := data.(string)` |

---

## Null Safety

| Language | Setting | Usage |
|----------|---------|-------|
| TypeScript | `strictNullChecks` required | Use `?.` / `??` / ❌ Non-null assertion `!` forbidden |
| Go | — | Thorough nil checks on pointers; explicit nil check with early return |

---

## Leverage Type Inference

Avoid redundant type annotations; rely on type inference when return types are obvious.

---

## When any/as Is Unavoidable

| Condition | Detail |
|-----------|--------|
| Allowed conditions | Incomplete type definitions in external libraries / temporary compatibility with existing code |
| **Required rules** | **Comment explaining the reason** / Minimize scope / Add TODO comment with future removal plan |
