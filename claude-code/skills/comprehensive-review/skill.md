---
name: comprehensive-review
description: 包括的コードレビュー - 設計・品質・可読性・セキュリティ・ドキュメント/テスト・恒久対応・ログを統合評価。/reviewコマンドで自動選択。--focusで観点を絞れる。
context: fork
agent: reviewer-agent
requires-guidelines:
  - common
  - clean-architecture
  - domain-driven-design
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs, root-cause, logging]
    default: all
    description: レビュー観点のフォーカス
---

# comprehensive-review - 包括的コードレビュー

## 7つの観点

1. **architecture** - クリーンアーキテクチャ、DDD、レイヤー違反
2. **quality** - コード臭、パフォーマンス、型安全性
3. **readability** - 命名、認知的複雑度、一貫性
4. **security** - OWASP Top 10、機密情報漏洩
5. **docs** - ドキュメント品質、テスト品質
6. **root-cause** - 対症療法vs根本治療
7. **logging** - ログレベル適切性、構造化ログ

各観点の詳細チェック項目: [references/review-criteria.md](references/review-criteria.md)

## パラメータ

`--focus`で観点を絞る（デフォルト: all）:

| 値 | レビュー範囲 |
|----|-------------|
| all | 全7観点（デフォルト） |
| architecture | 設計のみ |
| quality | 品質のみ |
| readability | 可読性のみ |
| security | セキュリティのみ |
| docs | ドキュメント/テストのみ |
| root-cause | 恒久対応のみ |
| logging | ログのみ |

## 実行フロー

### Step 1: 変更ファイル分析

`git diff --name-only`で言語・ファイル種別・変更規模を判断。

### Step 2: 静的解析ツール実行（必須）

```bash
# TypeScript
npm run lint 2>&1 | head -50
npx tsc --noEmit 2>&1 | head -50

# Go
golangci-lint run 2>&1 | head -50
go vet ./... 2>&1 | head -50
```

### Step 3: cleanup-enforcement確認

未使用import/変数/関数、後方互換残骸、進捗コメントを確認。

### Step 4: レビュー観点の選択と実行

focusパラメータで指定された観点のみ実行。`all`の場合は全7観点を並列実行。

**ファイル種別による自動追加**:

| 条件 | 追加観点 |
|------|---------|
| テストファイル（`*_test.*`, `*.spec.*`） | `docs` |
| UIファイル（`components/*`, `*.tsx`） | `uiux-review`（別スキル） |

### Step 5: 結果集約

## 出力形式

```markdown
## 包括的レビュー結果

### 実行した観点
- architecture / quality / readability / security / docs / root-cause / logging

### Critical（修正必須）
- [設計] Domain→Infrastructure参照（src/domain/user.ts:45）
- [セキュリティ] SQLインジェクション脆弱性（src/api/user.ts:120）

### Warning（要改善）
- [品質] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）

Total: Critical N件 / Warning N件
```

## 注意事項

- 大量の差分 → 1ファイルずつ、Critical → Warningの優先度順
- 問題指摘だけでなく具体的な修正案を提示
- focus=allの場合は全7観点を並列実行
