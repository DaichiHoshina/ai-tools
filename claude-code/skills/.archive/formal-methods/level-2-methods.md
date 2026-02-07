# 形式手法 - Level 2 Methods

> **基本パターンと検証方法**

---

## 🎯 TLA+による並行処理検証

### 基本構造

```tla
---- MODULE BankAccount ----
EXTENDS Integers

VARIABLES balance

Init == balance = 0

Deposit(amount) ==
  /\ amount > 0
  /\ balance' = balance + amount

Withdraw(amount) ==
  /\ amount > 0
  /\ balance >= amount
  /\ balance' = balance - amount

Next ==
  \/ \E amount \in 1..100: Deposit(amount)
  \/ \E amount \in 1..100: Withdraw(amount)

TypeInvariant == balance \in Nat

Spec == Init /\ [][Next]_balance /\ TypeInvariant
====
```

### 検証項目

1. **Safety(安全性)**: 悪いことが起きない
   - `balance >= 0` が常に成立

2. **Liveness(活性)**: 良いことがいつか起きる
   - リクエストはいつか処理される

3. **Invariant(不変条件)**: 常に成立する条件
   - 型制約、ビジネスルール

---

## 🔍 Alloyによるモデル検証

### データモデル例

```alloy
sig User {
  friends: set User
}

// 対称性: A が B の友達なら B も A の友達
fact Symmetric {
  all u1, u2: User | u2 in u1.friends implies u1 in u2.friends
}

// 非再帰性: 自分自身は友達でない
fact NoSelfFriend {
  all u: User | u not in u.friends
}

// 検証: 3人以上の友達グループが存在するか
pred hasGroup3 {
  some disj u1, u2, u3: User |
    u2 in u1.friends and u3 in u1.friends and u3 in u2.friends
}

run hasGroup3 for 5
```

---

## 📊 適用パターン

### パターン1: 分散ロック
```
状態:
  - Free
  - Locked(owner)

遷移:
  - Acquire: Free → Locked
  - Release: Locked → Free

検証:
  - 複数同時ロック不可
  - デッドロック検出
```

### パターン2: 2フェーズコミット
```
状態:
  - Prepare
  - Commit
  - Abort

検証:
  - 全ノードが Commit or 全ノードが Abort
  - 一部だけ Commit は発生しない
```

### パターン3: リーダー選出
```
検証:
  - リーダーは常に1人
  - ネットワーク分断時の挙動
```

---

## 🚀 実践ワークフロー

```
1. 仕様記述
   └─ TLA+/Alloyでモデル化

2. 不変条件定義
   └─ 守るべき性質を記述

3. モデル検証
   └─ TLC/Alloy Analyzerで実行

4. 反例分析
   └─ 違反が見つかったら修正

5. 実装
   └─ 検証済みモデルから実装
```

---

詳細例: level-3-full-docs.md
