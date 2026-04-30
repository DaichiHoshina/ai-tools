---
name: comprehensive-review
description: 包括的コードレビュー - 設計・品質・可読性・セキュリティ・ドキュメント・テスト充足度・恒久対応・ログを統合評価。/reviewコマンドで自動選択。--focusで観点を絞れる。
context: fork
agent: reviewer-agent
requires-guidelines:
  - common
  - clean-architecture
  - domain-driven-design
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs, test-coverage, root-cause, logging, writing, silent-failure, type-design]
    default: all
    description: レビュー観点のフォーカス
---

# comprehensive-review - 包括的コードレビュー

## 11の観点

| 観点 | 説明 | 詳細 |
|------|------|------|
| **architecture** | クリーンアーキテクチャ、DDD、レイヤー違反 | `review-criteria.md` |
| **quality** | コード臭、パフォーマンス、型安全性 | `review-criteria.md` |
| **readability** | 命名、認知的複雑度、一貫性 | `review-criteria.md` |
| **security** | OWASP Top 10、機密情報漏洩 | `review-criteria.md` |
| **docs** | ドキュメント品質、テスト充足度 | `review-criteria.md` |
| **test-coverage** | テストケースの充足度、質 | `review-criteria.md` |
| **root-cause** | 対症療法vs根本治療、再発パターン | `review-criteria.md` |
| **logging** | ログレベル適切性、構造化ログ | `review-criteria.md` |
| **writing** | ヒト向けドキュメント文章品質 | `writing-docs.md` |
| **silent-failure** | エラー握りつぶし、空 catch | `silent-failure.md` |
| **type-design** | 型による不変条件表現、enum乱用回避 | `type-design.md` |

## パラメータ

`--focus`で観点を絞る（デフォルト: all）。各値で対応する観点のみ実行。

| 値 | 実行観点 |
|---|---------|
| all | 全11観点（デフォルト） |
| architecture / quality / readability / security | 各単一観点 |
| docs / test-coverage / root-cause / logging | 各単一観点 |
| writing / silent-failure / type-design | 各単一観点 |

## Effort 連動モード（`${CLAUDE_EFFORT}`）

実行時の effort level で信頼度閾値と検査範囲が変動。

| effort | Critical 閾値 | 履歴確認 | 観点制御 |
|--------|---------------|---------|---------|
| `low` | 90+（false positive 極小化） | スキップ | writing / type-design / docs 省略 |
| `medium`（既定） | 80+ | 過去90日 | 全11観点 |
| `high` | 70+（過検出寄り） | 全履歴 | + 設計トレードオフ・前提依存 |

`${CLAUDE_EFFORT}` が未展開の場合は `medium` 扱い。

## 実行フロー

### Step 0: 履歴ロード（繰り返し指摘の検出）

リポジトリの `.claude/review-history.jsonl` を読み、同一 `file:line±3行` + 同一 `focus` の指摘が **過去履歴に3回以上** ある場合、`🔁 繰り返し指摘（Nth時）` と prefix（チームレベルの問題示唆）。

### Step 1: 変更ファイル分析

`git diff --name-only`で言語・ファイル種別・変更規模を判断し、自動追加観点を決定。

| 条件 | 追加観点 |
|------|---------|
| テストファイル（`*_test.*`, `*.spec.*`） | `docs` |
| UIファイル（`components/*`, `*.tsx`） | `uiux-review`（別スキル） |
| ロジック変更（テストファイル以外） | `test-coverage` + `silent-failure` |
| 型定義変更（`*.d.ts`, `types/*`, struct/interface追加） | `type-design` |

### Step 2: 静的解析ツール実行

```bash
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...
```

### Step 3: cleanup-enforcement確認

未使用import/変数/関数、後方互換残骸、進捗コメントを確認。

### Step 4: 信頼度スコアリング（ノイズ除去）

各 finding に 0-100 の信頼度スコアを付与し、低スコア指摘を降格・破棄。

**フィルタリング規則（medium既定値）**:

| スコア帯 | 扱い |
|---------|------|
| 80以上（low 90+、high 70+） | Critical のまま出力 |
| 50-79 | Warning に降格 |
| 25-49 | Warning のまま出力 |
| 25未満 | 破棄（出力しない） |

### Step 5-6: 結果集約・履歴記録

確定した Critical / Warning（信頼度25以上）を `.claude/review-history.jsonl` に追記。

```json
{"date":"2026-04-27","severity":"Critical","focus":"security","file":"src/api/user.ts","line":120,"finding":"SQLi","confidence":95,"branch":"feat/x","commit":"abc1234"}
```

## 出力形式

```markdown
## 包括的レビュー結果

### 実行した観点
- architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design

### Critical（修正必須・信頼度80以上）
- [security] SQLインジェクション脆弱性（src/api/user.ts:120）信頼度95
- 🔁 繰り返し指摘（4th時）: [architecture] Domain→Infrastructure参照（src/domain/user.ts:45）信頼度85

### Warning（要改善・信頼度25-79）
- [quality] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）信頼度65

Total: Critical N件 / Warning N件 / 破棄M件 / 🔁 繰り返しK件
```

## コメント添字

| 添字 | 意味 | 扱い |
|------|------|------|
| `must` | 修正必須 | Critical |
| `imo` | 提案（任意） | Warning |
| `nits` | 細かい指摘 | Warning |
| `q` | 質問 | 情報提供 |

## 注意事項

- focus=all の場合は全11観点を並列実行
- 大量の差分 → 1ファイルずつ、Critical優先
- 問題指摘だけでなく具体的な修正案を提示
