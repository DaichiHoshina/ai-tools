# Next.js / Reactガイドライン

Next.js 16.2 + React 19.2対応（2026年5月）。共通: `~/.claude/guidelines/common/`。

16.2新機能: React Compiler安定化（自動メモ化）、Turbopack Server Fast Refresh、Web Worker Origin for WASM、Subresource Integrity。

## 基本原則

- **Server Components First**: デフォルトServer Component
- **Client Component**: `'use client'` は最小限（インタラクション必要時のみ）
- **Concurrent Rendering**: React 19でデフォルト有効
- **React Compiler**: 自動最適化により `useMemo`/`useCallback` 不要なケース多
- **型安全**: Props・イベントハンドラも明示的型付け

## ディレクトリ構成

`app/`（App Router、API Routes）/ `features/`（domain/application/presentation）/ `shared/`（共通）。

## クイックリファレンス

### コンポーネント種別

| 種別 | 用途 | 特徴 |
|------|------|------|
| Server Component | データフェッチ、静的表示 | async/await可、デフォルト |
| Client Component | インタラクション、状態 | `'use client'` 必須 |
| Server Action | ミューテーション | `'use server'` |

### よく使うHooks

| Hook | 用途 | 制約 |
|------|------|------|
| `useState` | ローカル状態 | Clientのみ |
| `useEffect` | 副作用 | Clientのみ |
| `use()` | ストリーミングデータ | Server/Client両方 |
| `useActionState` | Server Action状態 | React 19+ |
| `useOptimistic` | 楽観的UI | React 19+ |

### データフェッチ

| 方法 | 用途 | キャッシュ |
|------|------|----------|
| `fetch()` | Server Component | デフォルト有効 |
| TanStack Query | Client Component | 自動管理 |
| Server Actions | ミューテーション | `revalidatePath()` |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| Server Componentで `ssr: false` | 通常の `import` | Next.js 15+ でエラー |
| Client Componentで `dynamic(..., {ssr: false})` | 通常の `import` | 冗長 |
| `process.env.NEXT_PUBLIC_*` 関数内直接参照 | 設定ファイル経由 | ビルド時静的置換 |
| Contextでグローバル状態 | Zustand/Jotai | パフォーマンス |
| `useEffect` でデータフェッチ | Server Component or TanStack Query | サーバー側で完結 |

## 古いパターン検出

`package.json` の `next`/`react` バージョン確認してから指摘。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `pages/`（Pages Router） | `app/`（App Router） | Next 13 |
| `getServerSideProps`/`getStaticProps` | Server Componentで直接 `fetch`/DB | Next 13 |
| `getInitialProps` | Server Component or Server Actions | Next 13 |
| class component | 関数コンポーネント + Hooks | React 16.8 |
| `next/router` | `next/navigation`（`useRouter`/`usePathname`） | Next 13 |
| `next.config.js` | `next.config.ts` | Next 15 |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `useMemo`/`useCallback` 多用 | React Compiler自動最適化 | React 19 |
| `useFormState` | `useActionState` | React 19 |
| `forwardRef` | `ref` をpropsで直接受取 | React 19 |
| `<Context.Provider>` | `<Context>` で直接提供 | React 19 |
| `useContext(Ctx)` | `use(Ctx)` | React 19 |
| Promiseを `useEffect` で解決 | `use(promise)` でrender内読込 | React 19 |
| `next/head` | `export const metadata`（App Router） | Next 13 |
| `middleware.ts` でプロキシ処理 | `proxy.ts`（ネットワーク境界明確化） | Next 16 |
| 手動キャッシュ制御 | `"use cache"` ディレクティブ | Next 16 |
| CSS-in-JS（styled-components等） | Tailwind / CSS Modules | Next 13+（RSC非対応） |

### ℹ️ Info

| 項目 | 内容 | Since |
|------|------|-------|
| Activity Component | `<Activity mode="hidden">` で表示/非表示制御 | React 19.2 |
| useEffectEvent | 非リアクティブロジックをeffectから分離 | React 19.2 |
| View Transitions | ナビゲーション時アニメーション | Next 16 |

## コンポーネント設計

### Server Components（デフォルト）

- async/await直接使用
- DB・APIコールはサーバー側実行
- `use()` Hookでストリーミングデータ

### Client Components（必要時のみ）

`'use client'` が必要なケース:
- state / イベント（`onClick`, `onChange`）
- ライフサイクル（`useEffect`）
- ブラウザAPI（`localStorage`, `window`）

戦略: 小さなClient Islands、葉のコンポーネントのみClient化。

### dynamic import

- 原則: `'use client'` ファイルで `dynamic` + `ssr: false` 不要（既にクライアント実行）
- Next.js 15+: Server Componentで `ssr: false` はエラー
- 推奨: 通常 `import`（Client内）/ `dynamic()` でコード分割（ssr: falseなし）

## 状態管理

| 種別 | 推奨 |
|------|------|
| Server State | TanStack Query（キャッシュ、再検証、楽観更新） |
| ローカルUI | `useState` |
| 複雑ローカル | `useReducer` |
| グローバル | Zustand/Jotai（必要最小限） |
| 静的値（DI・テーマ） | Context |

## データフェッチ（Next.js 15-16）

### キャッシュ設定

- `export const dynamic = 'force-dynamic'` — SSR強制
- `export const revalidate = 60` — ISR（60秒）
- `fetch(..., { next: { revalidate: 3600 } })` — 個別

### Server Actions

`'use server'` でミューテーション。`revalidatePath()` / `revalidateTag()` で再検証。

### エラーハンドリング

`error.tsx`（エラー境界）/ `loading.tsx`（Suspenseローディング）/ `not-found.tsx`（404）。

## 環境変数

関数スコープ内で `process.env.NEXT_PUBLIC_*` 直接参照禁止（Next.jsビルド時静的置換のため埋め込めない可能性）。

推奨: `src/config/*.ts` で一元管理。

```ts
export const appConfig = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL ?? ""
} as const
```

## フォーム（React 19）

新Hooks: `useActionState`（フォーム処理+状態）/ `useFormStatus`（送信状態）/ `useOptimistic`（楽観的更新）。

推奨ライブラリ: React Hook Form + zod / Conform（Server Actions連携）。

## セキュリティ

CVE-2025-55182（React2Shell）対応済み（19.0.3/19.1.4/19.2.3）。

## パフォーマンス

- Next.js: `next/image`（画像最適化）/ `revalidateTag()`（キャッシュ戦略）/ `export const runtime = 'edge'`（グローバル高速化）/ Turbopack（5-10xビルド高速化）
- React 19: `useTransition`（スムーズUX）/ Concurrent Rendering（UIフリーズ防止）

## Hooksルール

トップレベルのみ（条件・ループ内禁止）/ React関数内のみ / 依存配列を正確に（ESLint警告従う）。

## 型定義

### Props

```ts
type Props = {
  title: string
  children: React.ReactNode
  onClick?: () => void
}
```

### イベントハンドラ

`React.MouseEvent<HTMLButtonElement>` / `React.FormEvent<HTMLFormElement>` / `React.ChangeEvent<HTMLInputElement>`。

### Ref

```ts
useRef<HTMLDivElement>(null)
```
