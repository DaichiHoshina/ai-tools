---
name: ui-skills
description: UI Skills - Tailwind CSS/motion/react特化のエージェント向けUI構築制約 + UIデザインシステム + Playwrightビジュアル検証
requires-guidelines:
  - nextjs-react
  - tailwind
  - shadcn
---

# ui-skills - UI構築制約

## 使用タイミング

- Tailwind CSS/React実装時
- アニメーション実装レビュー時
- アクセシブルコンポーネント構築時

**公式**: https://github.com/ibelick/ui-skills

---

## テクノロジースタック

| 要素 | 要件 | 詳細 |
|------|------|------|
| スタイリング | **MUST** | Tailwind CSS defaults |
| アニメーション | **MUST** | `motion/react` |
| クラス管理 | **MUST** | `cn`（`clsx` + `tailwind-merge`） |

---

## ルール早見表

### Components

| 区分 | ルール |
|------|--------|
| 🔴 MUST | アクセシブルコンポーネントプリミティブ使用（Base UI, React Aria, Radix） |
| 🔴 MUST | アイコンのみボタンに`aria-label` |
| 🔴 NEVER | 同一インタラクション内で複数プリミティブシステム混在 |
| 🔴 NEVER | キーボード・フォーカス動作の手動実装 |

### Interaction

| 区分 | ルール |
|------|--------|
| 🔴 MUST | 破壊的アクション → `AlertDialog`必須 |
| 🔴 MUST | エラーはアクション発生場所の隣に表示 |
| 🔴 MUST | 固定要素に`safe-area-inset`尊重 |
| 🔴 NEVER | `h-screen`使用（`h-dvh`に置換） |
| 🔴 NEVER | `input`/`textarea`のペースト禁止 |
| 🟡 SHOULD | ローディングは構造的スケルトン表示 |

### Animation

| 区分 | ルール |
|------|--------|
| 🔴 MUST | 明示的リクエストなしのアニメーション追加禁止 |
| 🔴 MUST | `transform`, `opacity`のみアニメート |
| 🔴 NEVER | レイアウト属性の動画化（`width`, `height`, `margin`等） |
| 🔴 NEVER | インタラクションフィードバック200ms超 |
| 🟡 SHOULD | `prefers-reduced-motion`尊重 |

### Typography

| 区分 | ルール |
|------|--------|
| 🔴 MUST | 見出し → `text-balance` |
| 🔴 MUST | 本文・段落 → `text-pretty` |
| 🔴 MUST | データ表示 → `tabular-nums` |
| 🔴 NEVER | 明示要求なしの`letter-spacing`変更 |

### Layout

| 区分 | ルール |
|------|--------|
| 🔴 MUST | 固定z-indexスケール（任意`z-[999]`禁止） |
| 🟡 SHOULD | 正方形要素は`size-*`（`w-* h-*`より優先） |

### Performance

| 区分 | ルール |
|------|--------|
| 🔴 NEVER | 大規模`blur()`/`backdrop-filter`の動画化 |
| 🔴 NEVER | アクティブアニメーション外での`will-change` |
| 🔴 NEVER | レンダーロジックで可能な処理に`useEffect` |

### Design

| 区分 | ルール |
|------|--------|
| 🔴 MUST | 空状態に明確な次アクションを用意 |
| 🔴 NEVER | 明示要求なしのグラデーション |
| 🔴 NEVER | 紫色/マルチカラーグラデーション |
| 🟡 SHOULD | 既存テーマ/Tailwind標準色を優先 |

---

## 主要パターン

```tsx
// アイコンボタン
<button aria-label="Close menu"><X className="size-4" /></button>

// h-dvh使用
<div className="h-dvh">...</div>

// 破壊的アクション
<AlertDialog>
  <AlertDialogTrigger asChild><Button variant="destructive">Delete</Button></AlertDialogTrigger>
  <AlertDialogContent>...</AlertDialogContent>
</AlertDialog>

// アニメーション（transform/opacityのみ）
<motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }} />
```

