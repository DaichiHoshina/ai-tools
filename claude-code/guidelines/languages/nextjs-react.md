# Next.js / React ガイドライン

Next.js 16.2 + React 19.2 対応（2026年4月）。共通: `~/.claude/guidelines/common/`。

16.2 新機能: React Compiler 安定化（自動メモ化）、Turbopack Server Fast Refresh、Web Worker Origin for WASM、Subresource Integrity。

## 基本原則

- **Server Components First**: デフォルト Server Component
- **Client Component**: `'use client'` は最小限（インタラクション必要時のみ）
- **Concurrent Rendering**: React 19 でデフォルト有効
- **React Compiler**: 自動最適化により `useMemo`/`useCallback` 不要なケース多
- **型安全**: Props・イベントハンドラも明示的型付け

## ディレクトリ構成

`app/`（App Router、API Routes）/ `features/`（domain/application/presentation）/ `shared/`（共通）。

## クイックリファレンス

### コンポーネント種別

| 種別 | 用途 | 特徴 |
|------|------|------|
| Server Component | データフェッチ、静的表示 | async/await 可、デフォルト |
| Client Component | インタラクション、状態 | `'use client'` 必須 |
| Server Action | ミューテーション | `'use server'` |

### よく使う Hooks

| Hook | 用途 | 制約 |
|------|------|------|
| `useState` | ローカル状態 | Client のみ |
| `useEffect` | 副作用 | Client のみ |
| `use()` | ストリーミングデータ | Server/Client 両方 |
| `useActionState` | Server Action 状態 | React 19+ |
| `useOptimistic` | 楽観的 UI | React 19+ |

### データフェッチ

| 方法 | 用途 | キャッシュ |
|------|------|----------|
| `fetch()` | Server Component | デフォルト有効 |
| TanStack Query | Client Component | 自動管理 |
| Server Actions | ミューテーション | `revalidatePath()` |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| Server Component で `ssr: false` | 通常の `import` | Next.js 15+ でエラー |
| Client Component で `dynamic(..., {ssr: false})` | 通常の `import` | 冗長 |
| `process.env.NEXT_PUBLIC_*` 関数内直接参照 | 設定ファイル経由 | ビルド時静的置換 |
| Context でグローバル状態 | Zustand/Jotai | パフォーマンス |
| `useEffect` でデータフェッチ | Server Component or TanStack Query | サーバー側で完結 |

## 古いパターン検出

`package.json` の `next`/`react` バージョン確認してから指摘。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `pages/`（Pages Router） | `app/`（App Router） | Next 13 |
| `getServerSideProps`/`getStaticProps` | Server Component で直接 `fetch`/DB | Next 13 |
| `getInitialProps` | Server Component or Server Actions | Next 13 |
| class component | 関数コンポーネント + Hooks | React 16.8 |
| `next/router` | `next/navigation`（`useRouter`/`usePathname`） | Next 13 |
| `next.config.js` | `next.config.ts` | Next 15 |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `useMemo`/`useCallback` 多用 | React Compiler 自動最適化 | React 19 |
| `useFormState` | `useActionState` | React 19 |
| `forwardRef` | `ref` を props で直接受取 | React 19 |
| `<Context.Provider>` | `<Context>` で直接提供 | React 19 |
| `useContext(Ctx)` | `use(Ctx)` | React 19 |
| Promise を `useEffect` で解決 | `use(promise)` で render 内読込 | React 19 |
| `next/head` | `export const metadata`（App Router） | Next 13 |
| `middleware.ts` でプロキシ処理 | `proxy.ts`（ネットワーク境界明確化） | Next 16 |
| 手動キャッシュ制御 | `"use cache"` ディレクティブ | Next 16 |
| CSS-in-JS（styled-components 等） | Tailwind / CSS Modules | Next 13+（RSC 非対応） |

### ℹ️ Info

| 項目 | 内容 | Since |
|------|------|-------|
| Activity Component | `<Activity mode="hidden">` で表示/非表示制御 | React 19.2 |
| useEffectEvent | 非リアクティブロジックを effect から分離 | React 19.2 |
| View Transitions | ナビゲーション時アニメーション | Next 16 |

## コンポーネント設計

### Server Components（デフォルト）

- async/await 直接使用
- DB・API コールはサーバー側実行
- `use()` Hook でストリーミングデータ

### Client Components（必要時のみ）

`'use client'` が必要なケース:
- state / イベント（`onClick`, `onChange`）
- ライフサイクル（`useEffect`）
- ブラウザ API（`localStorage`, `window`）

戦略: 小さな Client Islands、葉のコンポーネントのみ Client 化。

### dynamic import

- 原則: `'use client'` ファイルで `dynamic` + `ssr: false` 不要（既にクライアント実行）
- Next.js 15+: Server Component で `ssr: false` はエラー
- 推奨: 通常 `import`（Client 内）/ `dynamic()` でコード分割（ssr: false なし）

## 状態管理

| 種別 | 推奨 |
|------|------|
| Server State | TanStack Query（キャッシュ、再検証、楽観更新） |
| ローカル UI | `useState` |
| 複雑ローカル | `useReducer` |
| グローバル | Zustand/Jotai（必要最小限） |
| 静的値（DI・テーマ） | Context |

## データフェッチ（Next.js 15-16）

### キャッシュ設定

- `export const dynamic = 'force-dynamic'` — SSR 強制
- `export const revalidate = 60` — ISR（60秒）
- `fetch(..., { next: { revalidate: 3600 } })` — 個別

### Server Actions

`'use server'` でミューテーション。`revalidatePath()` / `revalidateTag()` で再検証。

### エラーハンドリング

`error.tsx`（エラー境界）/ `loading.tsx`（Suspense ローディング）/ `not-found.tsx`（404）。

## 環境変数

関数スコープ内で `process.env.NEXT_PUBLIC_*` 直接参照禁止（Next.js ビルド時静的置換のため埋め込めない可能性）。

推奨: `src/config/*.ts` で一元管理。

```ts
export const appConfig = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL ?? ""
} as const
```

## フォーム（React 19）

新 Hooks: `useActionState`（フォーム処理+状態）/ `useFormStatus`（送信状態）/ `useOptimistic`（楽観的更新）。

推奨ライブラリ: React Hook Form + zod / Conform（Server Actions 連携）。

## セキュリティ

CVE-2025-55182（React2Shell）対応済み（19.0.3/19.1.4/19.2.3）。

## パフォーマンス

- Next.js: `next/image`（画像最適化）/ `revalidateTag()`（キャッシュ戦略）/ `export const runtime = 'edge'`（グローバル高速化）/ Turbopack（5-10x ビルド高速化）
- React 19: `useTransition`（スムーズ UX）/ Concurrent Rendering（UI フリーズ防止）

## Hooks ルール

トップレベルのみ（条件・ループ内禁止）/ React 関数内のみ / 依存配列を正確に（ESLint 警告従う）。

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
