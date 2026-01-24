# テクニック自動選択(Technique Auto-Selection)

> **目的**: タスクの特性に応じて最適なテクニックを自動選択

---

## 🎯 タスク分類フレームワーク

### タスク次元(4次元)

```
1. 目的(Purpose): {CRUD, Logic, Concurrency, Security, Performance}
2. 複雑さ(Complexity): 1-10
3. 難しさ(Difficulty): 1-10
4. 量(Volume): {Small, Medium, Large}
```

### 自動分類ロジック

```typescript
interface TaskCharacteristics {
  purpose: Purpose[]
  complexity: number  // 1-10
  difficulty: number  // 1-10
  volume: Volume
}

// 自動計算
function analyzeTask(task: string): TaskCharacteristics {
  return {
    purpose: detectPurpose(task),
    complexity: calculateComplexity(task),
    difficulty: calculateDifficulty(task),
    volume: calculateVolume(task)
  }
}
```

---

## 📊 テクニック選択マトリクス

### 1. 圏論(Category Theory)
```
適用条件:
  complexity >= 7 OR
  (purpose includes Logic AND difficulty >= 6)

効果:
  - 抽象化による複雑さ削減
  - 合成可能性の保証
  - 数学的正しさの検証

トークンコスト: +2K
```

### 2. 形式手法(Formal Methods)
```
適用条件:
  purpose includes Concurrency OR
  (purpose includes Security AND difficulty >= 8) OR
  complexity >= 9

効果:
  - 並行処理の正しさ検証
  - デッドロック検出
  - 状態空間の網羅的探索

トークンコスト: +1K

ツール:
  - TLA+: 分散システム
  - Alloy: データモデル検証
```

### 3. プロパティベーステスト(Property-Based Testing)
```
適用条件:
  difficulty >= 5 OR
  complexity >= 6 OR
  purpose includes Logic

効果:
  - エッジケースの自動発見
  - 網羅的テスト生成
  - 仕様の形式化

トークンコスト: +800

ライブラリ:
  - TypeScript: fast-check
  - Python: hypothesis
  - Go: gopter
```

### 4. Result/Either型(Functional Error Handling)
```
適用条件:
  ALWAYS (全タスクで推奨)

効果:
  - 型安全なエラーハンドリング
  - 例外の排除
  - 合成可能なエラー処理

トークンコスト: +500

実装:
  type Result<T, E> = Ok<T> | Err<E>
```

### 5. イミュータビリティ(Immutability)
```
適用条件:
  purpose includes Concurrency OR
  complexity >= 5 OR
  volume != Small

効果:
  - 競合状態の排除
  - デバッグ容易性向上
  - 副作用の制限

トークンコスト: +300

制約:
  ∀data ∈ SharedData, mutate(data) ∉ Allowed
```

### 6. 純粋関数(Pure Functions)
```
適用条件:
  purpose includes Logic OR
  difficulty >= 4

効果:
  - テスト容易性向上
  - 参照透明性
  - 合成可能性

トークンコスト: +400

制約:
  ∀f ∈ Functions, hasSideEffect(f) = false
```

### 7. DDD戦術的パターン(DDD Tactical Patterns)
```
適用条件:
  complexity >= 7 OR
  volume == Large OR
  (purpose includes Logic AND difficulty >= 6)

効果:
  - ドメインロジックの整理
  - 境界の明確化
  - ビジネスルールの表現

トークンコスト: +1.5K

パターン:
  - Value Object
  - Entity
  - Aggregate Root
  - Domain Service
```

### 8. 契約プログラミング(Design by Contract)
```
適用条件:
  difficulty >= 6 OR
  purpose includes Security OR
  complexity >= 7

効果:
  - 事前条件・事後条件の明示化
  - 不変条件の保証
  - ランタイム検証

トークンコスト: +600

アノテーション:
  @pre, @post, @invariant
```

### 9. 状態機械(State Machine)
```
適用条件:
  purpose includes Logic OR
  (complexity >= 6 AND purpose includes CRUD)

効果:
  - 状態遷移の型安全性
  - 無効な遷移の防止
  - ビジネスフローの可視化

トークンコスト: +700

実装:
  type State = State1 | State2 | State3
  function transition(from: State1): State2
```

### 10. コマンドクエリ分離(CQS)
```
適用条件:
  ALWAYS (全タスクで推奨)

効果:
  - 副作用の明示化
  - メソッドの予測可能性向上
  - テスト容易性向上

トークンコスト: +200

制約:
  ∀method: returns(method) XOR mutates(method)
```

---

## 🤖 自動選択アルゴリズム

### 選択ロジック

