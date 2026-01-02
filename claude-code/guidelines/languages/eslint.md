# ESLint ガイドライン

ESLint v9+ Flat Config対応（2025年）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **Flat Config標準**: v9からflat configがデフォルト
- **型安全**: `defineConfig()`で型安全な設定
- **プラグイン統合**: typescript-eslint、prettier等
- **自動修正**: `--fix`で多くの問題を自動解決

---

## v9.0 主要変更（2025年）

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

### 旧設定からの移行
公式ツール使用:
```bash
npx @eslint/migrate-config .eslintrc.json
```

自動的に`eslint.config.js`生成

---

## ベストプラクティス

### ファイル別設定
```js
export default [
  {
    files: ['**/*.ts', '**/*.tsx'],
    // TypeScript設定
  },
  {
    files: ['**/*.test.ts'],
    // テストファイル設定
  }
]
```

### 除外設定
```js
export default [
  {
    ignores: ['dist/**', 'node_modules/**', '.next/**']
  }
]
```

### 段階的導入
```js
export default [
  {
    rules: {
      // エラーから始める
      'no-console': 'error',
      // 徐々にwarningをerrorに
      '@typescript-eslint/no-explicit-any': 'warn'
    }
  }
]
```

---

## v10.0（ベータ）

2025年後半にv10.0ベータリリース予定:
- Flat Config更なる改善
- パフォーマンス向上
- 新ルール追加

---

## 実行

### コマンド
```bash
# チェック
npx eslint .

# 自動修正
npx eslint . --fix

# 特定ファイル
npx eslint src/**/*.ts
```

### package.json
```json
{
  "scripts": {
    "lint": "eslint .",
    "lint:fix": "eslint . --fix"
  }
}
```

---

## エディタ統合

### VS Code
`.vscode/settings.json`:
```json
{
  "eslint.enable": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  }
}
```