---

## チェックリスト

- [ ] アクセシブルコンポーネントプリミティブ使用
- [ ] アイコンボタンに`aria-label`
- [ ] 破壊的アクションに`AlertDialog`
- [ ] `h-screen` → `h-dvh`
- [ ] アニメーションは`transform`/`opacity`のみ
- [ ] 不要な`useEffect`なし
- [ ] Tailwind標準色優先

---

## 出力形式

```markdown
## UI Skillsレビュー結果

### 🔴 Critical Violations
**`Button.tsx:15`** - アクセシブルコンポーネント未使用 → Radix UI Buttonに置換

### 🟡 Warnings
**`Card.tsx:8`** - カスタムカラー使用 → `bg-primary`推奨

### ✅ Summary
Critical: 1件 / Warning: 1件
```

---

## UIデザインシステム

### テーマプリセット

AIが生成するUIはデフォルトだとダサくなる。**必ずテーマを適用してから実装開始**すること。

| プリセット | 雰囲気 | 用途 | radius |
|-----------|--------|------|--------|
| **corporate** | 洗練・信頼・クリーン | 業務系ダッシュボード、管理画面 | 0.5rem |
| **modern-dark** | ダーク・シャープ・技術的 | データ分析、モニタリング、開発ツール | 0.375rem |
| **soft** | 柔らかい・親しみやすい | チームツール、SaaS、社内ツール | 0.75rem |

テンプレート（フレームワーク別）:

| フレームワーク | パス | 形式 |
|--------------|------|------|
| **shadcn/ui** | `~/.claude/templates/ui-themes/shadcn/` | oklch CSS variables + @theme inline |
| **Tailwind CSS / vanilla CSS** | `~/.claude/templates/ui-themes/tailwind/` | CSS Custom Properties |
| **任意（トークン参照）** | `~/.claude/templates/ui-themes/tokens/` | JSON design tokens |

#### フレームワーク自動検出

```
UI実装リクエスト検出時:
1. カスタムテーマ検出:
   globals.css等に --color-primary や --primary のCSS変数定義あり → そのまま使用
2. テーマなし → フレームワーク検出（上から順に判定、最初にマッチした形式を使用）:
   a. プロジェクトrootに components.json あり → shadcn/ui → ui-themes/shadcn/ から適用
   b. (a)に該当せず tailwind.config.{js,ts,mjs} あり → ui-themes/tailwind/ から適用
   c. いずれにも該当しない → ui-themes/tokens/ のJSONを参照
3. AskUserQuestion でプリセット選択（または自動判定）
4. テーマファイルの適用:
   - shadcn → app/globals.css に上書き
   - tailwind → src/styles/theme.css として作成し、globals.cssで @import
   - tokens → JSONを参照してプロジェクトのCSS/Sass変数に手動変換
```

#### tokens版の使い方（非shadcn、非Tailwindプロジェクト）

JSONトークンからCSS変数への変換例:

```css
/* tokens/corporate.json の値を手動でCSSに変換 */
:root {
  --color-primary: #4f46e5;  /* tokens.color.primary.light */
  --color-bg: #fafaff;       /* tokens.color.bg.light */
  --radius-lg: 0.5rem;       /* tokens.radius.lg */
  --font-sans: system-ui, -apple-system, sans-serif; /* tokens.typography.fontFamily.sans */
}
```

Styled Components等のJS-in-CSS:

```typescript
import tokens from './tokens/corporate.json';
const theme = {
  primary: tokens.color.primary.light,
  bg: tokens.color.bg.light,
};
```

#### テーマカスタマイズ

適用後、ブランドカラー等を変更したい場合:

- **shadcn版**: `globals.css` の `:root` / `.dark` セクションで `--primary` 等を上書き
- **Tailwind版**: `--color-primary` 等のCSS変数を直接変更
- **tokens版**: JSONを編集してCSS再生成

### テーマ自動判定ロジック

ユーザーがテーマを選ばない場合、以下のルールで自動判定:

