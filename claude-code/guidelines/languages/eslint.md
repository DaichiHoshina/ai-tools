# ESLint Guidelines

ESLint v10+ Flat Config (2026). Common guidelines: `~/.claude/guidelines/common/`.

---

## Core Principles

- **Flat Config standard**: default since v9
- **Type safety**: type-safe config via `defineConfig()`
- **Plugin integration**: typescript-eslint, prettier, etc.
- **Auto-fix**: `--fix` resolves most issues automatically

---

## v9.0 Changes (2025) → v10.0 GA (2026-02)

| Change | Old | New |
|--------|-----|-----|
| Config format | `.eslintrc*` | `eslint.config.js` (Flat Config) |
| Type-safe config | — | `defineConfig()` helper |
| extends | removed → | restored by user request (new format) |
| Global ignores | `.eslintignore` | `globalIgnores()` / `ignores` property |

**Flat Config example (type-safe + extends + globalIgnores)**:
```js
import { defineConfig, globalIgnores } from 'eslint'
import recommended from '@eslint/js/recommended'

export default defineConfig([
  globalIgnores(['dist/**']),
  { extends: [recommended] }
])
```

---

## Flat Config Structure

Filename: `eslint.config.js` / `.mjs` / `.cjs`

```js
export default [
  {
    files: ['**/*.js'],
    languageOptions: { ecmaVersion: 2024, sourceType: 'module' },
    rules: { 'no-console': 'warn', 'prefer-const': 'error' }
  }
]
```

## TypeScript Integration

```js
import tseslint from 'typescript-eslint'
export default tseslint.config(...tseslint.configs.recommended, {
  rules: { '@typescript-eslint/no-explicit-any': 'error' }
})
```

## Next.js Integration

```js
import { defineConfig } from 'eslint'
import next from '@next/eslint-plugin-next'
export default defineConfig([{
  plugins: { '@next/next': next },
  rules: { '@next/next/no-html-link-for-pages': 'error' }
}])
```

---

## Recommended Rules

### TypeScript
- `@typescript-eslint/no-explicit-any: error` — ban any
- `@typescript-eslint/no-unused-vars: error` — ban unused vars
- `@typescript-eslint/strict-boolean-expressions: warn` — strict boolean expressions

### React
- `react/prop-types: off` — not needed with TypeScript
- `react-hooks/rules-of-hooks: error` — enforce Hooks rules
- `react-hooks/exhaustive-deps: warn` — check dependency arrays

### Import
- `import/order: warn` — import ordering
- `import/no-duplicates: error` — ban duplicate imports

---

## Prettier Integration

Disable conflicting rules with `eslint-config-prettier`:
```js
import prettier from 'eslint-config-prettier'

export default [
  // ...other config
  prettier
]
```

---

## Migration

Migrate from legacy config: `npx @eslint/migrate-config .eslintrc.json`

---

## Deprecated Pattern Detection (review / implementation)

Check `package.json` `eslint` version and project config format before flagging.

### Critical (always flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `.eslintrc` / `.eslintrc.json` / `.eslintrc.js` | `eslint.config.js` (Flat Config) | v9 |
| `extends: [...]` (old format) | `defineConfig()` + `extends` (new format) | v9 |
| `env: { browser: true, node: true }` | `languageOptions.globals` | v9 |
| `parserOptions` top-level | `languageOptions.parserOptions` | v9 |
| `plugins: ['@typescript-eslint']` (string) | `plugins: { '@typescript-eslint': tseslint }` (object) | v9 |
| `.eslintignore` file | `ignores` property or `globalIgnores()` | v9 |
| `overrides: [...]` | multiple config objects with `files` patterns | v9 |

### Warning (proactively flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `tslint` / `tslint.json` | ESLint + typescript-eslint | deprecated 2019 |
| Run prettier as ESLint rule | `eslint-config-prettier` to disable conflicts + run prettier separately | recommended |
| `eslint-plugin-react` `prop-types` rule | TypeScript Props types | when using TS |
| `@typescript-eslint/` pre-v7 config | v8+ `tseslint.config()` format | v8 |

### Info (suggestion level)

| Item | Detail | Since |
|------|--------|-------|
| v10.0 | Flat Config improvements, performance gains | GA (2026-02) |
| `defineConfig()` | type-safe config authoring | v9 |

---

## Usage

```bash
npx eslint .          # check
npx eslint . --fix    # auto-fix
```
