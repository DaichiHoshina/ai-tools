# 形式手法 - Level 3 Full Documentation

> **完全な仕様と高度なパターン**

---

## 🎓 TLA+ 完全ガイド

### 時相論理演算子

```tla
□ P  (Always P)     : P は常に成立
◇ P  (Eventually P) : P はいつか成立
P ~> Q              : P が成立したら、いつか Q が成立
```

### 分散システム例: Two-Phase Commit

```tla
---- MODULE TwoPhaseCommit ----
EXTENDS Integers, Sequences

CONSTANTS
  RM,          \* Resource Managers
  TMMAYFAIL    \* Transaction Manager may fail

VARIABLES
  rmState,     \* rmState[r] = state of resource manager r
  tmState,     \* state of transaction manager
  tmPrepared,  \* set of RMs that have prepared
  msgs         \* messages in flight

Message ==
  [type : {"Prepared"}, rm : RM]
    \cup [type : {"Commit", "Abort"}]

Init ==
  /\ rmState = [r \in RM |-> "working"]
  /\ tmState = "init"
  /\ tmPrepared = {}
  /\ msgs = {}

TMRcvPrepared(r) ==
  /\ tmState = "init"
  /\ [type |-> "Prepared", rm |-> r] \in msgs
  /\ tmPrepared' = tmPrepared \cup {r}
  /\ UNCHANGED <<rmState, tmState, msgs>>

TMCommit ==
  /\ tmState = "init"
  /\ tmPrepared = RM
  /\ tmState' = "committed"
  /\ msgs' = msgs \cup {[type |-> "Commit"]}
  /\ UNCHANGED <<rmState, tmPrepared>>

TMAbort ==
  /\ tmState = "init"
  /\ tmState' = "aborted"
  /\ msgs' = msgs \cup {[type |-> "Abort"]}
  /\ UNCHANGED <<rmState, tmPrepared>>

RMPrepare(r) ==
  /\ rmState[r] = "working"
  /\ rmState' = [rmState EXCEPT ![r] = "prepared"]
  /\ msgs' = msgs \cup {[type |-> "Prepared", rm |-> r]}
  /\ UNCHANGED <<tmState, tmPrepared>>

RMCommit(r) ==
  /\ rmState[r] = "prepared"
  /\ [type |-> "Commit"] \in msgs
  /\ rmState' = [rmState EXCEPT ![r] = "committed"]
  /\ UNCHANGED <<tmState, tmPrepared, msgs>>

RMAbort(r) ==
  /\ rmState[r] \in {"working", "prepared"}
  /\ [type |-> "Abort"] \in msgs
  /\ rmState' = [rmState EXCEPT ![r] = "aborted"]
  /\ UNCHANGED <<tmState, tmPrepared, msgs>>

Next ==
  \/ TMCommit \/ TMAbort
  \/ \E r \in RM: TMRcvPrepared(r) \/ RMPrepare(r) \/ RMCommit(r) \/ RMAbort(r)

Spec == Init /\ [][Next]_<<rmState, tmState, tmPrepared, msgs>>

\* INVARIANTS
TypeOK ==
  /\ rmState \in [RM -> {"working", "prepared", "committed", "aborted"}]
  /\ tmState \in {"init", "committed", "aborted"}
  /\ tmPrepared \subseteq RM
  /\ msgs \subseteq Message

Consistency ==
  \A r1, r2 \in RM:
    \/ rmState[r1] # "committed"
    \/ rmState[r2] # "aborted"
====
```

---

## 🔍 Alloy 完全ガイド

### 複雑なモデル例: ファイルシステム

