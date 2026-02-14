---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
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

フレームワーク検出 → テーマファイル適用は `ui-skills` スキルの「フレームワーク自動検出」「テーマファイルの適用」に従う。

**注意**: カスタムテーマが既にある場合はAskUserQuestionで上書き確認。

#### 適用後の提案

AskUserQuestionで次のアクション提案:

```
question: "テーマを適用しました。次は？"
options:
  - "このままUI実装に進む"
  - "ビジュアル検証（スクショで確認）"
  - "完了"
```

### Step 4: Playwrightビジュアル検証

`ui-skills` スキルの「Playwrightビジュアル検証」セクションに従って実行。

異なるポートの場合はAskUserQuestionで確認してから実行:

```bash
# デフォルト
npx tsx ~/.claude/templates/ui-themes/playwright-visual-check.ts

# カスタムポート
BASE_URL=http://localhost:5173 npx tsx ~/.claude/templates/ui-themes/playwright-visual-check.ts
```

前提条件:
- dev server起動中であること
- `npx playwright install chromium`（初回のみ）

### Step 5: UI実装

テーマ適用後のUI実装では `ui-skills` スキルの「ダッシュボード設計パターン」に従う（3層構造、グリッド強弱、色の節約等）。

## 依存スキル

- `ui-skills`: Tailwind CSS/motion/react構築制約
- `load-guidelines`: tailwind, shadcn ガイドライン自動読み込み

## 注意事項

- 3回修正しても改善しない場合はユーザーに相談
