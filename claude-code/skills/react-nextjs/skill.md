---
name: react-nextjs
description: React/Next.js開発 - Reactパターン、Next.js機能、状態管理、パフォーマンス最適化
requires-guidelines:
  - nextjs-react
---

# React/Next.js開発

## 使用タイミング

- **React/Next.jsコンポーネント実装時**
- **状態管理・データフェッチ設計時**
- **Server/Client Components判断時**
- **パフォーマンス最適化時**

## 設計パターン

### 🔴 Critical（修正必須）

#### 1. Server/Client Components の誤用

```tsx
// ❌ 危険: Client Componentで不要な'use client'
'use client'

export default function StaticContent() {
  return <div>静的コンテンツ</div>  // インタラクションなし
}

// ✅ 正しい: Server Component（デフォルト）
export default function StaticContent() {
  return <div>静的コンテンツ</div>
}

// ❌ 危険: Server ComponentでuseState使用
export default function Counter() {
  const [count, setCount] = useState(0)  // エラー！
  return <button onClick={() => setCount(count + 1)}>{count}</button>
}

// ✅ 正しい: Client Component
'use client'

export default function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(count + 1)}>{count}</button>
}
```

#### 2. dynamic + ssr: false の誤用

```tsx
// ❌ 危険: Client Componentで冗長なdynamic
'use client'

const Map = dynamic(() => import('./Map'), { ssr: false })  // 不要！

// ✅ 正しい: Client Componentは通常import
'use client'

import Map from './Map'

// ✅ 正しい: コード分割のみ必要な場合
'use client'

const Map = dynamic(() => import('./Map'))  // ssr: falseなし
```

#### 3. 環境変数の不適切な参照

```tsx
// ❌ 危険: 関数スコープ内で直接参照
'use client'

function MyComponent() {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL  // ビルド時埋め込み失敗の可能性
  return <div>{apiUrl}</div>
}

// ✅ 正しい: 設定ファイルで一元管理
// src/config/app.ts
export const appConfig = {
  apiUrl: process.env.NEXT_PUBLIC_API_URL ?? "",
} as const

// MyComponent.tsx
'use client'
import { appConfig } from '@/config/app'

function MyComponent() {
  return <div>{appConfig.apiUrl}</div>
}
```

### 🟡 Warning（要改善）

#### 1. 過度なClient Component化

```tsx
// ⚠️ 親全体をClient化
'use client'

export default function Page() {
  return (
    <div>
      <Header />  {/* 静的 */}
      <Content />  {/* 静的 */}
      <InteractiveButton />  {/* 動的 */}
    </div>
  )
}

// ✅ 小さなClient Islands
// Page.tsx（Server Component）
export default function Page() {
  return (
    <div>
      <Header />
      <Content />
      <InteractiveButton />  {/* これだけClient Component */}
    </div>
  )
}

// InteractiveButton.tsx
'use client'
export default function InteractiveButton() {
  const [clicked, setClicked] = useState(false)
  return <button onClick={() => setClicked(true)}>クリック</button>
}
```

#### 2. 不要な最適化

```tsx
// ⚠️ React 19 Compilerで自動最適化されるケース
const memoizedValue = useMemo(() => computeValue(a, b), [a, b])
const memoizedCallback = useCallback(() => doSomething(a), [a])

// ✅ まずシンプルに実装
const value = computeValue(a, b)
const callback = () => doSomething(a)

// ※パフォーマンス問題が確認されたら最適化
```

#### 3. 状態管理の過剰設計

```tsx
// ⚠️ 単純なローカル状態をグローバル化
// store.ts
export const useCountStore = create((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
}))

// ✅ ローカル状態で十分
function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(count + 1)}>{count}</button>
}
```

## データフェッチパターン

### Server Components（推奨）

```tsx
// ✅ async Server Component
export default async function UserProfile({ userId }: Props) {
  const user = await fetchUser(userId)  // 直接await
  return <div>{user.name}</div>
}

// ✅ use() Hook（React 19）
export default function UserProfile({ userPromise }: Props) {
  const user = use(userPromise)
  return <div>{user.name}</div>
}
```

### Client Components

```tsx
// ✅ TanStack Query
'use client'

function UserProfile({ userId }: Props) {
  const { data: user, isLoading } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
  })

  if (isLoading) return <div>読み込み中...</div>
  return <div>{user.name}</div>
}
```

### Server Actions

```tsx
// ✅ フォーム処理
'use server'

export async function createUser(formData: FormData) {
  const name = formData.get('name') as string
  await db.user.create({ data: { name } })
  revalidatePath('/users')
}

// Client Component
'use client'

export default function CreateUserForm() {
  return (
    <form action={createUser}>
      <input name="name" />
      <button type="submit">作成</button>
    </form>
  )
}
```

## チェックリスト

### コンポーネント設計
- [ ] Server Component優先（デフォルト）
- [ ] Client Componentは必要最小限
- [ ] 1ファイル1コンポーネント
- [ ] Props型定義が明示的
- [ ] イベントハンドラ型が適切

### データフェッチ
- [ ] Server ComponentでDB直接アクセス
- [ ] キャッシュ戦略が明確（revalidate設定）
- [ ] エラーハンドリング（error.tsx, try-catch）
- [ ] ローディング表示（loading.tsx, Suspense）

### 状態管理
- [ ] Server State: TanStack Query
- [ ] Client State: useState/useReducer
- [ ] グローバル状態は必要最小限
- [ ] Contextは静的値のみ

### パフォーマンス
- [ ] next/imageで画像最適化
- [ ] dynamic importでコード分割
- [ ] 不要なClient Component化を避ける
- [ ] revalidateTagでキャッシュ制御

### 環境変数
- [ ] 設定ファイルで一元管理
- [ ] NEXT_PUBLIC_*はクライアント公開を意識
- [ ] Server-only変数はServer Componentsで使用

## 出力形式

🔴 **Critical**: `ファイル:行` - Server/Client誤用/環境変数問題 - 修正案
🟡 **Warning**: `ファイル:行` - 過剰最適化/設計改善推奨 - リファクタ案
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

レビュー実施前に以下のガイドラインを参照:
- `~/.claude/guidelines/languages/nextjs-react.md`

## 外部知識ベース

最新のReact/Next.jsベストプラクティス確認には context7 を活用:
- Next.js公式ドキュメント
- React 19ドキュメント
- TanStack Query
- Zustand / Jotai

## プロジェクトコンテキスト

プロジェクト固有のReact/Next.js設定を確認:
- serena memory からプロジェクト構成を取得
- ディレクトリ構造（app/, features/, shared/）
- 既存のServer/Client Components比率
- 状態管理ライブラリの選択
