# Playwrightビジュアル検証

## 実行フロー

```text
UI実装完了 → dev server起動 → Playwrightスクリーンショット撮影
  → Claudeが /tmp/ui-visual-check/*.png をReadで読み込み
  → 5観点で視覚評価（視覚的階層/余白/色/タイポグラフィ/アライメント）
  → 問題あり → 修正 → 再撮影（最大3回） → 品質OK → 完了
```

テンプレート: `~/.claude/templates/ui-themes/playwright-visual-check.ts`

## 前提条件

- dev server起動（デフォルト: `http://localhost:3000`）
- 異なるポート: `BASE_URL=http://localhost:5173 npx tsx ...`
- `npx playwright install chromium`（初回のみ）
