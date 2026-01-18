---
name: ui-skills
description: UI Skills - Tailwind CSS/motion/react特化のエージェント向けUI構築制約
requires-guidelines:
  - nextjs-react
  - tailwind
  - shadcn
---

# UI Skills: エージェント向けUI構築制約

## 使用タイミング

- **Tailwind CSS/React実装時**
- **アニメーション実装レビュー時**
- **アクセシブルコンポーネント構築時**
- **パフォーマンス最適化時**

---

## 概要

UI SkillsはClaude Code、Cursor、OpenCode等のAIコーディングアシスタント向けに設計された、**意見付きのUI構築制約集**です。Tailwind CSS、motion/react、アクセシブルコンポーネントプリミティブを前提とした、MUST/SHOULD/NEVER形式の明確なルールを提供します。

**公式リポジトリ**: https://github.com/ibelick/ui-skills

---

## インストール・使用方法

**インストール**:
```bash
curl -fsSL https://ui-skills.com/install | bash
```

**使用コマンド**:
```bash
/ui-skills                 # セッション内でルール適用開始
/ui-skills <file>          # ファイルレビュー（違反・理由・修正案）
/ui-skills review src/     # ディレクトリ全体をレビュー
```

---

## テクノロジースタック（必須）

| 要素 | 要件 | 詳細 |
|------|------|------|
| スタイリング | **MUST** | Tailwind CSS defaults（既存カスタム値がある場合を除く） |
| アニメーション | **MUST** | `motion/react`（旧framer-motion）使用 |
| マイクロアニメ | **SHOULD** | `tw-animate-css`を活用 |
| クラス管理 | **MUST** | `cn`ユーティリティ（`clsx` + `tailwind-merge`） |

---

## Components（コンポーネント設計）

### 🔴 MUST（必須）

- **アクセシブルコンポーネントプリミティブ使用**
  - キーボード・フォーカス挙動を含むコンポーネントは **Base UI、React Aria、Radix** 等を使用
  - 既存のコンポーネントプリミティブを優先

- **アイコンのみボタンに`aria-label`追加**
  ```tsx
  // ✅ Good
  <button aria-label="Close menu">
    <X className="size-4" />
  </button>

  // ❌ Bad
  <button>
    <X className="size-4" />
  </button>
  ```

### 🔴 NEVER（禁止）

- **同一インタラクション内での複数プリミティブシステムの混在**
  - 例: Radix UIとReact Ariaを同一フォーム内で混在させない

- **明示要求がない限り、キーボード・フォーカス動作の手動実装**
  - プリミティブライブラリに任せる

### 🟡 SHOULD（推奨）

- **Base UIを新規プリミティブの第一選択肢に**
  - 互換性がある場合はBase UIを優先

---

## Interaction（相互作用設計）

### 🔴 MUST

- **破壊的または不可逆的アクション → `AlertDialog`必須**
  ```tsx
  // ✅ Good
  <AlertDialog>
    <AlertDialogTrigger asChild>
      <Button variant="destructive">Delete Account</Button>
    </AlertDialogTrigger>
    <AlertDialogContent>
      <AlertDialogHeader>
        <AlertDialogTitle>Are you sure?</AlertDialogTitle>
        <AlertDialogDescription>
          This action cannot be undone.
        </AlertDialogDescription>
      </AlertDialogHeader>
      <AlertDialogFooter>
        <AlertDialogCancel>Cancel</AlertDialogCancel>
        <AlertDialogAction onClick={handleDelete}>Delete</AlertDialogAction>
      </AlertDialogFooter>
    </AlertDialogContent>
  </AlertDialog>
  ```

- **エラーは「アクションが発生した場所の隣に表示」**
  ```tsx
  // ✅ Good
  <form>
    <input {...field} />
    {error && <p className="text-sm text-destructive">{error}</p>}
  </form>
  ```

- **固定要素に`safe-area-inset`尊重**
  ```css
  /* ✅ Good */
  .fixed-header {
    padding-top: env(safe-area-inset-top);
  }
  ```

### 🟡 SHOULD

- **ローディング状態は構造的スケルトン表示**
  ```tsx
  // ✅ Good
  {isLoading ? (
    <div className="space-y-2">
      <Skeleton className="h-4 w-full" />
      <Skeleton className="h-4 w-3/4" />
    </div>
  ) : (
    <Content />
  )}
  ```

### 🔴 NEVER

- **`h-screen`使用（代わりに`h-dvh`）**
  ```tsx
  // ✅ Good
  <div className="h-dvh">...</div>

  // ❌ Bad
  <div className="h-screen">...</div>
  ```

- **`input` / `textarea`のペースト禁止**
  - ユーザビリティを損なう

---

## Animation（アニメーション）

