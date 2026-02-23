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
| MUST | アクセシブルコンポーネントプリミティブ使用（Base UI, React Aria, Radix） |
| MUST | アイコンのみボタンに`aria-label` |
| NEVER | 同一インタラクション内で複数プリミティブシステム混在 |
| NEVER | キーボード・フォーカス動作の手動実装 |

### Interaction

| 区分 | ルール |
|------|--------|
| MUST | 破壊的アクション → `AlertDialog`必須 |
| MUST | エラーはアクション発生場所の隣に表示 |
| MUST | 固定要素に`safe-area-inset`尊重 |
| NEVER | `h-screen`使用（`h-dvh`に置換） |
| NEVER | `input`/`textarea`のペースト禁止 |
| SHOULD | ローディングは構造的スケルトン表示 |

### Animation

| 区分 | ルール |
|------|--------|
| MUST | 明示的リクエストなしのアニメーション追加禁止 |
| MUST | `transform`, `opacity`のみアニメート |
| NEVER | レイアウト属性の動画化（`width`, `height`, `margin`等） |
| NEVER | インタラクションフィードバック200ms超 |
| SHOULD | `prefers-reduced-motion`尊重 |

### Typography

| 区分 | ルール |
|------|--------|
| MUST | 見出し → `text-balance` |
| MUST | 本文・段落 → `text-pretty` |
| MUST | データ表示 → `tabular-nums` |
| NEVER | 明示要求なしの`letter-spacing`変更 |

### Layout

| 区分 | ルール |
|------|--------|
| MUST | 固定z-indexスケール（任意`z-[999]`禁止） |
| SHOULD | 正方形要素は`size-*`（`w-* h-*`より優先） |

### Performance

| 区分 | ルール |
|------|--------|
| NEVER | 大規模`blur()`/`backdrop-filter`の動画化 |
| NEVER | アクティブアニメーション外での`will-change` |
| NEVER | レンダーロジックで可能な処理に`useEffect` |

### Design

| 区分 | ルール |
|------|--------|
| MUST | 空状態に明確な次アクションを用意 |
| NEVER | 明示要求なしのグラデーション |
| NEVER | 紫色/マルチカラーグラデーション |
| SHOULD | 既存テーマ/Tailwind標準色を優先 |

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

### Critical Violations
**`Button.tsx:15`** - アクセシブルコンポーネント未使用 → Radix UI Buttonに置換

### Warnings
**`Card.tsx:8`** - カスタムカラー使用 → `bg-primary`推奨

### Summary
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
1. globals.css等に CSS変数定義あり → そのまま使用
2. テーマなし → フレームワーク検出（上から順に判定）:
   a. components.json あり → shadcn/ui → ui-themes/shadcn/ から適用
   b. tailwind.config.{js,ts,mjs} あり → ui-themes/tailwind/ から適用
   c. いずれにも該当しない → ui-themes/tokens/ のJSONを参照
3. AskUserQuestion でプリセット選択（または自動判定）
4. テーマファイルの適用
```

### テーマ自動判定ロジック

ユーザーがテーマを選ばない場合、以下のルールで自動判定:

| 判定条件 | テーマ |
|---------|--------|
| 「経営」「業務」「管理」「レポート」「営業」 | corporate |
| 「モニタリング」「分析」「ログ」「メトリクス」「API」「開発」 | modern-dark |
| 「チーム」「社内」「タスク」「プロジェクト」「コラボ」 | soft |
| 判定不能 | corporate（最も汎用的） |

### デザインブリーフ（--detailedオプション時）

| # | 要素 | 質問例 |
|---|------|--------|
| 1 | 情報優先度 | 画面で最も重要な情報は？ |
| 2 | レイアウト密度 | データ密度は高い？余白重視？ |
| 3 | トーン | フォーマル？カジュアル？ |
| 4 | カラーアクセント | ブランドカラーは？ |
| 5 | 参考デザイン | 近いイメージは？（Linear風、Vercel風等） |

---

## ダッシュボード設計パターン

### 視覚的階層（最重要）

```
NG: 全要素が同じサイズ・色・余白
OK: KPI大きく → トレンド中 → 詳細テーブル小さく
```

#### 3層構造

| Layer | 役割 | スタイル |
|-------|------|---------|
| Layer 1: Hero Metrics | 最重要KPI | text-3xl/4xl + font-bold、primaryアクセント |
| Layer 2: Trends | 傾向把握 | チャート、中サイズカード |
| Layer 3: Details | 詳細データ | テーブル、text-sm、控えめスタイル |

### レイアウト原則

| 原則 | 実装 |
|------|------|
| グリッドの強弱 | `grid-cols-3` で1つだけ `col-span-2` |
| 余白のリズム | セクション間 `gap-6`、カード内 `p-6` |
| 色の使い分け | primaryは1箇所だけ強調、他はmuted/secondary |
| タイポグラフィ階層 | 最低3段階（h2 text-2xl / h3 text-lg / body text-sm） |
| データ表示 | 数値は `font-mono tabular-nums` |

---

## Playwrightビジュアル検証

### 実行フロー

```
UI実装完了 → dev server起動 → Playwrightスクリーンショット撮影
  → Claude が /tmp/ui-visual-check/*.png を Read で読み込み
  → 5観点で視覚評価（視覚的階層/余白/色/タイポグラフィ/アライメント）
  → 問題あり → 修正 → 再撮影（最大3回） → 品質OK → 完了
```

テンプレート: `~/.claude/templates/ui-themes/playwright-visual-check.ts`

### 前提条件

- dev server起動（デフォルト: `http://localhost:3000`）
- 異なるポート: `BASE_URL=http://localhost:5173 npx tsx ...`
- `npx playwright install chromium`（初回のみ）

---

## 参考リンク

- [ui-skills](https://github.com/ibelick/ui-skills)
- [Base UI](https://base-ui.com/)
- [React Aria](https://react-spectrum.adobe.com/react-aria/)
- [Radix UI](https://www.radix-ui.com/)
- [motion/react](https://motion.dev/)
