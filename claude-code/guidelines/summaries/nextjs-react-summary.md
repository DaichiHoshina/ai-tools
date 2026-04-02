# Next.js/React ガイドライン（サマリー版）

## バージョン: Next.js 16.1 / React 19.2

## コンポーネント設計: 関数コンポーネント、TypeScript Props interface必須、単一責任

## 状態管理

| ツール | 用途 |
|--------|------|
| useState | ローカル（単純） |
| useContext / `use(Ctx)` | グローバル（中規模） |
| useReducer | 複雑な状態ロジック |
| Zustand/Jotai | グローバル（大規模） |

## Next.js App Router

| 機能 | 説明 |
|------|------|
| Server Components | デフォルト（'use client'不要） |
| Server Actions | フォーム処理簡易化 |
| next/image | 画像最適化 |

React 19 + React Compiler: `useMemo`/`useCallback` は自動最適化で不要な場合が多い

## 古いパターン検出

### 必ず指摘

| 古い | モダン | Since |
|------|--------|-------|
| `pages/`（Pages Router） | `app/`（App Router） | Next.js 13 |
| `getServerSideProps` | Server Component で直接fetch | Next.js 13 |
| class component | 関数コンポーネント + Hooks | React 16.8 |
| `next/router` | `next/navigation` | Next.js 13 |

### 積極的に指摘

| 古い | モダン | Since |
|------|--------|-------|
| `useMemo`/`useCallback` 多用 | React Compiler 自動最適化 | React 19 |
| `forwardRef` | `ref` をpropsで直接受取 | React 19 |
| `useFormState` | `useActionState` | React 19 |
| `useContext(Ctx)` | `use(Ctx)` | React 19 |
| CSS-in-JS | Tailwind / CSS Modules | Next.js 13+ |
