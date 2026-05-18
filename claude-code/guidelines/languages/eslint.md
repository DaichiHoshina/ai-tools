# ESLintガイドライン

ESLint v9+ Flat Config対応（2025年）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **Flat Config標準**: v9からflat configがデフォルト
- **型安全**: `defineConfig()`で型安全な設定
- **プラグイン統合**: typescript-eslint、prettier等
- **自動修正**: `--fix`で多くの問題を自動解決

---

## v9.0主要変更（2025年）

### Flat Configがデフォルト
- 旧`.eslintrc*`は非推奨
- `eslint.config.js`（またはmjs/cjs）を使用
- よりシンプルで柔軟な設定

### defineConfig()ヘルパー
型安全な設定記述:
```js
import { defineConfig } from 'eslint'

export default defineConfig([
  // 設定オブジェクトの配列
])
```

### extends機能復活
ユーザーからの要望で復活:
```js
import { defineConfig } from 'eslint'
import recommended from '@eslint/js/recommended'

export default defineConfig({
  extends: [recommended]
})
```

### globalIgnores()ヘルパー
グローバル除外設定を明確化:
```js
import { globalIgnores } from '@eslint/config-helpers'

export default [
  globalIgnores(['dist/**', 'build/**'])
]
```

---

## Flat Config基本構造

### ファイル名
- `eslint.config.js` (CommonJS)
- `eslint.config.mjs` (ES Module)
- `eslint.config.cjs` (CommonJS明示)

### 基本形式
```js
export default [
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'module'
    },
    rules: {
      'no-console': 'warn',
      'prefer-const': 'error'
    }
  }
]
```

---

## TypeScript統合

### typescript-eslint v8+
```js
import tseslint from 'typescript-eslint'

export default tseslint.config(
  ...tseslint.configs.recommended,
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
      '@typescript-eslint/no-unused-vars': 'error'
    }
  }
)
```

---

## Next.js統合

### next/core-web-vitals
```js
import { defineConfig } from 'eslint'
import next from '@next/eslint-plugin-next'

export default defineConfig([
  {
    plugins: {
      '@next/next': next
    },
    rules: {
      '@next/next/no-html-link-for-pages': 'error'
    }
  }
])
```

---

## 推奨ルール

### TypeScript
- `@typescript-eslint/no-explicit-any: error` - any禁止
- `@typescript-eslint/no-unused-vars: error` - 未使用変数禁止
- `@typescript-eslint/strict-boolean-expressions: warn` - 厳格なboolean式

### React
- `react/prop-types: off` - TypeScript使用時は不要
- `react-hooks/rules-of-hooks: error` - Hooksルール厳守
- `react-hooks/exhaustive-deps: warn` - 依存配列チェック

### Import
- `import/order: warn` - インポート順序
- `import/no-duplicates: error` - 重複インポート禁止

---

## Prettier統合

### eslint-config-prettier
競合するルールを無効化:
```js
import prettier from 'eslint-config-prettier'

export default [
  // ...他の設定
  prettier
]
```

---

## マイグレーション

旧設定からの移行: `npx @eslint/migrate-config .eslintrc.json`

---

## 古いパターン検出（レビュー/実装時チェック）

`package.json` の `eslint` バージョンとプロジェクトの設定ファイル形式を確認してから指摘する。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `.eslintrc` / `.eslintrc.json` / `.eslintrc.js` | `eslint.config.js` (Flat Config) | v9 |
| `extends: [...]` (旧形式) | `defineConfig()` + `extends` (新形式) | v9 |
| `env: { browser: true, node: true }` | `languageOptions.globals` | v9 |
| `parserOptions` トップレベル | `languageOptions.parserOptions` | v9 |
| `plugins: ['@typescript-eslint']` (文字列) | `plugins: { '@typescript-eslint': tseslint }` (オブジェクト) | v9 |
| `.eslintignore` ファイル | `ignores` プロパティor `globalIgnores()` | v9 |
| `overrides: [...]` | `files` パターンで複数設定オブジェクト | v9 |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `tslint` / `tslint.json` | ESLint + typescript-eslint | 2019年非推奨 |
| `prettier` をESLintルールで実行 | `eslint-config-prettier` で競合無効化 + 別途prettier実行 | 推奨 |
| `eslint-plugin-react` の `prop-types` ルール | TypeScriptのProps型で代替 | TS使用時 |
| `@typescript-eslint/` v7以前の設定 | v8+ の `tseslint.config()` 形式 | v8 |

### ℹ️ Info（提案レベル）

| 項目 | 内容 | Since |
|------|------|-------|
| v10.0 | Flat Config改善、パフォーマンス向上 | ベータ |
| `defineConfig()` | 型安全な設定記述 | v9 |

---

## 実行

```bash
npx eslint .          # チェック
npx eslint . --fix    # 自動修正
```
