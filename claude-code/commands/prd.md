---
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Task, mcp__serena__read_file, mcp__serena__list_dir, mcp__serena__find_file, mcp__serena__search_for_pattern, mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__list_memories, mcp__serena__read_memory, mcp__context7__resolve-library-id, mcp__context7__get-library-docs, mcp__confluence__conf_get, mcp__jira__jira_get_issue, mcp__jira__jira_search_issues
description: PRD作成 - 対話式で要件整理、数学的定式化（オプション）、10の専門家視点で厳格レビュー
---

# /prd - 要件定義・PRD作成コマンド

## 目的

複雑な要件（マイクロサービス連携、外部API考慮）を整理し、あらゆる角度から抜け漏れを検出する。

## 実行フロー

### Phase 1: 情報収集（対話式）

AskUserQuestion を使用して段階的に情報を収集する。

**Step 1: 概要**
```
質問: 何を実現したいですか？
- 目的・背景
- 解決したい課題
```

**Step 2: 関連サービス**
```
質問: どのサービスが関係しますか？（複数選択可）
- 既存サービス一覧を提示
- 新規サービス追加も可
- 各サービスの役割を確認
```

**Step 3: 外部API・依存**
```
質問: 外部APIや外部サービスはありますか？
- API仕様URL → WebFetchで自動取得・要約
- 制約（レート制限、タイムアウト等）を抽出
```

**Step 4: ユーザー・権限**
```
質問: 誰が使いますか？権限は？
- ユーザーロール
- 権限マトリクス
```

**Step 5: 主要フロー**
```
質問: メインの処理フローは？
- 正常系フロー
- 入力・出力
```

### Phase 1.5: 数学的定式化（複雑な要件の場合）

複雑なドメイン（状態管理、決済、配送など）では、自然言語のままだと議論が進まない。
このフェーズで曖昧さを排除する。

**AskUserQuestion で確認**:
```
質問: 要件を数学的に定式化しますか？
- はい（状態管理が複雑、例外が多い場合に推奨）
- いいえ（単純なCRUD、UI中心の場合）
```

**「はい」の場合、以下を出力**:

#### 1.5.1 用語集（Glossary）
```markdown
| 用語 | 定義 | 型/制約 | 備考 |
|------|------|---------|------|
| 注文 | 商品購入の意思表示 | Order | Aggregate Root |
| 決済 | 金銭移動の確定 | Payment | 注文に1:1 |
```
- **5〜15語**に絞る（多すぎると使われない）
- **型を明記**（string, number, enum, Entity, ValueObject）
- **同じ概念に複数の名前を許さない**

#### 1.5.2 エンティティと属性（型付き）
```markdown
## Order（注文）
| 属性 | 型 | 必須 | 制約 |
|------|---|------|------|
| id | UUID | ✓ | 不変 |
| status | OrderStatus | ✓ | enum |
| total | Money | ✓ | > 0 |
| items | OrderItem[] | ✓ | 1件以上 |
```

#### 1.5.3 状態集合と状態遷移
```markdown
## 状態集合 S
S = { Draft, Pending, Paid, Shipped, Delivered, Cancelled }

## 状態遷移表
| 現状態 | イベント | 次状態 | 条件（Guard） |
|--------|---------|--------|--------------|
| Draft | submit() | Pending | items.length > 0 |
| Pending | pay() | Paid | payment.success |
| Pending | cancel() | Cancelled | - |
| Paid | ship() | Shipped | inventory.available |
```

#### 1.5.4 操作を関数として定義（pre/post）
```markdown
## submit: Order → Order
pre:
  - order.status == Draft
  - order.items.length > 0
  - order.total > 0
post:
  - order.status == Pending
  - OrderSubmittedEvent が発行される

## cancel: Order → Order
pre:
  - order.status ∈ { Draft, Pending }
post:
  - order.status == Cancelled
  - 在庫が戻る（Pending の場合）
```

#### 1.5.4b 操作の合成（パイプライン）
複数操作をどう連鎖させるか。合成可能性を明示する。

```markdown
| パイプライン | 定義 | 前提条件 | 備考 |
|-------------|------|---------|------|
| checkout | pay ∘ submit | Draft状態 | 検証→決済を一括 |
| fullRefund | refund ∘ cancel | Paid状態 | キャンセル→返金 |
| reorder | submit ∘ clone | Delivered状態 | 過去注文から再注文 |
```