| 判定条件 | テーマ |
|---------|--------|
| 「経営」「業務」「管理」「レポート」「営業」 | corporate |
| 「モニタリング」「分析」「ログ」「メトリクス」「API」「開発」 | modern-dark |
| 「チーム」「社内」「タスク」「プロジェクト」「コラボ」 | soft |
| 判定不能 | corporate（最も汎用的） |

### デザインブリーフ（--detailedオプション時）

UI実装前に以下5要素を確認。テーマ選択だけでも品質は大幅に向上するが、さらに高品質を求める場合に使用。

| # | 要素 | 質問例 |
|---|------|--------|
| 1 | 情報優先度 | 画面で最も重要な情報は？（KPI数値、アクティブユーザー数等） |
| 2 | レイアウト密度 | データ密度は高い？余白重視？ |
| 3 | トーン | フォーマル？カジュアル？ |
| 4 | カラーアクセント | ブランドカラーは？（指定なしならテーマから） |
| 5 | 参考デザイン | 近いイメージは？（Linear風、Vercel風、Notion風等） |

---

## ダッシュボード設計パターン

### 視覚的階層（最重要）

ダッシュボードで最も重要なのは**情報の優先度を視覚的に表現すること**。

```
🔴 NG: 全要素が同じサイズ・色・余白
✅ OK: KPI大きく → トレンド中 → 詳細テーブル小さく
```

#### 3層構造

```
Layer 1: Hero Metrics（最重要KPI）
  - text-3xl / text-4xl + font-bold
  - primaryカラーでアクセント
  - カード全幅 or 大きめグリッド（col-span-2）

Layer 2: Trends（傾向把握）
  - チャート、グラフ
  - 中サイズカード
  - muted背景で視覚的に区別

Layer 3: Details（詳細データ）
  - テーブル、リスト
  - text-sm
  - 控えめなスタイリング
```

### レイアウト原則

| 原則 | 実装 |
|------|------|
| グリッドの強弱 | `grid-cols-3` で 1つだけ `col-span-2` にする |
| 余白のリズム | セクション間 `gap-6`、カード内 `p-6`、要素間 `space-y-2` |
| 色の使い分け | primaryは1箇所だけ強調、他はmuted/secondary |
| タイポグラフィ階層 | 最低3段階（h2 text-2xl / h3 text-lg / body text-sm） |
| データ表示 | 数値は `font-mono tabular-nums`、単位は `text-muted-foreground text-xs` |

### ダッシュボード実装例（Tailwind CSS）

どのフレームワークでも使えるTailwind + CSS Custom Properties版:

