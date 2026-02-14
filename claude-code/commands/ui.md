---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: UIテーマ適用 + Playwrightビジュアル検証を一括実行
---

# /ui - UIデザインシステム適用

対話式でテーマ選択 → 適用 → ビジュアル検証まで実行。

## 実行フロー

### Step 1: 何をする？

AskUserQuestionで確認:

```
question: "何をしますか？"
options:
  - "テーマを適用" → Step 2へ
  - "ビジュアル検証（スクショ）" → Step 4へ
  - "検証 + 自動修正" → Step 4（--fix付き）へ
```

### Step 2: テーマ選択

AskUserQuestionで選択肢を提示:

```
question: "どのテーマを使いますか？"
options:
  - "Corporate（Linear/Stripe風 - 洗練・クリーン）"
    description: "業務系ダッシュボード、管理画面、レポート向け。Indigo基調、控えめなradius。"
  - "Modern Dark（Raycast/Vercel風 - シャープ・技術的）"
    description: "データ分析、モニタリング、開発ツール向け。Cyan基調、タイトなスペーシング。"
  - "Soft（Notion/Loom風 - やさしい・親しみやすい）"
    description: "チームツール、SaaS、社内ツール向け。Violet基調、大きめのradius。"
```

### Step 3: テーマ適用

#### 3a: フレームワーク自動検出

```
プロジェクトrootに components.json あり → shadcn/ui
(a)に該当せず tailwind.config.{js,ts,mjs} あり → Tailwind CSS
いずれも該当しない → tokens（JSON参照）
```

#### 3b: テーマファイルの適用

テンプレートパス: `~/.claude/templates/ui-themes/{形式}/{テーマ名}.css`

| 検出結果 | 適用方法 |
|---------|---------|
| shadcn/ui | `ui-themes/shadcn/{theme}.css` → `app/globals.css` に上書き |
| Tailwind | `ui-themes/tailwind/{theme}.css` → `src/styles/theme.css` として作成、globals.cssで `@import` |
| tokens | `ui-themes/tokens/{theme}.json` を参照してCSS変数を定義 |

**注意**: カスタムテーマが既にある場合はAskUserQuestionで上書き確認。

#### 3c: 適用後の提案

AskUserQuestionで次のアクション提案:

```
question: "テーマを適用しました。次は？"
options:
  - "このままUI実装に進む"
  - "ビジュアル検証（スクショで確認）"
  - "完了"
```

### Step 4: Playwrightビジュアル検証

```
dev server起動確認（デフォルト: http://localhost:3000）
  ↓
異なるポートの場合はAskUserQuestionで確認
  ↓
Playwright スクリーンショット撮影
  npx tsx ~/.claude/templates/ui-themes/playwright-visual-check.ts
  ↓
/tmp/ui-visual-check/*.png を Read で読み込み
  ↓
5観点で視覚評価:
  1. 視覚的階層: KPI数値が最も目立っているか
  2. 余白バランス: 詰まりすぎ/スカスカすぎないか
  3. 色の一貫性: テーマカラーが正しく適用されているか
  4. タイポグラフィ: 見出し・本文・キャプションに明確な差があるか
  5. アライメント: 要素が整列しているか
  ↓
--fix時: 問題あり → 修正 → 再撮影（最大3回ループ）
通常時: 問題点を報告して終了
```

前提条件:
- dev server起動中であること
- `npx playwright install chromium`（初回のみ）

### Step 5: ダッシュボード実装時の自動適用ルール

テーマ適用後のUI実装では、以下を自動で守る:

- **3層構造**: Hero Metrics（text-4xl） → Trends（チャート） → Details（テーブル）
- **グリッド強弱**: 均等分割禁止、col-span-2で1つだけ強調
- **色の節約**: primaryカラーは1箇所だけ、他はmuted/secondary
- **タイポグラフィ**: 最低3段階（text-2xl → text-lg → text-sm）
- **数値表示**: `font-mono tabular-nums` 必須

## 依存スキル

- `ui-skills`: Tailwind CSS/motion/react構築制約
- `load-guidelines`: tailwind, shadcn ガイドライン自動読み込み

## 注意事項

- 3回修正しても改善しない場合はユーザーに相談