**合成の検証**:
- `f ∘ g` が成立 → `g` の終域 = `f` の始域
- 合成不可の場合は明示（例: cancel ∘ ship は不可）

#### 1.5.5 不変条件（Invariants）
```markdown
## Order の不変条件
1. order.total == sum(order.items.map(i => i.price * i.quantity))
2. order.status が Paid 以降 → items は変更不可
3. order.items.length >= 1（空の注文は存在しない）

## システム全体の不変条件
1. Payment.success == true → Order.status ∈ { Paid, Shipped, Delivered }
2. 在庫数 >= 0（負の在庫は許容しない）
```

#### 1.5.6 例外・境界条件（反例ベース）
```markdown
| 条件 | 期待動作 | 理由 |
|------|---------|------|
| items = [] | submit() 失敗 | 空注文は無効 |
| total = 0 | submit() 失敗 | 0円注文は無効 |
| 決済タイムアウト | Pending に戻る | リトライ可能に |
| 同時に cancel() と pay() | 先勝ち（楽観ロック） | 整合性維持 |
```

#### 1.5.6b 経路独立性（整合性チェック）
異なる操作順序で同じ結果になるかを検証。順序依存の操作を明示する。

```markdown
| 経路A | 経路B | 可換？ | 理由 |
|-------|-------|--------|------|
| validate → enrich | enrich → validate | ✗ | validateが先でないとenrichでエラー |
| updateStock → notify | notify → updateStock | ✓ | 独立した操作 |
| pay → ship | ship → pay | ✗ | payが先でないと出荷不可 |
| log → save | save → log | ✓ | 順序無関係 |
```

**非可換の場合**:
- 実行順序を強制する仕組みが必要（状態マシン、Saga等）
- ドキュメントに明記

**可換の場合**:
- 並列実行可能 → パフォーマンス最適化の余地

#### 1.5.7 目的関数（最適化基準）
```markdown
最適化したい目的関数（優先順位付き）:
1. 安全性: データ整合性 > 可用性
2. 工数: MVP優先、後から拡張
3. 運用コスト: 手作業を最小化

→ これにより「やらないこと」を明確に切れる
```

#### 1.5.8 DDD マッピング（実装への橋渡し）
```markdown
| 定式化 | DDD概念 | 実装 |
|--------|---------|------|
| 不変条件 | Aggregate境界 | Order クラスのバリデーション |
| 状態遷移関数 | UseCase | OrderService.submit() |
| 制約の集合 | Policy/DomainService | PricingPolicy, InventoryPolicy |
| 状態遷移の証跡 | DomainEvent | OrderSubmittedEvent |
```

---

### Phase 2: PRD自動生成

収集情報から以下を自動構築:

```markdown
# PRD: [機能名]

## 1. 概要
- 目的:
- 背景:
- スコープ: In / Out

## 2. ユーザーストーリー
- [ロール]として、[行動]したい。なぜなら[理由]。

## 3. サービス依存関係
```mermaid
graph LR
    A[Service A] --> B[Service B]
    B --> C[External API]
```

## 4. 外部API仕様
| API | エンドポイント | 制約 |
|-----|---------------|------|
| Payment | POST /charge | 3秒タイムアウト |

## 5. 変数マトリクス
| 変数 | 型 | 発生元 | 影響先 | 必須 | 制約 |
|------|---|--------|--------|------|------|

## 6. 状態遷移
| 現状態 | イベント | 次状態 | 備考 |
|--------|---------|--------|------|

## 7. 受け入れ基準
- [ ] 基準1
- [ ] 基準2
```

### Phase 3: 多角的レビュー（10ペルソナ）

PRD生成後、以下の専門家視点で自動レビューを実行。

#### レビュアー定義

