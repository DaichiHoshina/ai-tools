---
name: comprehensive-review
description: 包括的コードレビュー - 設計・品質・可読性・セキュリティ・ドキュメント/テストを統合評価
requires-guidelines:
  - common
  - clean-architecture
  - domain-driven-design
  - typescript  # lang=typescript の場合
  - golang  # lang=go の場合
  - python  # lang=python の場合
  - rust  # lang=rust の場合
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs]
    default: all
    description: レビュー観点のフォーカス
---

# comprehensive-review - 包括的コードレビュー

## 概要

5つの専門レビュー観点を統合した包括的レビューを提供します：

1. **architecture（設計）** - クリーンアーキテクチャ、DDD、依存関係、レイヤー違反
2. **quality（品質）** - コード臭、パフォーマンス、型安全性、古いパターン
3. **readability（可読性）** - 命名、構造、認知的複雑度、一貫性
4. **security（セキュリティ）** - OWASP Top 10、エラーハンドリング、ログ管理
5. **docs（ドキュメント/テスト）** - ドキュメント品質、テスト品質、カバレッジ

## パラメータ

### `--focus` オプション

レビュー範囲を指定します（デフォルト: all）

```bash
/skill comprehensive-review                    # 全観点（デフォルト）
/skill comprehensive-review --focus=architecture  # 設計のみ
/skill comprehensive-review --focus=quality       # 品質のみ
/skill comprehensive-review --focus=readability   # 可読性のみ
/skill comprehensive-review --focus=security      # セキュリティのみ
/skill comprehensive-review --focus=docs          # ドキュメント/テストのみ
```

## 使用タイミング

- `/review` コマンド実行時（自動選択）
- 包括的なコードレビューが必要な時
- 特定観点に絞ったレビュー時（`--focus`指定）

---

## 実行ロジック

### Step 1: 変更ファイル分析

```bash
git diff --name-only
```

変更内容から以下を判断：
- 言語（TypeScript/Go/その他）
- ファイル種別（テスト/API/UI/ドキュメント）
- 変更規模

### Step 2: 静的解析ツール実行（必須）

レビュー前に自動検出可能な問題を洗い出す：

```bash
# TypeScript
npm run lint 2>&1 | head -50
npx tsc --noEmit 2>&1 | head -50

# Go
golangci-lint run 2>&1 | head -50
go vet ./... 2>&1 | head -50
```

### Step 3: cleanup-enforcement 確認

`cleanup-enforcement` スキルで以下を確認：
- 未使用の import/変数/関数
- 後方互換残骸（`_deprecated_*`、旧名re-export）
- 進捗コメント（「実装した」「完了」等）

### Step 4: レビュー観点の選択と実行

focus パラメータで指定された観点のみ実行。`all` の場合は全5観点を並列実行。

**ファイル種別による自動追加**:

| 条件 | 追加観点 |
|------|---------|
| テストファイル（`*_test.*`, `*.spec.*`） | `docs`（focus=allの場合） |
| ドキュメント（`README.md`, JSDoc/GoDoc変更） | `docs`（focus=allの場合） |
| UIファイル（`components/*`, `*.tsx`） | `uiux-review`（別スキル） |

### Step 5: 結果集約

**出力フォーマット**:
```markdown
## 包括的レビュー結果

### 実行した観点
- ✅ architecture（設計）
- ✅ quality（品質）
- ✅ readability（可読性）
- ✅ security（セキュリティ）
- ✅ docs（ドキュメント・テスト）

### 🔴 Critical（修正必須）
- [設計] Domain→Infrastructure参照（src/domain/user.ts:45）
- [セキュリティ] SQLインジェクション脆弱性（src/api/user.ts:120）
- [可読性] 関数名と振る舞いの不一致（src/services/user.ts:30）

### 🟡 Warning（要改善）
- [品質] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）
- [可読性] ネスト4階層、ガード節で改善可能（src/handlers/order.go:80）
- [設計] Fat Service - UserService に5つの責務（src/services/user.ts:1）

Total: Critical 3件 / Warning 3件
```

---

## レビュー観点

### 🏗️ architecture（設計） — 常にチェック

クリーンアーキテクチャ・DDDの観点でレビュー。詳細は `design/clean-architecture.md`, `design/domain-driven-design.md` 参照。

#### 🔴 Critical

