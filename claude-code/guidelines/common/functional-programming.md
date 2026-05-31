# 関数型プログラミング(Functional Programming)

> **目的**: イミュータビリティと純粋関数でバグを削減

---

## 必須原則(4つ)

### 適用条件

| テクニック | 適用条件 |
|-----------|---------|
| Result/Either型 | 常時必須 |
| CQS | 常時必須 |
| イミュータビリティ | Concurrency OR complexity ≥ 5 OR volume != Small |
| 純粋関数 | Logic OR difficulty ≥ 4 |

---

### 1. イミュータビリティ

```typescript
// ✅ スプレッドで新オブジェクト: const newUsers = [...users, user3]
// ❌ 直接変更: users.push(user3)
```

### 2. 純粋関数

同じ入力→同じ出力、副作用なし。
```typescript
// ✅ const total = items.reduce((s, i) => s + i.price, 0)
// ❌ let total = 0; function add(i) { total += i.price }
```

### 3. Result/Either型

```typescript
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E }
function divide(a: number, b: number): Result<number, string> {
  return b === 0 ? { ok: false, error: 'div/0' } : { ok: true, value: a / b }
}
// map: 値変換 / flatMap: ネスト平坦化
```

### 4. コマンドクエリ分離(CQS)

`returns(method) XOR mutates(method)`
```typescript
function getUser(id: string): User { ... }  // Query: 値返す・変更なし
function addUser(user: User): void { ... }  // Command: 変更する・値返さない
```

---

## 高度なパターン

### Option/Maybe型(null安全)

```typescript
type Option<T> = Some<T> | None
// Some<T>: { _tag: 'Some', value: T }
// None: { _tag: 'None' }

function findUser(id: string): Option<User> {
  const user = users.find(u => u.id === id)
  return user ? Some(user) : None
}
```

### パイプライン

```typescript
// pipe: 関数を左から右に合成
const processUser = pipe(
  (id: string) => findUser(id),
  (user: Option<User>) => user._tag === 'Some' ? user.value.name : 'Unknown',
  (name: string) => name.toUpperCase()
)
```

### Lens(ネスト構造のイミュータブル更新)

```typescript
// interface Lens<S, A> { get: (s: S) => A; set: (a: A, s: S) => S }
const cityLens: Lens<User, string> = {
  get: (user) => user.address.city,
  set: (city, user) => ({ ...user, address: { ...user.address, city } })
}
```

---

## 効果

| 項目 | 改善率 |
|------|--------|
| 競合状態バグ | -90%（イミュータビリティ） |
| null参照エラー | -100%（Option型） |
| 例外漏れ | -100%（Result型） |
| テスト容易性 | +80%（純粋関数） |
| デバッグ時間 | -50% |

---

## 他のテクニックとの連携

| 連携先 | 関係 |
|--------|------|
| 圏論 | Result型・Option型はMonad、純粋関数は射(morphism) |
| DDD | Value Object→イミュータブル、Domain Service→純粋関数、Repository→Result型を返す |

---

**参照透明性と合成可能性で、堅牢なコードを構築。**
