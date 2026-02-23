---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: UI統合コマンド - テーマ・実装・レビュー・パフォーマンス・検証・監査を1コマンドで
---

# /ui - UI統合コマンド

全UI操作の単一入口。引数に応じて適切なスキルにルーティングする。

## ルーティング

### `$ARGUMENTS` ありの場合 → キーワード自動判定

引数のキーワードからアクションを判定する。

| キーワード | アクション |
|-----------|-----------|
| theme, テーマ, color | テーマ適用 |
| implement, build, create, 実装, page, component | UI実装 |
| review, check, レビュー, a11y, ui-review | UI/UXレビュー（※`/review`はコードレビュー、こちらはUI特化） |
| performance, perf, bundle, パフォーマンス | パフォーマンスレビュー |
| screenshot, verify, visual, スクショ | ビジュアル検証 |
| fix, ugly, improve, broken, 修正, 改善, ダサい | フルUI監査 |

判定不能の場合 → AskUserQuestionで6択を提示（下記と同じ）。

### `$ARGUMENTS` なしの場合 → AskUserQuestion

```yaml
question: "何をしますか？"
header: "UIアクション"
options:
  - label: "テーマ適用"
    description: "デザインテーマを選択・適用する"
  - label: "UI実装"
    description: "コンポーネント/ページを構築する"
  - label: "UI/UXレビュー"
    description: "MD3/WCAG/Nielsen原則でレビュー"
  - label: "パフォーマンスレビュー"
    description: "React/Next.jsパフォーマンスを診断"
```

1問目で「Other」が選ばれた場合のみ、2問目を表示:

```yaml
question: "他のアクションを選択してください"
header: "UIアクション"
options:
  - label: "ビジュアル検証"
    description: "Playwrightでスクショ撮影・確認"
  - label: "フルUI監査"
    description: "レビュー→パフォ→検証→修正を一括実行"
```

**注**: AskUserQuestionは最大4選択肢のため、利用頻度の高い4つを1問目に配置。ビジュアル検証・フルUI監査は「Other」経由で2問目に表示される。`$ARGUMENTS` でキーワード指定すれば2問目のアクションも直接実行可能。

## アクション詳細

### 1. テーマ適用

`ui-skills` スキルに委譲。

AskUserQuestionでテーマ選択:

```yaml
question: "どのテーマを使いますか？"
header: "テーマ"
options:
  - label: "Corporate（Linear/Stripe風）"
    description: "業務系ダッシュボード、管理画面向け。Indigo基調、控えめなradius。"
  - label: "Modern Dark（Raycast/Vercel風）"
    description: "データ分析、モニタリング向け。Cyan基調、タイトなスペーシング。"
  - label: "Soft（Notion/Loom風）"
    description: "チームツール、SaaS向け。Violet基調、大きめのradius。"
```

フレームワーク検出 → テーマファイル適用は `ui-skills` スキルの「フレームワーク自動検出」「テーマファイルの適用」に従う。

カスタムテーマが既にある場合はAskUserQuestionで上書き確認。

適用後、AskUserQuestionで次ステップ（UI実装/ビジュアル検証/完了）を確認。

### 2. UI実装

`ui-skills` スキルに委譲。

テーマ適用後のUI実装では `ui-skills` スキルの「ダッシュボード設計パターン」に従う（3層構造、グリッド強弱、色の節約等）。

### 3. UI/UXレビュー

`uiux-review` スキルに委譲。対象不明時はAskUserQuestionで確認。
観点: MD3 / WCAG 2.2 AA / Nielsen 10原則

### 4. パフォーマンスレビュー

`react-best-practices` スキルに委譲。非Reactの場合はスキップ。
観点: ウォーターフォール排除 / バンドル最適化 / Server-Client分離 / 再レンダリング最適化

### 5. ビジュアル検証

`ui-skills` スキルの「Playwrightビジュアル検証」に従う。前提: dev server起動中、`npx playwright install chromium`済み。カスタムポートは `BASE_URL=http://localhost:5173` で指定。

### 6. フルUI監査

全スキルを順次実行し、統合レポートを作成する。

```
Step 1: uiux-review → MD3/WCAG/Nielsen観点でレビュー
Step 2: react-best-practices → パフォーマンス診断（React時のみ）
Step 3: Playwright → ビジュアル検証（dev server起動中の場合）
Step 4: 統合レポート提示（問題一覧 + 優先度）
Step 5: AskUserQuestion → 修正するか確認
Step 6: ui-skills で修正実行（ユーザー承認後）
```

## 依存スキル

| スキル | 用途 |
|--------|------|
| `ui-skills` | テーマ適用、UI実装、ビジュアル検証 |
| `uiux-review` | UI/UXレビュー（MD3/WCAG/Nielsen） |
| `react-best-practices` | Reactパフォーマンスレビュー |
| `load-guidelines` | tailwind, shadcn ガイドライン自動読み込み |

## 注意事項

- 3回修正しても改善しない場合はユーザーに相談
- フルUI監査は各ステップの結果を確認してから次に進む
- `/review`や`/flow`の既存UI動線はそのまま維持（`/ui`は追加の統合入口）