```alloy
module filesystem

abstract sig Object {}
sig File extends Object {}
sig Dir extends Object {
  contents: set Object
}

sig FileSystem {
  root: Dir,
  live: set Object
}

// 全てのオブジェクトは root から到達可能
fact AllLiveObjectsReachable {
  all fs: FileSystem, o: Object |
    o in fs.live iff reachable[o, fs.root, contents]
}

// ディレクトリは自分自身を含まない
fact NoCycles {
  no d: Dir | d in d.^contents
}

// 各オブジェクトは最大1つの親を持つ
fact UniqueParent {
  all o: Object |
    lone d: Dir | o in d.contents
}

// 操作: ファイル作成
pred createFile[fs, fs': FileSystem, parent: Dir, f: File] {
  // 事前条件
  f not in fs.live
  parent in fs.live

  // 事後条件
  fs'.root = fs.root
  fs'.live = fs.live + f

  all d: Dir |
    d.contents' = if d = parent
                  then d.contents + f
                  else d.contents
}

// 操作: ファイル削除
pred deleteFile[fs, fs': FileSystem, f: File] {
  // 事前条件
  f in fs.live

  // 事後条件
  fs'.root = fs.root
  fs'.live = fs.live - f

  all d: Dir |
    d.contents' = d.contents - f
}

// 検証: ファイル作成後に削除可能
assert CreateThenDelete {
  all fs, fs', fs'': FileSystem, parent: Dir, f: File |
    createFile[fs, fs', parent, f] and deleteFile[fs', fs'', f]
    implies fs''.live = fs.live
}

check CreateThenDelete for 5

// 反例検索: サイクルが作成可能か
pred canCreateCycle {
  some fs, fs': FileSystem, d: Dir |
    createFile[fs, fs', d, d]  // 自分自身を追加
}

run canCreateCycle for 3  // 反例が見つかるべき(fact NoCycles により)
```

---

## 📊 高度なパターン

### パターン1: Raft コンセンサスアルゴリズム

```tla
Raft の検証項目:
  - Election Safety: 各タームで最大1人のリーダー
  - Leader Append-Only: リーダーはログを削除しない
  - Log Matching: 同じインデックスのエントリは同じ
  - Leader Completeness: コミット済みエントリは全リーダーに存在
  - State Machine Safety: 同じログインデックスに異なる値なし
```

### パターン2: Paxos

```tla
Paxos の検証項目:
  - Validity: 選ばれた値は提案された値のいずれか
  - Agreement: 2つの値が選ばれることはない
  - Progress: いつか値が選ばれる(Liveness)
```

### パターン3: CRDTs (Conflict-free Replicated Data Types)

```alloy
G-Counter (Grow-only Counter):
  - 各レプリカは独自のカウンター
  - マージは最大値を取る
  - 検証: マージは可換・結合的・冪等
```

---

## 🚀 実装への変換

### TLA+ → コード

```typescript
// TLA+ 仕様
Withdraw(amount) ==
  /\ amount > 0
  /\ balance >= amount
  /\ balance' = balance - amount

// TypeScript 実装
function withdraw(amount: number): Result<void, string> {
  // 事前条件
  if (amount <= 0) {
    return Err('Amount must be positive')
  }
  if (this.balance < amount) {
    return Err('Insufficient balance')
  }

  // 状態変更
  this.balance -= amount

  // 不変条件チェック
  if (this.balance < 0) {
    throw new Error('Invariant violated: balance < 0')
  }

  return Ok(void)
}
```

---

## 🧪 検証ツールの使用

### TLC (TLA+ Model Checker)

```bash
# モデル検証
tlc BankAccount.tla

# カバレッジ表示
tlc -coverage 1 BankAccount.tla

# 並列実行
tlc -workers 4 BankAccount.tla
```

### Alloy Analyzer

```bash
# GUI起動
java -jar alloy.jar filesystem.als

# CLI実行
java -cp alloy.jar edu.mit.csail.sdg.alloy4whole.SimpleReporter filesystem.als
```

---

## 📈 ケーススタディ

### 事例1: Amazon DynamoDB
- TLA+ で Paxos ベースのレプリケーションを検証
- 8年間で発見された重大バグ: 3件(全て修正前に発見)

### 事例2: Microsoft Azure
- TLA+ で Cosmos DB の分散トランザクションを検証
- 設計段階で 15 の重大バグを発見

### 事例3: MongoDB
- Alloy でシャーディングロジックを検証
- データ損失の可能性を事前に発見

---

## 🎯 チェックリスト

### 形式手法適用時

- [ ] システムの状態を列挙
- [ ] 状態遷移を定義
- [ ] 不変条件を記述
- [ ] Safety プロパティを定義
- [ ] Liveness プロパティを定義(必要なら)
- [ ] モデル検証実行
- [ ] 反例を分析
- [ ] 仕様を修正
- [ ] 実装へ変換
- [ ] 実装とモデルの同期維持

---

## 📚 参考資料

### 書籍
- "Specifying Systems" by Leslie Lamport (TLA+)
- "Software Abstractions" by Daniel Jackson (Alloy)

### オンライン
- https://learntla.com/
- http://alloytools.org/tutorials.html

---

数学的に正しい並行処理・分散システムを構築。
