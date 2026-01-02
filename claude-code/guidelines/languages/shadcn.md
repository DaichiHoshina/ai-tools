# shadcn/ui ガイドライン

v2.5.0対応（2025年最新）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **コピー&ペースト**: NPMパッケージではなく、コードを直接プロジェクトに配置
- **カスタマイズ可能**: 完全にカスタマイズ可能なコンポーネント
- **アクセシビリティ**: WCAG準拠
- **Radix UI + Tailwind**: 堅牢な基盤

---

## コンセプト

shadcn/uiは**コンポーネントライブラリではなく、再利用可能なコンポーネント集**:
- NPMでインストールせず、CLIでコードをコピー
- プロジェクトに配置後、自由にカスタマイズ
- 依存関係を最小限に抑える

---

## v2.5.0 新機能（2025年）

### "Resolve Anywhere"
- レジストリがアプリ内の任意の場所にファイル配置可能
- 固定ファイル構造の制約を撤廃
- インポート解決を自動化

### フレームワーク自動検出
- CLI がフレームワークを自動検出
- Laravel、Vite、React Router に対応
- ルート設定を自動調整

### Tailwind v4 & React 19 プレビュー
- Tailwind CSS v4 の初回プレビュー実装
- React 19 サポート

### Next.js 16 サポート
- `init` コマンドで Next.js 16 対応

---

## インストール

### 初期化
```bash
npx shadcn@latest init
```

対話式でプロジェクト設定:
- TypeScript/JavaScript
- スタイルテーマ
- ベースカラー
- CSS変数使用有無

### コンポーネント追加
```bash
npx shadcn@latest add button
npx shadcn@latest add form
```

---

## ディレクトリ構成

```
src/
├── components/
│   └── ui/          # shadcn/uiコンポーネント
├── lib/
│   └── utils.ts     # ユーティリティ関数
```

---

## 主要コンポーネント

### Form（推奨）
React Hook Form + Zod統合:
```tsx
const formSchema = z.object({
  username: z.string().min(2).max(50),
})

function ProfileForm() {
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
  })

  return <Form {...form}>...</Form>
}
```

### Button
```tsx
<Button variant="default">Default</Button>
<Button variant="destructive">Delete</Button>
<Button variant="outline">Outline</Button>
<Button variant="ghost">Ghost</Button>
```

### Dialog
```tsx
<Dialog>
  <DialogTrigger>Open</DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Title</DialogTitle>
      <DialogDescription>Description</DialogDescription>
    </DialogHeader>
  </DialogContent>
</Dialog>
```

---

## Blocks（v2.5+）

すぐ使えるレイアウト:
- ダッシュボードレイアウト
- 認証ページ
- レスポンシブ・アクセシブル・合成可能

```bash
npx shadcn@latest add login-01
```

---

## モノレポサポート

CLIがモノレポ対応:
```bash
npx shadcn@latest init --workspace=apps/web
```

---

## MCP統合（近日公開）

ゼロコンフィグMCPサポート:
```bash
npx shadcn registry:mcp
```

---

## エコシステム（2025年）

### TanCN
TanStack（Query、Table、Form）統合

### FormCN
フォームバリデーション特化

### Motion Primitives
アニメーション統合

---

## ベストプラクティス

### TypeScript活用
- 全コンポーネント型安全
- Props型を明示

### アクセシビリティ
- ARIA属性自動付与（Radix UI）
- キーボードナビゲーション対応
- スクリーンリーダー対応

### ダークモード
```tsx
import { ThemeProvider } from "@/components/theme-provider"

<ThemeProvider attribute="class" defaultTheme="system">
  {children}
</ThemeProvider>
```

### カスタマイズ
コンポーネントはプロジェクト内にあるため、直接編集可能:
- スタイル変更
- 機能追加
- バリアント追加

---

## 推奨構成

- **Next.js 15+** - App Router
- **React 19** - 最新機能
- **TypeScript** - 型安全性
- **Tailwind CSS v4** - スタイリング
- **Zod** - バリデーション
- **React Hook Form** - フォーム管理
