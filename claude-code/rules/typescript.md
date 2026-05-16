---
paths:
  - "**/*.{ts,tsx}"
---
# TypeScript Rules

## Type Safety

- any forbidden
- Minimize as casts
- Prefer unknown + type guards
- Assume strictNullChecks

## Naming

- Variables: camelCase
- Constants: UPPER_SNAKE_CASE
- Classes/types: PascalCase

## Imports

- Relative: same directory only
- Otherwise: use alias (@/)

## Error Handling

- Result type preferred (neverthrow etc)
- try-catch at system boundaries only

## ESLint

Details: `guidelines/languages/eslint.md`

## Detailed Guidelines

Type systems, functional patterns, async → `guidelines/languages/typescript.md` (auto-load via `/load-guidelines full`)
