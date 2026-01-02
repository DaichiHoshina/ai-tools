# Next.js / React ガイドライン

Next.js 16.1 + React 19.2対応（2026年1月時点）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **Server Components First**: デフォルトはServer Component
- **Client Component**: `'use client'` は最小限（インタラクション必要時のみ）
- **Concurrent Rendering**: React 19でデフォルト有効
- **React Compiler**: 自動最適化により`useMemo`/`useCallback`不要な場合多い
- **型安全**: Props・イベントハンドラも明示的型付け

---

## ディレクトリ構成

- `app/` - App Router（ルート、API Routes）
- `features/` - 機能別（domain / application / presentation）
- `shared/` - 共通コンポーネント、hooks、ユーティリティ

---

## クイックリファレンス

### コンポーネント種別

| 種別 | 用途 | 特徴 |
|------|------|------|
| Server Component | データフェッチ、静的表示 | async/await可、デフォルト |
| Client Component | インタラクション、状態 | `'use client'`必須 |
| Server Action | ミューテーション | `'use server'` |

### よく使うHooks

| Hook | 用途 | 制約 |
|------|------|------|
| `useState` | ローカル状態 | Client のみ |
| `useEffect` | 副作用 | Client のみ |
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
| Server Component で `ssr: false` | 通常の`import` | Next.js 15+でエラー |
| Client Component で `dynamic(..., {ssr: false})` | 通常の`import` | 冗長 |
| `process.env.NEXT_PUBLIC_*` を関数内で直接参照 | 設定ファイル経由 | ビルド時静的置換 |
| Context でグローバル状態 | Zustand/Jotai | パフォーマンス |
| `useEffect` でデータフェッチ | Server Component or TanStack Query | サーバー側で完結 |

## コンポーネント設計

### Server Components（デフォルト）
- async/await直接使用
- DB・APIコールはサーバー側実行
- `use()` Hook でストリーミングデータ

### Client Components（必要時のみ）
`'use client'` が必要:
- state / イベント（`onClick`, `onChange`）
- ライフサイクル（`useEffect`）
- ブラウザAPI（`localStorage`, `window`）

**戦略**: 小さなClient Islandsとして実装。葉のコンポーネントのみClient化。

### dynamic import（重要）
- **原則**: `'use client'` ファイルでは `dynamic` + `ssr: false` 不要
- Client Component既にクライアント実行のため冗長
- **Next.js 15+**: Server Componentで`ssr: false`はエラー

**推奨**:
- ✅ 通常の`import`（Client Component内）
- ✅ `dynamic()`でコード分割（ssr: falseなし）
- ❌ `dynamic(..., { ssr: false })` in Client Component

---

## 状態管理

### Server State
**TanStack Query**: キャッシュ、自動再検証、楽観的更新

### Client State
- **useState**: ローカルUI
- **useReducer**: 複雑なローカル状態
- **Zustand/Jotai**: グローバル（必要最小限）
- **Context**: 依存注入・テーマ等の静的値のみ

---

## データフェッチ（Next.js 15-16）

### キャッシュ設定
- `export const dynamic = 'force-dynamic'` - SSR強制
- `export const revalidate = 60` - ISR（60秒）
- `fetch(..., { next: { revalidate: 3600 } })` - 個別

### Server Actions
- `'use server'` でミューテーション
- `revalidatePath()` / `revalidateTag()` で再検証

### エラーハンドリング
- `error.tsx` - エラー境界
- `loading.tsx` - Suspenseローディング
- `not-found.tsx` - 404

---

## 環境変数（重要）

### 原則
関数スコープ内で`process.env.NEXT_PUBLIC_*`直接参照禁止

**理由**: Next.jsビルド時静的置換のため埋め込めない可能性

### 推奨: 設定ファイル一元管理
`src/config/*.ts`:
```ts
export const appConfig = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL ?? ""
} as const
```

---

## フォーム（React 19）

### 新Hooks
- **useActionState**: フォーム処理+状態管理
- **useFormStatus**: 送信状態（pending）
- **useOptimistic**: 楽観的UI更新

### 推奨ライブラリ
- **React Hook Form + zod**: バリデーション
- **Conform**: Server Actions連携

---

## React 19.2 新機能

### Activity Component（19.2）
- **visible mode**: 子要素表示、通常更新
- **hidden mode**: 子要素非表示、エフェクトアンマウント、更新延期

```ts
<Activity mode="hidden">
  <ExpensiveComponent />
</Activity>
```

### useEffectEvent Hook（19.2）
非リアクティブロジックをエフェクトイベントに抽出:
```ts
const onVisit = useEffectEvent(() => {
  logAnalytics(url)
})
```

### use API（19.0）
render内でPromise/Context読込:
```ts
const user = use(userPromise)
```

### React Compiler（19.0）
自動メモ化で`useMemo`/`useCallback`不要な場合多い。まずシンプル実装、問題時のみ最適化。

### セキュリティ更新（19.2.3）
- CVE-2025-55182（React2Shell）対応
- 複数の脆弱性修正を19.0.3/19.1.4/19.2.3にバックポート

---

## Next.js 16.1 新機能（2025年12月）

| 機能 | 説明 |
|------|------|
| **Bundle Analyzer（実験的）** | Turbopack対応の新アナライザー |
| **File System Cache改善** | キャッシュ効率向上 |
| **Turbopack安定化** | 開発・本番ビルドでデフォルト有効<br>新プロジェクトの標準バンドラーに |

### Next.js 16.0主要機能
- **"use cache" Directive**: PPRと組合せ、コンポーネント/関数キャッシュ
- **View Transitions**: ナビゲーション要素のアニメーション
- **after() API**: レスポンスストリーミング完了後処理
- **proxy.ts**: middlewareの後継（ネットワーク境界明確化）
- **MCP統合**: デバッグ・ワークフロー改善

### 参考リンク
- [Next.js 16.1 Release](https://nextjs.org/blog/next-16-1)
- [React 19.2 Release](https://react.dev/blog/2025/10/01/react-19-2)

---

## パフォーマンス

### Next.js
- `next/image` - 画像最適化
- `revalidateTag()` - キャッシュ戦略
- `export const runtime = 'edge'` - グローバル高速化
- **Turbopack**: 5-10x高速ビルド

### React 19
- `useTransition` - スムーズUX
- Concurrent Rendering - UIフリーズ防止

---

## Hooks ルール

- トップレベルのみ（条件・ループ内禁止）
- React関数内のみ
- 依存配列を正確に（ESLint警告従う）

---

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
- `React.MouseEvent<HTMLButtonElement>`
- `React.FormEvent<HTMLFormElement>`
- `React.ChangeEvent<HTMLInputElement>`

### Ref
```ts
useRef<HTMLDivElement>(null)
```