```html
<!-- ダッシュボード全体構造（CSS Custom Propertiesでテーマ適用） -->
<div class="space-y-[var(--space-section)] p-[var(--space-card)]"
     style="background: var(--color-bg); color: var(--color-text);">

  <!-- Layer 1: Hero Metrics - 4列グリッド、1つだけ強調 -->
  <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
    <div class="col-span-2 rounded-[var(--radius-lg)] border p-[var(--space-card)]"
         style="background: color-mix(in srgb, var(--color-primary) 5%, var(--color-surface));
                border-color: color-mix(in srgb, var(--color-primary) 20%, transparent);">
      <p class="text-sm" style="color: var(--color-text-muted);">Total Revenue</p>
      <p class="text-4xl font-bold tabular-nums tracking-tight">$45,231.89</p>
      <p class="text-sm mt-1" style="color: var(--color-text-muted);">
        <span class="font-medium" style="color: var(--color-success);">+20.1%</span> from last month
      </p>
    </div>
    <div class="rounded-[var(--radius-lg)] border p-[var(--space-card)]"
         style="background: var(--color-surface); border-color: var(--color-border);">
      <p class="text-sm" style="color: var(--color-text-muted);">New Customers</p>
      <p class="text-2xl font-semibold tabular-nums">234</p>
      <p class="text-xs mt-1" style="color: var(--color-text-muted);">+8% from last month</p>
    </div>
    <div class="rounded-[var(--radius-lg)] border p-[var(--space-card)]"
         style="background: var(--color-surface); border-color: var(--color-border);">
      <p class="text-sm" style="color: var(--color-text-muted);">Conversion Rate</p>
      <p class="text-2xl font-semibold tabular-nums">3.2%</p>
      <p class="text-xs mt-1" style="color: var(--color-text-muted);">-0.5% from last month</p>
    </div>
  </div>

  <!-- Layer 2: Trends - 非均等分割 -->
  <div class="grid gap-4 md:grid-cols-7">
    <div class="col-span-4 rounded-[var(--radius-lg)] border p-[var(--space-card)]"
         style="background: var(--color-surface); border-color: var(--color-border);">
      <h3 class="text-lg font-semibold mb-4">Revenue Trend</h3>
      <!-- chart here -->
    </div>
    <div class="col-span-3 rounded-[var(--radius-lg)] border p-[var(--space-card)]"
         style="background: var(--color-surface); border-color: var(--color-border);">
      <h3 class="text-lg font-semibold mb-4">Top Categories</h3>
      <!-- chart here -->
    </div>
  </div>

  <!-- Layer 3: Details -->
  <div class="rounded-[var(--radius-lg)] border p-[var(--space-card)]"
       style="background: var(--color-surface); border-color: var(--color-border);">
    <h3 class="text-lg font-semibold">Recent Transactions</h3>
    <p class="text-sm mb-4" style="color: var(--color-text-muted);">Last 30 days</p>
    <!-- table here -->
  </div>
</div>
```

> **shadcn/ui使用時**: 上記のdiv+styleをshadcnの`<Card>`,`<CardHeader>`,`<CardContent>`等に置き換え。テーマCSS側でshadcn変数が定義済みなのでstyle属性は不要。

**ポイント**:
- Hero MetricのカードだけCol-span-2 + primary背景で視覚的に強調
- font-size: 4xl → 2xl → lg → sm の4段階で階層を作る
- グリッド列数を7にして4:3分割（均等分割を避ける）
- spacing: セクション間`space-y-*`、カード間`gap-4`で一貫
- CSS Custom Propertiesでテーマを参照するため、テーマ切替だけで全体の色が変わる

---

## Playwrightビジュアル検証

### 目的

Claude Codeは生成したUIを「見る」ことができない。Playwrightでスクリーンショットを撮り、マルチモーダル評価で品質を検証する。

### 実行フロー

```
UI実装完了
  ↓
dev server起動（next dev / vite dev 等）
  ↓
Playwright スクリーンショット撮影
  npx tsx ~/.claude/templates/ui-themes/playwright-visual-check.ts
  ↓
Claude が /tmp/ui-visual-check/*.png を Read で読み込み
  ↓
5観点で視覚評価:
  1. 視覚的階層: KPI数値が最も目立っているか
  2. 余白バランス: 詰まりすぎ/スカスカすぎないか
  3. 色の一貫性: テーマカラーが正しく適用されているか
  4. タイポグラフィ: 見出し・本文・キャプションに明確な差があるか
  5. アライメント: 要素が整列しているか
  ↓
問題あり → 修正 → 再撮影（最大3回ループ）
  ↓
品質OK → 完了
```

テンプレート: `~/.claude/templates/ui-themes/playwright-visual-check.ts`

### 前提条件

1. dev server起動（デフォルト: `http://localhost:3000`）
2. 異なるポートの場合: `BASE_URL=http://localhost:5173 npx tsx ...`
3. `npx playwright install chromium`（初回のみ）

### 注意事項

- スクリーンショットは `/tmp/ui-visual-check/` に保存
- 3回修正しても改善しない場合はユーザーに相談

---

## 参考リンク

- [ui-skills](https://github.com/ibelick/ui-skills)
- [Base UI](https://base-ui.com/)
- [React Aria](https://react-spectrum.adobe.com/react-aria/)
- [Radix UI](https://www.radix-ui.com/)
- [motion/react](https://motion.dev/)
