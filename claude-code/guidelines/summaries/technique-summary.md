# テクニック選択サマリー

> **タスク特性に応じた自動テクニック選択の概要**

---

## 🎯 4次元分析

```
1. 目的(Purpose): CRUD, Logic, Concurrency, Security, Performance
2. 複雑さ(Complexity): 1-10
3. 難しさ(Difficulty): 1-10
4. 量(Volume): Small, Medium, Large
```

---

## 📊 選択マトリクス(簡易版)

### 必須(ALWAYS)
- **Result/Either型**: 型安全なエラーハンドリング
- **CQS**: コマンドクエリ分離

### complexity >= 9
- **形式手法**: TLA+/Alloy検証

### complexity >= 7
- **圏論**: 抽象化と合成
- **DDD戦術的パターン**: ドメインロジック整理

### complexity >= 6
- **プロパティベーステスト**: エッジケース発見
- **状態機械**: 型安全な状態遷移

### complexity >= 5
- **イミュータビリティ**: 競合状態の排除

### difficulty >= 6
- **契約プログラミング**: 事前・事後条件

### difficulty >= 4
- **純粋関数**: 副作用の排除

### purpose includes Concurrency
- **形式手法**: デッドロック検出
- **イミュータビリティ**: 競合状態の排除

### purpose includes Security
- **契約プログラミング**: 不変条件の保証

### purpose includes Logic
- **プロパティベーステスト**: 仕様の形式化
- **純粋関数**: 参照透明性
- **状態機械**: ビジネスフロー可視化
- **DDD戦術的パターン**: ビジネスルール表現

### volume == Large
- **DDD戦術的パターン**: 境界の明確化

---

## 📋 選択例

### シンプルなCRUD (complexity 3)
```
選択: Result型, CQS
コスト: 700トークン
```

### 決済処理 (complexity 8, Security)
```
選択: Result型, CQS, 圏論, DDD, プロパティテスト,
      状態機械, 契約プログラミング, イミュータビリティ, 純粋関数
コスト: 6.6Kトークン
```

### 分散システム (complexity 10, Concurrency)
```
選択: 上記 + 形式手法
コスト: 8.5Kトークン
```

---

## 🔗 詳細

- **完全版**: guidelines/common/technique-selection.md
- **関数型**: guidelines/common/functional-programming.md

---

タスクに応じて最適なテクニックを自動選択し、効率的に高品質コードを生産。
