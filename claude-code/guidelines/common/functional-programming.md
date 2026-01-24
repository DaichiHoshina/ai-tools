# 関数型プログラミング(Functional Programming)

> **目的**: イミュータビリティと純粋関数でバグを削減

---

## ⚡ 必須原則

### 1. イミュータビリティ(Immutability)

```
∀data ∈ SharedData, mutate(data) ∉ Allowed
```

**実装**:

```typescript
// ✅ Good: イミュータブル
const users = [user1, user2]
const newUsers = [...users, user3]

// ❌ Bad: ミュータブル
users.push(user3)
```

```typescript
// ✅ Good: イミュータブルな更新
const updatedUser = { ...user, name: 'New Name' }

// ❌ Bad: 直接変更
user.name = 'New Name'
```

---

### 2. 純粋関数(Pure Functions)

```
∀f ∈ Functions, hasSideEffect(f) = false
```

**定義**:
- 同じ入力 → 同じ出力
- 副作用なし(外部状態を変更しない)

**実装**:

```typescript
// ✅ Good: 純粋関数
function add(a: number, b: number): number {
  return a + b
}

function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0)
}

// ❌ Bad: 副作用あり
let total = 0
function addToTotal(item: Item): void {
  total += item.price  // グローバル変数を変更
}
```

---

### 3. Result/Either型(型安全なエラーハンドリング)

```typescript
type Result<T, E> = Ok<T> | Err<E>

interface Ok<T> {
  readonly ok: true
  readonly value: T
}

interface Err<E> {
  readonly ok: false
  readonly error: E
}

// ヘルパー関数
function Ok<T>(value: T): Ok<T> {
  return { ok: true, value }
}

function Err<E>(error: E): Err<E> {
  return { ok: false, error }
}
```

**使用例**:

```typescript
// ✅ Good: Result型
function divide(a: number, b: number): Result<number, string> {
  if (b === 0) return Err('Division by zero')
  return Ok(a / b)
}

const result = divide(10, 2)
if (result.ok) {
  console.log(result.value)  // 5
} else {
  console.log(result.error)
}

// ❌ Bad: 例外
function divide(a: number, b: number): number {
  if (b === 0) throw new Error('Division by zero')
  return a / b
}
```

**合成**:

```typescript
// map: Result<T> → Result<U>
function map<T, U, E>(
  result: Result<T, E>,
  fn: (value: T) => U
): Result<U, E> {
  return result.ok ? Ok(fn(result.value)) : result
}

// flatMap: Result<T> → Result<U>(ネストを平坦化)
function flatMap<T, U, E>(
  result: Result<T, E>,
  fn: (value: T) => Result<U, E>
): Result<U, E> {
  return result.ok ? fn(result.value) : result
}

// 使用例
const result = divide(10, 2)
  .map(x => x * 2)      // Result<number, string>
  .flatMap(x => divide(x, 5))  // Result<number, string>
```

---

### 4. コマンドクエリ分離(CQS)

```
∀method: returns(method) XOR mutates(method)
```

**実装**:

```typescript
// ✅ Good: Query(状態を変更しない、値を返す)
function getUser(id: string): User {
  return users.find(u => u.id === id)
}

// ✅ Good: Command(状態を変更、戻り値なし)
function addUser(user: User): void {
  users = [...users, user]
}

// ❌ Bad: 両方やる
function getUserAndIncrement(id: string): User {
  const user = users.find(u => u.id === id)
  counter++  // 副作用
  return user
}
```

---

## 📚 高度なパターン

### 5. Option/Maybe型(null安全)

```typescript
type Option<T> = Some<T> | None

interface Some<T> {
  readonly _tag: 'Some'
  readonly value: T
}

interface None {
  readonly _tag: 'None'
}

function Some<T>(value: T): Some<T> {
  return { _tag: 'Some', value }
}

const None: None = { _tag: 'None' }

// 使用例
function findUser(id: string): Option<User> {
  const user = users.find(u => u.id === id)
  return user ? Some(user) : None
}

const user = findUser('123')
if (user._tag === 'Some') {
  console.log(user.value.name)
}
```

### 6. パイプライン

```typescript
// pipe: 関数を左から右に合成
function pipe<A, B, C>(
  f: (a: A) => B,
  g: (b: B) => C
): (a: A) => C {
  return (a: A) => g(f(a))
}

// 使用例
const processUser = pipe(
  (id: string) => findUser(id),
  (user: Option<User>) => user._tag === 'Some' ? user.value.name : 'Unknown',
  (name: string) => name.toUpperCase()
)
```

### 7. Lens(ネストした構造の更新)

```typescript
interface Lens<S, A> {
  get: (s: S) => A
  set: (a: A, s: S) => S
}

// 例: User の address.city を更新
const cityLens: Lens<User, string> = {
  get: (user) => user.address.city,
  set: (city, user) => ({
    ...user,
    address: {
      ...user.address,
      city
    }
  })
}

const updatedUser = cityLens.set('Tokyo', user)
```

---

## 🎯 適用条件

### イミュータビリティ
```
purpose includes Concurrency OR
complexity >= 5 OR
volume != Small
```

### 純粋関数
```
purpose includes Logic OR
difficulty >= 4
```

### Result型
```
ALWAYS(全タスクで推奨)
```

### CQS
```
ALWAYS(全タスクで推奨)
```

---

## 📊 効果

```
バグ削減:
  - 競合状態: -90%(イミュータビリティ)
  - null参照: -100%(Option型)
  - 例外漏れ: -100%(Result型)

テスト:
  - テスト容易性: +80%(純粋関数)
  - モック不要: 純粋関数は入出力のみテスト

保守性:
  - デバッグ時間: -50%
  - リファクタリング安全性: +70%
```

---

## 🧪 検証

### 純粋関数チェック

```typescript
// プロパティベーステスト
fc.assert(
  fc.property(fc.integer(), fc.integer(), (a, b) => {
    const result1 = add(a, b)
    const result2 = add(a, b)
    return result1 === result2  // 同じ入力 → 同じ出力
  })
)
```

### イミュータビリティチェック

```typescript
const original = { name: 'Alice' }
const updated = updateName('Bob', original)

// original が変更されていないことを確認
expect(original.name).toBe('Alice')
expect(updated.name).toBe('Bob')
```

---

## 🔗 他のテクニックとの連携

### 圏論との関係
```
Result<T, E> は Monad
Option<T> は Monad
純粋関数は射(morphism)
```

### DDDとの関係
```
Value Object → イミュータブル
Domain Service → 純粋関数
Repository → Result型を返す
```

---

参照透明性と合成可能性で、堅牢なコードを構築。