| ID | ペルソナ | 観点 | チェック項目 |
|----|---------|------|-------------|
| SEC | セキュリティエンジニア | 認証・認可・データ保護 | 認証なしAPI、個人情報露出、インジェクション、暗号化 |
| PERF | パフォーマンスエンジニア | 速度・スケール | N+1、ボトルネック、キャッシュ、同時実行数 |
| SRE | SRE/運用 | 可用性・監視・復旧 | SPOF、障害検知、ロールバック、アラート |
| QA | QAエンジニア | テスト可能性 | エッジケース、0件/大量件、境界値、再現性 |
| UX | UXデザイナー | ユーザー体験 | エラー表示、待機UI、導線、アクセシビリティ |
| DATA | データエンジニア | データ整合性 | 履歴、監査ログ、整合性、マイグレーション |
| BIZ | プロダクトオーナー | ビジネス価値 | ROI、優先度、MVP、本当に必要か |
| LEGAL | 法務/コンプライアンス | 規制・規約 | 個人情報、保持期間、同意、規約 |
| ARCH | アーキテクト | 設計・拡張性 | 依存関係、技術的負債、拡張性、一貫性 |
| EXT | 外部連携スペシャリスト | API連携 | 障害時フォールバック、リトライ、レート制限 |

#### レビュー手法

**1. 論理検証（MECE）**
```
全状態 = 状態A ∪ 状態B ∪ 状態C
状態A ∩ 状態B = ∅
→ 漏れ・重複を検出
```

**2. 状態遷移の完全性**
```
全ての (状態 × イベント) に対して次状態が定義されているか
```

**3. 条件分岐の網羅（デシジョンテーブル）**
```
全ての条件組み合わせに結果が定義されているか
```

**4. 矛盾検出**
```
ルール間の論理的矛盾がないか
```

**5. 反証質問**
```
- 〜でない場合は？
- 〜が失敗したら？
- 同時に〜したら？
- 0件/100万件だったら？
- 悪意あるユーザーなら？
```

### Phase 4: 指摘一覧の出力

重要度で分類して提示:

```markdown
## レビュー結果

### ❌ Critical（必須対応）
対応しないとリリース不可

1. [SEC] カード情報の暗号化方式が未定義
2. [ARCH] Payment Service障害時、Order Serviceがハング
3. [LEGAL] 個人情報の保持期間が未定義

### ⚠️ Warning（推奨対応）
リスクあり、対応推奨

4. [PERF] 同時100決済でDBロック競合の可能性
5. [SRE] 決済エラーのアラート閾値が未設定
6. [EXT] 外部API障害時のフォールバック未定義

### 💡 Info（検討推奨）
改善の余地あり

7. [UX] 決済処理中の待機UIが未定義
8. [DATA] 決済履歴の保持期間は？
9. [QA] 金額0円のテストケースは？
```

### Phase 5: 修正・承認

```
AskUserQuestion:
- 指摘を修正してPRD更新
- 一部承認して次へ進む
- /plan で実装計画へ
- /dev で実装開始
```

## 出力テンプレート

最終PRDは以下の形式:

```markdown
# PRD: [機能名]
作成日: YYYY-MM-DD
ステータス: Draft / Reviewed / Approved

## 1. 概要
### 1.1 目的
### 1.2 背景・課題
### 1.3 スコープ
- In:
- Out:

## 2. ユーザー
### 2.1 ターゲットユーザー
### 2.2 ユーザーストーリー
### 2.3 権限マトリクス

## 3. システム構成
### 3.1 サービス依存関係（図）
### 3.2 データフロー
### 3.3 外部API仕様

## 4. 機能要件
### 4.1 変数マトリクス
### 4.2 状態遷移
### 4.3 ビジネスルール

## 4.5 定式化（複雑な要件の場合）
### 4.5.1 用語集
### 4.5.2 エンティティと属性
### 4.5.3 状態集合と状態遷移
### 4.5.4 操作（pre/post条件）
### 4.5.4b 操作の合成（パイプライン）
### 4.5.5 不変条件
### 4.5.6 例外・境界条件
### 4.5.6b 経路独立性（整合性）
### 4.5.7 目的関数
### 4.5.8 DDDマッピング

## 5. 非機能要件
### 5.1 パフォーマンス
### 5.2 セキュリティ
### 5.3 可用性
### 5.4 監視・運用

## 6. 受け入れ基準
- [ ] 基準1
- [ ] 基準2

## 7. レビュー結果
### 7.1 Critical（対応済み）
### 7.2 Warning（対応済み/許容）
### 7.3 Info（検討結果）

## 8. 次のアクション
- [ ] /plan で実装計画
- [ ] /dev で実装開始
```

## 注意事項

- **読み取り専用**: このコマンドでは実装しない
- **外部API**: WebFetchで仕様取得可能
- **Jira/Confluence連携**: 既存チケット・ドキュメント参照可能
- **反復可能**: 指摘→修正→再レビューを繰り返せる