### 🔴 MUST

- **明示的なリクエストがない限り「アニメーション追加禁止」**
  - ユーザーが要求した場合のみアニメーション実装

- **コンポジター属性のみアニメート**
  - `transform`、`opacity`のみ使用（GPUアクセラレーション）

### 🔴 NEVER

- **レイアウト属性の動画化禁止**
  - ❌ `width`、`height`、`top`、`left`、`margin`、`padding`
  - ✅ `transform: scale()`、`transform: translate()`を使用

- **ペイント属性の動画化禁止**（小型UIのみ例外）
  - ❌ `background`、`color`（大型要素）
  - ✅ 小さなボタン・アイコンは許容

- **カスタムイージング曲線禁止**（明示要求なし）
  - Tailwindデフォルトのイージングを使用

- **大規模画像・フルスクリーン表面の動画化禁止**

- **インタラクションフィードバック時の「200msを超える」期間禁止**
  ```tsx
  // ✅ Good
  <motion.button
    whileTap={{ scale: 0.95 }}
    transition={{ duration: 0.1 }}
  />

  // ❌ Bad
  <motion.button
    whileTap={{ scale: 0.95 }}
    transition={{ duration: 0.5 }}
  />
  ```

### 🟡 SHOULD

- **エントランスで`ease-out`使用**
  ```tsx
  <motion.div
    initial={{ opacity: 0, y: 20 }}
    animate={{ opacity: 1, y: 0 }}
    transition={{ ease: "easeOut", duration: 0.3 }}
  />
  ```

- **オフスクリーン時ループアニメーション停止**
  - Intersection Observerで制御

- **`prefers-reduced-motion`尊重**
  ```tsx
  const prefersReducedMotion = window.matchMedia(
    '(prefers-reduced-motion: reduce)'
  ).matches;

  <motion.div
    animate={prefersReducedMotion ? {} : { x: 100 }}
  />
  ```

---

## Typography（テキスト配置）

### 🔴 MUST

- **見出し → `text-balance`**
  ```tsx
  <h1 className="text-balance">...</h1>
  ```

- **本文・段落 → `text-pretty`**
  ```tsx
  <p className="text-pretty">...</p>
  ```

- **データ表示 → `tabular-nums`**
  ```tsx
  <span className="tabular-nums">$1,234.56</span>
  ```

### 🟡 SHOULD

- **密集UI → `truncate`または`line-clamp`**
  ```tsx
  <p className="truncate">...</p>
  <p className="line-clamp-3">...</p>
  ```

### 🔴 NEVER

- **明示的要求なしの`letter-spacing`（`tracking-*`）変更**
  - デザイナーからの明示的な指示がない限り使用禁止

---

## Layout（レイアウト）

### 🔴 MUST

- **固定z-indexスケール使用（任意の`z-*`禁止）**
  ```tsx
  // ✅ Good - Tailwindのスケール使用
  <div className="z-10">...</div>
  <div className="z-50">...</div>

  // ❌ Bad - 任意の値
  <div className="z-[999]">...</div>
  ```

### 🟡 SHOULD

- **正方形要素は`size-*`（`w-*` + `h-*`の組み合わせより優先）**
  ```tsx
  // ✅ Good
  <div className="size-10">...</div>

  // ❌ Bad
  <div className="w-10 h-10">...</div>
  ```

---

## Performance（パフォーマンス）

### 🔴 NEVER

- **大規模`blur()`や`backdrop-filter`の動画化禁止**
  - パフォーマンスに重大な影響

- **アクティブなアニメーション外での`will-change`適用禁止**
  ```tsx
  // ✅ Good
  <motion.div
    animate={{ x: 100 }}
    style={{ willChange: isAnimating ? 'transform' : 'auto' }}
  />

  // ❌ Bad
  <div className="will-change-transform">...</div>
  ```

- **レンダーロジックで表現可能な処理に`useEffect`使用禁止**
  ```tsx
  // ✅ Good
  const total = items.reduce((sum, item) => sum + item.price, 0);

  // ❌ Bad
  const [total, setTotal] = useState(0);
  useEffect(() => {
    setTotal(items.reduce((sum, item) => sum + item.price, 0));
  }, [items]);
  ```

---

## Design（デザイン決定）

### 🔴 NEVER

- **明示要求なしのグラデーション**
- **紫色またはマルチカラーグラデーション**
- **グロー効果を主要な視覚手がかりに**

### 🟡 SHOULD

- **新規色導入前に既存テーマまたはTailwind CSS標準色を使用**
  ```tsx
  // ✅ Good
  <div className="bg-primary">...</div>
  <div className="text-blue-600">...</div>

  // ❌ Bad
  <div className="bg-[#6750A4]">...</div>
  ```

