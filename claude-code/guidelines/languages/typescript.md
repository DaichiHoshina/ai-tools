# TypeScript Guidelines

TypeScript 6.0.3 (stable as of 2026). Common guidelines: `~/.claude/guidelines/common/`.

---

## Core Principles

- **strict: true required**: enable all strict options
- **Maximize the type system**: catch errors at compile time
- **Latest ECMAScript**: ES2024 support (5.7+)
- **Functional**: immutability, pure functions

---

## Directory Structure

- `domain/` — entities, value objects
- `application/` — use cases
- `infrastructure/` — DB, external APIs
- `presentation/` — controllers, DTOs

---

## Type Definitions (strict)

### Prohibitions
- **no `any`**: use `unknown` + type guard
- **no `as`**: narrow with type guard functions
- **no `!`**: explicit null checks

### Type Usage
- `interface` — object shape
- `type` — union/intersection types
- **Branded Type** — ID type safety
- **const assertion** — `as const`
- **Utility Types** — `Partial<T>`, `Pick<T,K>`, `Omit<T,K>`, `Record<K,V>` etc. (see Quick Reference > Utility Types table)

---

## Naming Conventions

- Variable/Function: camelCase
- Type/Class: PascalCase
- Constant: UPPER_SNAKE_CASE
- Private: # prefix

---

## null/undefined

- `?.` — Optional Chaining
- `??` — Nullish Coalescing
- Type guard: `function isUser(data: unknown): data is User`

---

## Function Design

- Prefer pure functions
- Isolate side effects explicitly
- Early return

---

## Quick Reference

### Type Definitions

| Use | Code | Description |
|-----|------|-------------|
| Type-safe unknown | `unknown` + type guard | alternative to any |
| Union | `type Status = "active" \| "inactive"` | either |
| Intersection | `type A & B` | both types |
| Branded Type | `type UserId = string & { __brand: "UserId" }` | distinguish ID types |
| const assertion | `as const` | literal type |

### Utility Types

| Type | Use |
|------|-----|
| `Partial<T>` | make all properties optional |
| `Required<T>` | make all properties required |
| `Readonly<T>` | make all properties read-only |
| `Pick<T, K>` | extract specific properties |
| `Omit<T, K>` | exclude specific properties |
| `Record<K, V>` | key-value map |
| `NonNullable<T>` | exclude null/undefined |
| `ReturnType<F>` | extract function return type |
| `Parameters<F>` | extract function parameter types (tuple) |
| `Awaited<T>` | extract resolved Promise type |

### Error Handling

| Pattern | Code | Use |
|---------|------|-----|
| Result type | `type Result<T, E> = { ok: true; value: T } \| { ok: false; error: E }` | functional error handling |
| Custom error | `class NotFoundError extends Error` | typed errors |
| try-catch | `try { ... } catch (error) { ... }` | exception handling |

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| `function process(data: any)` | `function process<T>(data: T)` | type safety |
| `const user = data as User` | `if (isUser(data))` | runtime safety |
| `user.name!.toUpperCase()` | `user.name?.toUpperCase()` | null safety |
| `throw new Error()` | `Result<T, E>` type | clear control flow |

---

## Deprecated Pattern Detection (review / implementation)

Check `tsconfig.json` `target` and `package.json` TypeScript version before flagging.

### Critical (always flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `enum Foo { ... }` (numeric enum) | `as const` object or union type | general TS |
| `namespace` | ES Modules (`import`/`export`) | general TS |
| `/// <reference>` | `import` statement | general TS |
| `require()` | `import` (ESM) | ES2015+ |
| `any` type usage | `unknown` + type guard or generics | strict |

### Warning (proactively flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `Promise.then().catch()` chain | `async`/`await` + `try`/`catch` | ES2017 |
| `Object.assign({}, obj)` | spread `{ ...obj }` | ES2018 |
| `arr.indexOf(x) !== -1` | `arr.includes(x)` | ES2016 |
| `Object.keys(obj).forEach(...)` | `Object.entries(obj)` / `for...of` | ES2017 |
| `arr.filter(...)[0]` | `arr.find(...)` | ES2015 |
| `arr.reduce` for array grouping | `Object.groupBy()` / `Map.groupBy()` | ES2024/TS5.7 |
| `lodash.get(obj, 'a.b.c')` | Optional chaining `obj?.a?.b?.c` | TS3.7/ES2020 |
| `x === null \|\| x === undefined` | `x ?? fallback` (Nullish Coalescing) | TS3.7/ES2020 |
| `x != null ? x : fallback` | `x ?? fallback` | TS3.7/ES2020 |
| class component (`extends React.Component`) | function component + Hooks | React 16.8+ |
| `@decorator` (legacy/experimental) | Stage 3 Decorators | TS5.0 |
| Repeated `typeof x === 'string'` | `satisfies` for type assurance | TS4.9 |

### Info (suggestion level)

| Item | Detail | Since |
|------|--------|-------|
| TS 7.0 (Project Corsa) | native compiler for 10x speedup; 6.0 is last JS version | planned 2026 |
| `--erasableSyntaxOnly` | detect runtime-affecting syntax | TS5.8 |

---

## tsconfig.json Required Settings

```json
{
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "target": "es2024"
  }
}
```

---

## Tools

- ESLint + typescript-eslint
- Prettier
- TypeDoc