```typescript
function selectTechniques(task: TaskCharacteristics): Technique[] {
  const selected: Technique[] = []

  // 必須テクニック(常時適用)
  selected.push('Result/Either型')
  selected.push('CQS')

  // 複雑さベース
  if (task.complexity >= 9) {
    selected.push('形式手法')
  }
  if (task.complexity >= 7) {
    selected.push('圏論')
    selected.push('DDD戦術的パターン')
  }
  if (task.complexity >= 6) {
    selected.push('プロパティベーステスト')
    selected.push('状態機械')
  }
  if (task.complexity >= 5) {
    selected.push('イミュータビリティ')
  }

  // 難しさベース
  if (task.difficulty >= 8) {
    selected.push('形式手法')
  }
  if (task.difficulty >= 6) {
    selected.push('圏論')
    selected.push('契約プログラミング')
  }
  if (task.difficulty >= 5) {
    selected.push('プロパティベーステスト')
  }
  if (task.difficulty >= 4) {
    selected.push('純粋関数')
  }

  // 目的ベース
  if (task.purpose.includes('Concurrency')) {
    selected.push('形式手法')
    selected.push('イミュータビリティ')
  }
  if (task.purpose.includes('Security')) {
    selected.push('契約プログラミング')
  }
  if (task.purpose.includes('Logic')) {
    selected.push('プロパティベーステスト')
    selected.push('純粋関数')
    selected.push('状態機械')
    selected.push('DDD戦術的パターン')
  }

  // 量ベース
  if (task.volume === 'Large') {
    selected.push('DDD戦術的パターン')
  }

  // 重複削除
  return [...new Set(selected)]
}
```

### トークン予算管理

```typescript
function applyTokenBudget(
  techniques: Technique[],
  budget: number = 10000  // 10K制限
): Technique[] {
  const costs = calculateTotalCost(techniques)

  if (costs <= budget) {
    return techniques
  }

  // 優先度順にソート(効果/コスト比)
  const sorted = techniques.sort((a, b) =>
    (effectivenessScore(b) / cost(b)) -
    (effectivenessScore(a) / cost(a))
  )

  // 予算内に収まるまで削減
  const result: Technique[] = []
  let currentCost = 0

  for (const tech of sorted) {
    if (currentCost + cost(tech) <= budget) {
      result.push(tech)
      currentCost += cost(tech)
    }
  }

  return result
}
```

---

## 📋 選択例

### 例1: シンプルなCRUD API
```
タスク: ユーザー登録APIの実装

分析結果:
  purpose: [CRUD]
  complexity: 3
  difficulty: 2
  volume: Small

選択されたテクニック:
  ✓ Result/Either型(必須)
  ✓ CQS(必須)

トークンコスト: 700
```

### 例2: 決済処理システム
```
タスク: クレジットカード決済フローの実装

分析結果:
  purpose: [Logic, Security]
  complexity: 8
  difficulty: 7
  volume: Medium

選択されたテクニック:
  ✓ Result/Either型(必須)
  ✓ CQS(必須)
  ✓ 圏論(complexity >= 7, difficulty >= 6)
  ✓ DDD戦術的パターン(complexity >= 7)
  ✓ プロパティベーステスト(complexity >= 6)
  ✓ 状態機械(purpose includes Logic)
  ✓ 契約プログラミング(difficulty >= 6, purpose includes Security)
  ✓ イミュータビリティ(complexity >= 5)
  ✓ 純粋関数(difficulty >= 4)

トークンコスト: 6.6K
```

### 例3: 分散トランザクション
```
タスク: マイクロサービス間の分散トランザクション実装

分析結果:
  purpose: [Concurrency, Logic]
  complexity: 10
  difficulty: 9
  volume: Large

選択されたテクニック:
  ✓ Result/Either型(必須)
  ✓ CQS(必須)
  ✓ 形式手法(complexity >= 9, difficulty >= 8, purpose includes Concurrency)
  ✓ 圏論(complexity >= 7, difficulty >= 6)
  ✓ DDD戦術的パターン(complexity >= 7, volume == Large)
  ✓ プロパティベーステスト(complexity >= 6)
  ✓ 状態機械(purpose includes Logic)
  ✓ 契約プログラミング(difficulty >= 6)
  ✓ イミュータビリティ(complexity >= 5, purpose includes Concurrency)
  ✓ 純粋関数(difficulty >= 4)

トークンコスト: 8.5K(予算内)
```

---

## 🔄 Progressive Disclosure統合

### Level 1: タスク分析(自動)
```
1. タスク特性を自動分析
2. 適用テクニック一覧を生成
3. トークン予算を確認
```

### Level 2: テクニック概要ロード
```
選択されたテクニックの概要のみロード
例: Result型の基本パターン(詳細は未ロード)
```

### Level 3: 詳細ロード(必要時)
```
実装中に詳細が必要になった時のみロード
例: プロパティベーステストの高度なパターン
```

---

## 📊 効果測定

### 期待される改善

```
コード品質:
  - バグ密度: -60%
  - テストカバレッジ: +20%
  - セキュリティ脆弱性: -80%

開発効率:
  - 設計時間: -30%(適切なテクニック自動選択)
  - デバッグ時間: -40%(型安全性、純粋関数)
  - リファクタリング時間: -50%(合成可能性)

トークン効率:
  - 無駄なロード: -70%
  - 的確なテクニック選択: +90%
```

---

タスクの特性を分析し、最適なテクニックを自動選択。数学的に正しく、効率的なコードを生産。