- **シャドウはTailwindデフォルトスケール優先**
  ```tsx
  // ✅ Good
  <div className="shadow-md">...</div>

  // ❌ Bad
  <div className="shadow-[0_4px_6px_rgba(0,0,0,0.1)]">...</div>
  ```

- **1ビュー内の強調色を1つに制限**
  - アクセントカラーは1種類のみ

### 🔴 MUST

- **空状態には「1つの明確な次のアクション」を用意**
  ```tsx
  // ✅ Good
  <EmptyState>
    <p>No items found</p>
    <Button onClick={handleAdd}>Add your first item</Button>
  </EmptyState>
  ```

---

## レビュー手順

### Step 1: テクノロジースタックチェック

- [ ] Tailwind CSS使用
- [ ] `motion/react`使用（アニメーションがある場合）
- [ ] `cn`ユーティリティ使用（`clsx` + `tailwind-merge`）

### Step 2: コンポーネントチェック

- [ ] アクセシブルコンポーネントプリミティブ使用（Base UI、React Aria、Radix）
- [ ] アイコンのみボタンに`aria-label`
- [ ] プリミティブシステム混在なし

### Step 3: インタラクションチェック

- [ ] 破壊的アクションに`AlertDialog`
- [ ] エラー表示位置適切（アクションの隣）
- [ ] `h-screen`を`h-dvh`に置換
- [ ] ペースト禁止なし

### Step 4: アニメーションチェック

- [ ] 不要なアニメーション追加なし
- [ ] レイアウト属性の動画化なし（`width`、`height`等）
- [ ] `transform`、`opacity`のみ使用
- [ ] インタラクションフィードバック200ms以内
- [ ] `prefers-reduced-motion`尊重

### Step 5: タイポグラフィチェック

- [ ] 見出しに`text-balance`
- [ ] 本文に`text-pretty`
- [ ] 数値に`tabular-nums`
- [ ] 不要な`tracking-*`なし

### Step 6: レイアウトチェック

- [ ] 固定z-indexスケール使用
- [ ] 正方形要素に`size-*`

### Step 7: パフォーマンスチェック

- [ ] `blur()`/`backdrop-filter`の動画化なし
- [ ] 不要な`will-change`なし
- [ ] 不要な`useEffect`なし

### Step 8: デザインチェック

- [ ] 不要なグラデーションなし
- [ ] Tailwind標準色優先
- [ ] 空状態にCTA配置

---

## 出力形式

### レビュー結果

```markdown
## UI Skillsレビュー結果

### 🔴 Critical Violations

**`Button.tsx:15`** - アクセシブルコンポーネントプリミティブ未使用
- 問題: キーボード・フォーカス動作を手動実装
- 修正案: Radix UI `Button`に置換
```tsx
import { Button } from "@radix-ui/themes";
```

**`Hero.tsx:20`** - レイアウト属性のアニメーション
- 問題: `height`を直接アニメート（リフロー発生）
- 修正案: `transform: scaleY()`使用
```tsx
<motion.div
  initial={{ scaleY: 0 }}
  animate={{ scaleY: 1 }}
/>
```

### 🟡 Warnings

**`Card.tsx:8`** - カスタムカラー使用
- 問題: `#6750A4`を直接指定
- 改善案: `bg-primary`または`bg-purple-600`使用

**`Header.tsx:12`** - `h-screen`使用
- 問題: モバイルでビューポート問題
- 改善案: `h-dvh`に置換

### ✅ Summary
- Critical: 2件
- Warning: 2件
- 総合評価: Criticalを優先修正してください
```

---

## 既存スキルとの使い分け

| スキル | 用途 | 対象技術 |
|--------|------|----------|
| `ui-skills` | Tailwind/React特化のUI制約レビュー | Tailwind CSS、motion/react、Radix UI等 |
| `uiux-review` | Material Design 3 + WCAG 2.2 AA + Nielsen 10原則 | 汎用UI/UXレビュー、デザインシステム |
| `react-best-practices` | React/Next.jsパフォーマンス最適化 | Vercel推奨パターン、45ルール8カテゴリ |

### 推奨使用パターン

```bash
# Tailwind/React案件で実装前チェック
/ui-skills review src/components

# 包括的UI/UXレビュー（アクセシビリティ重視）
/review  # → uiux-review自動選択

# パフォーマンス最適化レビュー
/react-best-practices
```

---

## 参考リンク

- [GitHub](https://github.com/ibelick/ui-skills)
- [公式サイト](https://ui-skills.com/)
- [Base UI](https://base-ui.com/)
- [React Aria](https://react-spectrum.adobe.com/react-aria/)
- [Radix UI](https://www.radix-ui.com/)
- [motion/react](https://motion.dev/)
