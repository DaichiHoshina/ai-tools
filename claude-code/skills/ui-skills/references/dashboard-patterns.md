# ダッシュボード設計パターン

## 視覚的階層（最重要）

```text
NG: 全要素が同じサイズ・色・余白
OK: KPI大きく → トレンド中 → 詳細テーブル小さく
```

### 3層構造

| Layer | 役割 | スタイル |
|-------|------|---------|
| Layer 1: Hero Metrics | 最重要KPI | text-3xl/4xl + font-bold、primaryアクセント |
| Layer 2: Trends | 傾向把握 | チャート、中サイズカード |
| Layer 3: Details | 詳細データ | テーブル、text-sm、控えめスタイル |

## レイアウト原則

| 原則 | 実装 |
|------|------|
| グリッドの強弱 | `grid-cols-3`で1つだけ`col-span-2` |
| 余白のリズム | セクション間`gap-6`、カード内`p-6` |
| 色の使い分け | primaryは1箇所だけ強調、他はmuted/secondary |
| タイポグラフィ階層 | 最低3段階（h2 text-2xl / h3 text-lg / body text-sm） |
| データ表示 | 数値は`font-mono tabular-nums` |
