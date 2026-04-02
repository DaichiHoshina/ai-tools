# テクニック選択サマリー

> タスク特性に応じた自動テクニック選択。詳細: `guidelines/common/technique-selection.md`

## 4次元分析

1. 目的(Purpose): CRUD, Logic, Concurrency, Security, Performance
2. 複雑さ(Complexity): 1-10
3. 難しさ(Difficulty): 1-10
4. 量(Volume): Small, Medium, Large

## 選択マトリクス

| 条件 | テクニック |
|------|-----------|
| **ALWAYS** | Result/Either型、CQS |
| complexity >= 9 | 形式手法（TLA+/Alloy） |
| complexity >= 7 | 圏論、DDD戦術的パターン |
| complexity >= 6 | プロパティベーステスト、状態機械 |
| complexity >= 5 | イミュータビリティ |
| difficulty >= 6 | 契約プログラミング |
| difficulty >= 4 | 純粋関数 |
| Concurrency | 形式手法、イミュータビリティ |
| Security | 契約プログラミング |
| Logic | プロパティテスト、純粋関数、状態機械、DDD |
| Large | DDD戦術的パターン |
