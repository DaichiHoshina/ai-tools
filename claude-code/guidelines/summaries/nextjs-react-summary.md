# Next.js/React ガイドライン（サマリー版）

## バージョン情報

| 項目 | バージョン |
|------|-----------|
| **Next.js** | 16.1（2025年12月リリース） |
| **React** | 19.2（2026年1月予定） |

## コンポーネント設計

| 原則 | 説明 |
|------|------|
| 関数コンポーネント | class componentは非推奨 |
| TypeScript | Propsはinterface定義必須 |
| 単一責任 | 1コンポーネント = 1責務 |

## 状態管理

| ツール | 使用ケース |
|--------|------------|
| **useState** | ローカル状態（単純） |
| **useContext** | グローバル状態（中規模） |
| **useReducer** | 複雑な状態ロジック |
| **Zustand/Jotai** | グローバル状態（大規模） |

## パフォーマンス最適化

| 手法 | 使用例 |
|------|--------|
| React.memo | `React.memo(Component)` |
| useMemo | `useMemo(() => compute(data), [data])` |
| useCallback | `useCallback(() => doSomething(), [])` |

**注意**: React 19 + React Compiler では自動最適化により不要な場合が多い

## Next.js App Router（13+）

| 機能 | 説明 |
|------|------|
| **Server Components** | デフォルト（'use client'不要） |
| **Server Actions** | フォーム処理簡易化 |
| **Dynamic Import** | コード分割 |
| **next/image** | 画像最適化 |

## dynamic import 注意点（Next.js 15+）

| ケース | 推奨 |
|--------|------|
| Server Component | ❌ `ssr: false`（エラー） |
| Client Component | ✅ 通常のimport（`dynamic`不要） |
| 条件付きロード | ✅ `dynamic(() => import())` |

## ベストプラクティス

| 項目 | 基準 |
|------|------|
| Props数 | 5個以下が理想 |
| useEffect依存配列 | 正確に指定 |
| key prop | リスト項目に必須 |
| エラーバウンダリ | 適切に配置 |

## Hooks ルール

| ルール | 説明 |
|--------|------|
| トップレベル | 条件分岐・ループ内で呼び出し禁止 |
| 関数コンポーネント内 | カスタムHooksまたはコンポーネント内のみ |
| 命名規則 | `use`で始める |

## 古いパターン検出（レビュー/実装時）

### 必ず指摘

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `pages/` (Pages Router) | `app/` (App Router) | Next.js 13 |
| `getServerSideProps` / `getStaticProps` | Server Component で直接fetch | Next.js 13 |
| class component | 関数コンポーネント + Hooks | React 16.8 |
| `next/router` | `next/navigation` | Next.js 13 |

### 積極的に指摘

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `useMemo`/`useCallback` 多用 | React Compiler 自動最適化 | React 19 |
| `forwardRef` | `ref` をpropsで直接受取 | React 19 |
| `useFormState` | `useActionState` | React 19 |
| `useContext(Ctx)` | `use(Ctx)` | React 19 |
| CSS-in-JS | Tailwind / CSS Modules | Next.js 13+ |