| チェック項目 | 説明 |
|-------------|------|
| レイヤー違反 | Domain → Infrastructure 参照、UseCase でフレームワーク固有処理 |
| 依存方向の逆転不備 | Repository 実装に Domain が依存、DI 未使用 |
| 貫通型アクセス | Controller → DB 直接、UseCase 未経由 |
| ビジネスロジック配置ミス | Controller / Infrastructure にビジネスロジック |
| 貧血ドメインモデル | Entity が getter/setter のみでロジック不在 |
| 集約境界違反 | 集約ルート外からの直接アクセス、集約を超えたトランザクション |

#### 🟡 Warning

| チェック項目 | 説明 |
|-------------|------|
| 過剰な抽象化 | 不要なインターフェース・レイヤー |
| Fat Service | 1つのServiceに複数責務が集中 |
| ユビキタス言語不一致 | コード上の命名がドメイン用語と乖離 |
| 境界曖昧 | Bounded Context の境界が不明確 |

### 🎯 quality（品質）

#### 🔴 Critical

| チェック項目 | 説明 |
|-------------|------|
| 型安全性 | `any`使用、無検証`as`、`interface{}`（言語別ガイドライン参照） |
| パフォーマンス | N+1問題、メモリリーク |
| 古いパターン | 言語別ガイドラインの「古いパターン検出」セクション参照 |

#### 🟡 Warning

| チェック項目 | 説明 |
|-------------|------|
| コード臭 | 長い関数（100行超）、マジックナンバー |
| 非効率アルゴリズム | O(n²) で O(n) / O(n log n) が可能な場合 |
| 古いパターン（Warning級） | 言語別ガイドラインの Warning 項目 |

### 📖 readability（可読性）

#### 🔴 Critical

| チェック項目 | 説明 |
|-------------|------|
| 誤解を招く命名 | 名前と実際の振る舞いが異なる（`getUser` が副作用を持つ等） |
| 暗号的コード | 意図が読み取れない複雑なワンライナー、正規表現の説明なし |

#### 🟡 Warning

| チェック項目 | 説明 |
|-------------|------|
| 認知的複雑度 | 深いネスト（3階層超）、長い条件式、複数の早期リターンが絡むフロー |
| 命名の質 | 省略しすぎ（`usr`, `tmp`, `d`）、長すぎ、対称性の欠如（`get`/`set`等） |
| 関数の長さ・引数 | 関数50行超は分割検討、引数4個超はオブジェクト化検討 |
| 一貫性 | 同一プロジェクト内で命名規則・パターンが不統一 |
| 構造の明瞭さ | ガード節未使用（深いif-else）、否定条件の連鎖、bool引数（意味不明） |
| コメントの質 | Whatコメント（コードを繰り返すだけ）、古くなったコメント |
| **過剰な複雑性（YAGNI違反）** | 使われていない抽象化、1回だけ呼ばれるヘルパー、過剰な設定可能性、未来のための準備 |

### 🛡️ security（セキュリティ）

#### 🔴 Critical

| チェック項目 | 説明 |
|-------------|------|
| インジェクション | SQL（文字列結合）、XSS（innerHTML）、コマンドインジェクション |
| 認証不備 | パスワード平文、セッション漏洩 |
| エラー握りつぶし | 空catch、エラー無視 |
| 機密情報漏洩 | password/token/secret のログ出力 |

#### 🟡 Warning

| チェック項目 | 説明 |
|-------------|------|
| ヘッダー不足 | CSP/HSTS/X-Frame-Options |
| レート制限なし | 公開APIにスロットリング未実装 |
| リトライなし | 外部API呼び出しにリトライ・サーキットブレーカーなし |

### 📝 docs（ドキュメント・テスト）

#### 🔴 Critical

| チェック項目 | 説明 |
|-------------|------|
| 公開APIに説明なし | exported な型・関数にドキュメントなし |
| 嘘のコメント | 実装と不一致のコメント |
| **実質的検証がないテスト** | `expect(user).toBeDefined()` のみ、assertion なし、常に成功するテスト |
| 過剰なモック | 全モックで実際の動作検証なし |

#### 🟡 Warning

| チェック項目 | 説明 |
|-------------|------|
| 自明なコメント | コードを繰り返すだけ |
| テスト独立性欠如 | 共有状態、実行順序依存 |
| カバレッジ不足 | 異常系・境界値テスト欠如 |
| **冗長なテストコード** | 過剰なセットアップ、意味のない重複テスト、実装の詳細に依存しすぎたテスト |

---

## 注意事項

- 大量の差分 → 1ファイルずつ、Critical → Warning の優先度順
- 問題指摘だけでなく具体的な修正案を提示
- focus=all の場合は全5観点を並列実行
