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
    values: [all, architecture, quality, readability, security, docs, test-coverage, root-cause, logging, writing]
    default: all
    description: レビュー観点のフォーカス
---

# comprehensive-review - 包括的コードレビュー

## 9つの観点

1. **architecture** - クリーンアーキテクチャ、DDD、レイヤー違反
2. **quality** - コード臭、パフォーマンス、型安全性
3. **readability** - 命名、認知的複雑度、一貫性
4. **security** - OWASP Top 10、機密情報漏洩
5. **docs** - ドキュメント品質（テストファイル等の補助ドキュメント）
6. **test-coverage** - テストケースの充足度
7. **root-cause** - 対症療法vs根本治療
8. **logging** - ログレベル適切性、構造化ログ
9. **writing** - ヒト向けドキュメント（md / Notion / PR description / PRD / Design Doc）の文章品質

## パラメータ

`--focus`で観点を絞る（デフォルト: all）:

| 値 | レビュー範囲 |
|----|-------------|
| all | 全8観点（デフォルト） |
| architecture | 設計のみ |
| quality | 品質のみ |
| readability | 可読性のみ |
| security | セキュリティのみ |
| docs | ドキュメントのみ |
| test-coverage | テスト充足度のみ |
| root-cause | 恒久対応のみ |
| logging | ログのみ |
| writing | ヒト向けドキュメントの文章品質のみ |

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

focusパラメータで指定された観点のみ実行。`all`の場合は全8観点を並列実行。

**test-coverage観点のチェック項目**:

| チェック | 内容 |
|---------|------|
| **テスト有無** | 変更したロジックに対応するテストファイルが存在するか |
| **新規コードのテスト** | 新しい関数・メソッド・エンドポイントにテストがあるか |
| **バグ修正の回帰テスト** | 修正したバグの再発を防ぐテストケースがあるか |
| **境界値・異常系** | 正常系だけでなくエラーケース・境界値がカバーされているか |
| **テストの質** | テストが実装の詳細でなく振る舞いを検証しているか |

**writing観点のチェック項目**（`guidelines/common/user-voice.md` 準拠）:

対象ファイル: md（Design Doc、README、ADR、調査レポート）、Notion 投稿下書き、PR description、PRD。コード・コードコメントは対象外（コードは `readability` focus で扱う）。

| チェック | NG 例 | Critical / Warning |
|---------|-------|-------------------|
| **結論先行** | 「本稿では〜について説明します」導入、数段落後に結論 | Warning |
| **根拠なき評価語** | 「適切な」「最適な」「重要」「必須」「推奨」を根拠1文なしで使用 | Critical（1箇所でもあれば） |
| **抽象語の放置** | 「改善」「最適化」「効率化」「強化」に数字 or 事例が隣接していない | Critical |
| **難語の未定義** | 初出の idempotency / Saga / RLS / CQRS 等を定義併記なしで使用 | Warning |
| **主語の省略** | 誰が・何がが不明な文（「対応しました」「実施する」） | Warning |
| **5W1H 欠落** | When / Where / Who が不明な決定記述 | Warning |
| **箇条書き金太郎飴** | 3項目以上の bullet の前後に地の文が1文もない | Warning |
| **AI 定型語** | 「効果的に」「シームレスに」「〜を実現します」等、user-voice.md NG辞書ヒット | Warning |
| **読後アクション未明示** | 末尾に「レビュワーは X を確認」「次は Y を実行」が無い | Warning |

**Critical / Warning の扱い**:
- Critical: 1箇所でもあれば書き直し必須
- Warning: 3箇所以下なら修正推奨、4箇所以上で書き直し必須

**出力例**:
```
🔴 Critical: [writing] 根拠なき「必須」使用（docs/design/oripa.md:45）
修正案: 「SET LOCAL 必須」→ 「SET LOCAL 必須。session-scoped の SET は connection pool で次 request に tenant が漏洩するため」
```

**ファイル種別による自動追加**:

| 条件 | 追加観点 |
|------|---------|
| テストファイル（`*_test.*`, `*.spec.*`） | `docs` |
| UIファイル（`components/*`, `*.tsx`） | `uiux-review`（別スキル） |
| ロジック変更（テストファイル以外の`.go`, `.ts`, `.py`） | `test-coverage` |

### Step 5: 結果集約

## 出力形式

```markdown
## 包括的レビュー結果

### 実行した観点
- architecture / quality / readability / security / docs / test-coverage / root-cause / logging

### Critical（修正必須）
- [設計] Domain→Infrastructure参照（src/domain/user.ts:45）
- [セキュリティ] SQLインジェクション脆弱性（src/api/user.ts:120）

### Warning（要改善）
- [品質] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）

Total: Critical N件 / Warning N件
```

## コメント添字

レビューコメントには添字を付ける:

| 添字 | 意味 | 対応 |
|------|------|------|
| `must` | 修正必須 | Critical扱い |
| `imo` | 提案（任意） | Warning扱い |
| `nits` | 細かい指摘 | Warning扱い |
| `q` | 質問 | 情報提供 |

## 注意事項

- 大量の差分 → 1ファイルずつ、Critical → Warningの優先度順
- 問題指摘だけでなく具体的な修正案を提示
- focus=allの場合は全8観点を並列実行
