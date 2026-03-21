# UIデザインシステム - テーマ

## テーマプリセット

| プリセット | 雰囲気 | 用途 | radius |
|-----------|--------|------|--------|
| **corporate** | 洗練・信頼・クリーン | 業務系ダッシュボード、管理画面 | 0.5rem |
| **modern-dark** | ダーク・シャープ・技術的 | データ分析、モニタリング、開発ツール | 0.375rem |
| **soft** | 柔らかい・親しみやすい | チームツール、SaaS、社内ツール | 0.75rem |

## テンプレート（フレームワーク別）

| フレームワーク | パス | 形式 |
|--------------|------|------|
| **shadcn/ui** | `~/.claude/templates/ui-themes/shadcn/` | oklch CSS variables + @theme inline |
| **Tailwind CSS / vanilla CSS** | `~/.claude/templates/ui-themes/tailwind/` | CSS Custom Properties |
| **任意（トークン参照）** | `~/.claude/templates/ui-themes/tokens/` | JSON design tokens |

## フレームワーク自動検出

```text
UI実装リクエスト検出時:
1. globals.css等にCSS変数定義あり → そのまま使用
2. テーマなし → フレームワーク検出（上から順に判定）:
   a. components.json あり → shadcn/ui → ui-themes/shadcn/から適用
   b. tailwind.config.{js,ts,mjs} あり → ui-themes/tailwind/から適用
   c. いずれにも該当しない → ui-themes/tokens/のJSONを参照
3. AskUserQuestionでプリセット選択（または自動判定）
4. テーマファイルの適用:
   - shadcn → app/globals.cssに上書き
   - tailwind → src/styles/theme.cssとして作成しglobals.cssで@import
   - tokens → JSONを参照してプロジェクトのCSS変数に手動変換
```

## テーマ自動判定ロジック

ユーザーがテーマを選ばない場合:

| 判定条件 | テーマ |
|---------|--------|
| 「経営」「業務」「管理」「レポート」「営業」 | corporate |
| 「モニタリング」「分析」「ログ」「メトリクス」「API」「開発」 | modern-dark |
| 「チーム」「社内」「タスク」「プロジェクト」「コラボ」 | soft |
| 判定不能 | corporate（最も汎用的） |

## デザインブリーフ（--detailedオプション時）

| # | 要素 | 質問例 |
|---|------|--------|
| 1 | 情報優先度 | 画面で最も重要な情報は? |
| 2 | レイアウト密度 | データ密度は高い? 余白重視? |
| 3 | トーン | フォーマル? カジュアル? |
| 4 | カラーアクセント | ブランドカラーは? |
| 5 | 参考デザイン | 近いイメージは?（Linear風、Vercel風等） |
