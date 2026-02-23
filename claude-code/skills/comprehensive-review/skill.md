---
name: comprehensive-review
description: 包括的コードレビュー - 設計・品質・可読性・セキュリティ・ドキュメント/テスト・恒久対応・ログを統合評価
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

## 概要

7つの専門レビュー観点を統合した包括的レビューを提供します：

1. **architecture（設計）** - クリーンアーキテクチャ、DDD、依存関係、レイヤー違反
2. **quality（品質）** - コード臭、パフォーマンス、型安全性、古いパターン
3. **readability（可読性）** - 命名、構造、認知的複雑度、一貫性
4. **security（セキュリティ）** - OWASP Top 10、エラーハンドリング、機密情報漏洩
5. **docs（ドキュメント/テスト）** - ドキュメント品質、テスト品質、カバレッジ
6. **root-cause（恒久対応）** - 対症療法vs根本治療、パターン再発、構造的正しさ
7. **logging（ログ）** - ログレベル適切性、構造化ログ、可観測性、機密情報保護

## パラメータ

`--focus` オプションで観点を絞る（デフォルト: all）:

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

## 使用タイミング

- `/review` コマンド実行時（自動選択）
- 包括的なコードレビューが必要な時
- 特定観点に絞ったレビュー時（`--focus`指定）

---

## 実行ロジック

### Step 1: 変更ファイル分析

`git diff --name-only` で変更内容から言語・ファイル種別・変更規模を判断。

### Step 2: 静的解析ツール実行（必須）

```bash
# TypeScript
npm run lint 2>&1 | head -50
npx tsc --noEmit 2>&1 | head -50

# Go
golangci-lint run 2>&1 | head -50
go vet ./... 2>&1 | head -50
```

### Step 3: cleanup-enforcement 確認

未使用import/変数/関数、後方互換残骸、進捗コメントを確認。

### Step 4: レビュー観点の選択と実行

focus パラメータで指定された観点のみ実行。`all` の場合は全7観点を並列実行。

**ファイル種別による自動追加**:

| 条件 | 追加観点 |
|------|---------|
| テストファイル（`*_test.*`, `*.spec.*`） | `docs`（focus=allの場合） |
| ドキュメント（`README.md`, JSDoc/GoDoc変更） | `docs`（focus=allの場合） |
| UIファイル（`components/*`, `*.tsx`） | `uiux-review`（別スキル） |

### Step 5: 結果集約

```markdown
## 包括的レビュー結果

### 実行した観点
- architecture / quality / readability / security / docs / root-cause / logging

### Critical（修正必須）
- [設計] Domain→Infrastructure参照（src/domain/user.ts:45）
- [セキュリティ] SQLインジェクション脆弱性（src/api/user.ts:120）

### Warning（要改善）
- [品質] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）
- [設計] Fat Service - UserService に5つの責務

Total: Critical N件 / Warning N件
```

---

## レビュー観点

### architecture（設計）

#### Critical

| チェック項目 | 説明 |
|-------------|------|
| レイヤー違反 | Domain → Infrastructure 参照、UseCase でフレームワーク固有処理 |
| 依存方向の逆転不備 | Repository 実装に Domain が依存、DI 未使用 |
| 貫通型アクセス | Controller → DB 直接、UseCase 未経由 |
| ビジネスロジック配置ミス | Controller / Infrastructure にビジネスロジック |
| 貧血ドメインモデル | Entity が getter/setter のみでロジック不在 |
| 集約境界違反 | 集約ルート外からの直接アクセス |

#### Warning

| チェック項目 | 説明 |
|-------------|------|
| 過剰な抽象化 | 不要なインターフェース・レイヤー |
| Fat Service | 1つのServiceに複数責務が集中 |
| ユビキタス言語不一致 | コード上の命名がドメイン用語と乖離 |

### quality（品質）

#### Critical

| チェック項目 | 説明 |
|-------------|------|
| 型安全性 | `any`使用、無検証`as`、`interface{}` |
| パフォーマンス | N+1問題、メモリリーク |
| 古いパターン | 言語別ガイドラインの「古いパターン検出」参照 |

#### Warning

