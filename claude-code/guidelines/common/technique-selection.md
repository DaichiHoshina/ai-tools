# テクニック自動選択(Technique Auto-Selection)

> **目的**: タスクの特性に応じて最適なテクニックを自動選択

---

## タスク分類(4次元)

| 次元 | 値 |
|------|---|
| 目的(Purpose) | CRUD / Logic / Concurrency / Security / Performance |
| 複雑さ(Complexity) | 1-10 |
| 難しさ(Difficulty) | 1-10 |
| 量(Volume) | Small / Medium / Large |

---

## テクニック選択マトリクス

| テクニック | 適用条件 | 効果 | トークンコスト |
|-----------|---------|------|-------------|
| **Result/Either型** | 常時必須 | 型安全なエラーハンドリング | +500 |
| **CQS** | 常時必須 | 副作用の明示化 | +200 |
| **純粋関数** | Logic OR difficulty ≥ 4 | テスト容易性、参照透明性 | +400 |
| **イミュータビリティ** | Concurrency OR complexity ≥ 5 OR volume != Small | 競合状態排除 | +300 |
| **プロパティベーステスト** | difficulty ≥ 5 OR complexity ≥ 6 OR Logic | エッジケース自動発見 | +800 |
| **状態機械** | Logic OR (complexity ≥ 6 AND CRUD) | 状態遷移の型安全性 | +700 |
| **契約プログラミング** | difficulty ≥ 6 OR Security OR complexity ≥ 7 | 事前・事後条件明示 | +600 |
| **DDD戦術的パターン** | complexity ≥ 7 OR volume == Large OR (Logic AND difficulty ≥ 6) | ドメインロジック整理 | +1.5K |
| **圏論** | complexity ≥ 7 OR (Logic AND difficulty ≥ 6) | 抽象化・合成可能性 | +2K |
| **形式手法** | Concurrency OR (Security AND difficulty ≥ 8) OR complexity ≥ 9 | 並行処理の正しさ検証 | +1K |

### プロパティベーステストライブラリ
- TypeScript: fast-check / Python: hypothesis / Go: gopter

### 形式手法ツール
- TLA+: 分散システム / Alloy: データモデル検証

---

## 自動選択ロジック

**Step 1: 必須テクニック追加**
- Result/Either型、CQSは常に選択

**Step 2: complexity基準**
```
≥ 9 → 形式手法
≥ 7 → 圏論、DDD戦術的パターン
≥ 6 → プロパティベーステスト、状態機械
≥ 5 → イミュータビリティ
```

**Step 3: difficulty基準**
```
≥ 8 → 形式手法
≥ 6 → 圏論、契約プログラミング
≥ 5 → プロパティベーステスト
≥ 4 → 純粋関数
```

**Step 4: purpose基準**
```
Concurrency → 形式手法、イミュータビリティ
Security    → 契約プログラミング
Logic       → プロパティベーステスト、純粋関数、状態機械、DDD
```

**Step 5: volume基準**
```
Large → DDD戦術的パターン
```

**Step 6: 重複削除、トークン予算(10K)確認**
- 超過時は効果/コスト比で優先度順に削減

---

## 選択例

### シンプルなCRUD API
```
purpose: CRUD / complexity: 3 / difficulty: 2 / volume: Small
選択: Result/Either型 + CQS
コスト: 700
```

### 決済処理システム
```
purpose: Logic, Security / complexity: 8 / difficulty: 7 / volume: Medium
選択: Result/Either型 + CQS + 圏論 + DDD + プロパティベーステスト
     + 状態機械 + 契約プログラミング + イミュータビリティ + 純粋関数
コスト: 6.6K
```

### 分散トランザクション
```
purpose: Concurrency, Logic / complexity: 10 / difficulty: 9 / volume: Large
選択: 全テクニック
コスト: 8.5K(予算内)
```

---

## Progressive Disclosure統合

| Level | 内容 |
|-------|------|
| 1 | タスク特性を自動分析、適用テクニック一覧を生成 |
| 2 | 選択されたテクニックの概要のみロード |
| 3 | 実装中に詳細が必要になった時のみロード |

---

**タスク特性を分析し、最適なテクニックを自動選択。数学的に正しく、効率的なコードを生産。**