| チェック項目 | 説明 |
|-------------|------|
| コード臭 | 長い関数（100行超）、マジックナンバー |
| 非効率アルゴリズム | O(n²) で O(n) / O(n log n) が可能 |

### readability（可読性）

#### Critical

| チェック項目 | 説明 |
|-------------|------|
| 誤解を招く命名 | 名前と実際の振る舞いが異なる |
| 暗号的コード | 意図が読み取れない複雑なワンライナー |

#### Warning

| チェック項目 | 説明 |
|-------------|------|
| 認知的複雑度 | 深いネスト（3階層超）、長い条件式 |
| 命名の質 | 省略しすぎ（`usr`, `tmp`）、対称性の欠如 |
| 関数の長さ・引数 | 50行超は分割検討、引数4個超はオブジェクト化 |
| 一貫性 | 同一プロジェクト内で命名規則・パターンが不統一 |
| 構造の明瞭さ | ガード節未使用、否定条件の連鎖、bool引数 |
| 過剰な複雑性（YAGNI違反） | 使われていない抽象化、1回だけ呼ばれるヘルパー |

### security（セキュリティ）

#### Critical

| チェック項目 | 説明 |
|-------------|------|
| インジェクション | SQL（文字列結合）、XSS（innerHTML）、コマンドインジェクション |
| 認証不備 | パスワード平文、セッション漏洩 |
| エラー握りつぶし | 空catch、エラー無視 |
| 機密情報漏洩 | password/token/secret のログ出力 |

#### Warning

| チェック項目 | 説明 |
|-------------|------|
| ヘッダー不足 | CSP/HSTS/X-Frame-Options |
| レート制限なし | 公開APIにスロットリング未実装 |

### docs（ドキュメント・テスト）

#### Critical

| チェック項目 | 説明 |
|-------------|------|
| 公開APIに説明なし | exported な型・関数にドキュメントなし |
| 嘘のコメント | 実装と不一致のコメント |
| 実質的検証がないテスト | `expect(user).toBeDefined()` のみ、assertion なし |
| 過剰なモック | 全モックで実際の動作検証なし |

#### Warning

| チェック項目 | 説明 |
|-------------|------|
| テスト独立性欠如 | 共有状態、実行順序依存 |
| カバレッジ不足 | 異常系・境界値テスト欠如 |
| 冗長なテストコード | 過剰なセットアップ、実装の詳細に依存しすぎ |

### root-cause（恒久対応）

#### Critical

| チェック項目 | 説明 |
|-------------|------|
| 対症療法 | null check/try-catch/条件分岐で問題を隠している |
| エラー握りつぶし | エラーを無視して処理を続行（空catch、`_ = err`） |
| 同一パターン再発 | 同じ種類の問題がコードベース内の他箇所にも存在 |

#### Warning

| チェック項目 | 説明 |
|-------------|------|
| 局所的修正 | 1箇所だけ修正しているが同じパターンが3箇所以上ある |
| 構造的不整合 | 修正が既存の設計パターンと矛盾する |
| 原因未特定 | なぜ直ったか説明できない修正 |

### logging（ログ）

詳細基準はCLAUDE.mdの「ログ設計基準」参照。

#### Critical

| チェック項目 | 説明 |
|-------------|------|
| 機密情報ログ出力 | password/token/Cookie/PII生値/request body丸ごと |
| エラー情報の欠落 | エラーログにerror object/stacktraceなし |
| 非構造化ログ | 文字列結合でのログ出力（`"user " + id`等） |
| 到達不能パスのレベル不足 | switchのdefault、未対応enum値がwarn/info |

#### Warning

| チェック項目 | 説明 |
|-------------|------|
| ログレベル不適切 | 正常系にwarn/error、異常系にinfo、debug使用 |
| フォールバックのInfo降格 | 稀にしか起きない事象をinfoにしている |
| 必須フィールド欠落 | request_id/trace_id、event、duration_msが不足 |
| NotFound判断ミス | 一覧0件にwarn、ID指定NotFoundにログなし等 |
| 過剰ログ | ループ内やN+1になるログ出力 |

---

## 注意事項

- 大量の差分 → 1ファイルずつ、Critical → Warning の優先度順
- 問題指摘だけでなく具体的な修正案を提示
- focus=all の場合は全7観点を並列実行
