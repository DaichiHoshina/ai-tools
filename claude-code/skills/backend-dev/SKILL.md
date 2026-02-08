---
name: backend-dev
description: バックエンド開発 - Go/TypeScript/Python/Rust対応（言語自動検出）
requires-guidelines:
  - common
  - golang  # lang=go の場合
  - typescript  # lang=typescript の場合
  - python  # lang=python の場合
  - rust  # lang=rust の場合
parameters:
  lang:
    type: enum
    values: [auto, go, typescript, python, rust]
    default: auto
    description: 開発言語（auto=変更ファイルから自動検出）
hooks:
  - event: PreSkillUse
    command: "~/.claude/hooks/pre-skill-use.sh"
---

# Backend Development - バックエンド開発

## 概要

複数言語に対応したバックエンド開発スキル。言語固有のベストプラクティスと共通の設計原則を提供します。

## パラメータ

### `--lang` オプション

開発言語を指定します（デフォルト: auto）

```bash
# 自動検出（デフォルト）
/skill backend-dev

# 明示的指定
/skill backend-dev --lang=go
/skill backend-dev --lang=typescript
/skill backend-dev --lang=python
/skill backend-dev --lang=rust
```

**環境変数での指定**:
```bash
export BACKEND_LANG=go
/skill backend-dev
```

**自動検出ロジック**:
```bash
# 変更ファイルの拡張子から推論
git diff --name-only | grep -q '\.go$' → lang=go
git diff --name-only | grep -q '\.(ts|tsx)$' → lang=typescript
git diff --name-only | grep -q '\.py$' → lang=python
git diff --name-only | grep -q '\.rs$' → lang=rust
```

## 使用タイミング

- バックエンドAPI実装時
- データベース操作実装時
- 並行処理・非同期処理実装時
- コードレビュー時

---

## 共通ベストプラクティス

### 🔴 Critical（全言語共通）

#### 1. エラーハンドリング
- エラーを無視しない
- 適切なエラーメッセージを付与
- エラー型を明示（型安全な言語）

#### 2. セキュリティ
- SQLインジェクション対策（パラメータ化クエリ）
- 機密情報のログ出力禁止
- 認証・認可の適切な実装

#### 3. テスト
- 単体テストの作成
- 正常系・異常系両方をテスト
- モックの適切な使用

### 🟡 Warning（全言語共通）

#### 1. パフォーマンス
- N+1クエリ問題
- 不要なメモリ確保
- 非効率なアルゴリズム

#### 2. 保守性
- 関数は1つの責務のみ
- マジックナンバーの定数化
- 適切なコメント

---

## Go固有のベストプラクティス

### 🔴 Critical

#### 1. エラーハンドリング
```go
// ❌ 危険: エラー無視
result, _ := userRepo.Find(id)

// ✅ 正しい: エラー適切処理
result, err := userRepo.Find(id)
if err != nil {
    return fmt.Errorf("failed to find user: %w", err)
}
```

#### 2. goroutineリーク
```go
// ❌ 危険: 終了しないgoroutine
func process() {
    ch := make(chan int)
    go func() {
        for v := range ch {  // chがクローズされない
            fmt.Println(v)
        }
    }()
}

// ✅ 正しい: contextでキャンセル制御
func process(ctx context.Context) {
    ch := make(chan int)
    go func() {
        defer close(ch)
        for {
            select {
            case <-ctx.Done():
                return
            case v := <-ch:
                fmt.Println(v)
            }
        }
    }()
}
```

#### 3. インターフェース設計
```go
// ❌ 危険: 不要なインターフェース
type UserRepositoryInterface interface {
    Find(int) (*User, error)
    Save(*User) error
}

// ✅ 正しい: 必要な場所でのみ定義（Accept interfaces, return structs）
// domain/repository.go
type UserRepository interface {
    Find(int) (*User, error)
}

// infrastructure/user_repository.go
type userRepositoryImpl struct { ... }
func (r *userRepositoryImpl) Find(id int) (*User, error) { ... }
```

### 🟡 Warning

#### 1. context不使用
```go
// ⚠️ タイムアウト制御がない
func FetchData(url string) ([]byte, error) {
    resp, err := http.Get(url)
    ...
}

// ✅ contextでタイムアウト制御
func FetchData(ctx context.Context, url string) ([]byte, error) {
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    resp, err := http.DefaultClient.Do(req)
    ...
}
```

#### 2. テーブル駆動テスト未使用
```go
// ✅ テーブル駆動テスト
func TestAdd(t *testing.T) {
    tests := []struct {
        name string
        a, b int
        want int
    }{
        {"positive", 1, 2, 3},
        {"zero", 0, 0, 0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            if got := Add(tt.a, tt.b); got != tt.want {
                t.Errorf("got %d, want %d", got, tt.want)
            }
        })
    }
}
```

---

## TypeScript固有のベストプラクティス

### 🔴 Critical

#### 1. 型安全性
```typescript
// ❌ 危険: any使用
async function getUser(id: any): Promise<any> {
    const result = await db.query('SELECT * FROM users WHERE id = ?', [id]);
    return result;
}

// ✅ 正しい: 厳格な型定義
type UserId = string & { __brand: 'UserId' };
interface User {
    id: UserId;
    name: string;
    email: string;
}

async function getUser(id: UserId): Promise<User | null> {
    const result = await db.query<User>(
        'SELECT * FROM users WHERE id = ?',
        [id]
    );
    return result.rows[0] ?? null;
}
```

#### 2. Result型パターン
```typescript
// ✅ エラーハンドリング
type Result<T, E = Error> =
    | { ok: true; value: T }
    | { ok: false; error: E };

async function createUser(
    data: CreateUserInput
): Promise<Result<User, ValidationError | DatabaseError>> {
    const validated = validateInput(data);
    if (!validated.ok) {
        return { ok: false, error: validated.error };
    }

    try {
        const user = await userRepo.save(validated.value);
        return { ok: true, value: user };
    } catch (error) {
        if (error instanceof DatabaseError) {
            return { ok: false, error };
        }
        throw error;
    }
}
```

#### 3. Non-null assertion禁止
```typescript
// ❌ 危険: ! 演算子
function processUser(userId: string) {
    const user = users.find(u => u.id === userId)!;
    return user.name;  // userがundefinedの可能性
}

// ✅ 正しい: 明示的nullチェック
function processUser(userId: string): string | null {
    const user = users.find(u => u.id === userId);
    if (!user) {
        return null;
    }
    return user.name;
}
```

### 🟡 Warning

#### 1. 依存性注入
```typescript
// ✅ DIコンテナ活用
interface IUserRepository {
    findById(id: string): Promise<User | null>;
}

class UserService {
    constructor(private repo: IUserRepository) {}

    async find(id: string) {
        return this.repo.findById(id);
    }
}
```

---

## Python固有のベストプラクティス

### 🔴 Critical

#### 1. 型ヒント
```python
# ❌ 型ヒントなし
def get_user(id):
    return db.query("SELECT * FROM users WHERE id = ?", [id])

# ✅ 型ヒント使用
from typing import Optional

def get_user(user_id: int) -> Optional[User]:
    result = db.query("SELECT * FROM users WHERE id = ?", [user_id])
    return User.from_dict(result) if result else None
```

#### 2. 例外処理
```python
# ❌ 汎用的すぎる例外
try:
    user = get_user(id)
except Exception:
    pass

# ✅ 具体的な例外処理
try:
    user = get_user(id)
except UserNotFoundError as e:
    logger.error(f"User not found: {e}")
    return None
except DatabaseError as e:
    logger.error(f"Database error: {e}")
    raise
```

### 🟡 Warning

#### 1. データクラス活用
```python
# ✅ dataclassで型安全
from dataclasses import dataclass

@dataclass
class User:
    id: int
    name: str
    email: str
```

---

## Rust固有のベストプラクティス

### 🔴 Critical

#### 1. Result型の活用
```rust
// ✅ Result型でエラーハンドリング
async fn get_user(id: i32) -> Result<User, DatabaseError> {
    let user = db.query_one("SELECT * FROM users WHERE id = $1", &[&id])
        .await
        .map_err(|e| DatabaseError::QueryFailed(e))?;
    Ok(User::from_row(user))
}
```

#### 2. 所有権の明示
```rust
// ✅ 所有権を明示
fn process_user(user: User) -> String {
    // user を消費
    user.name
}

fn borrow_user(user: &User) -> &str {
    // user を借用
    &user.name
}
```

---

## チェックリスト

### エラーハンドリング
- [ ] すべてのエラーを適切に処理
- [ ] エラーメッセージに文脈情報を付与
- [ ] 型安全なエラー処理（該当言語）

### セキュリティ
- [ ] SQLインジェクション対策
- [ ] 機密情報のログ出力なし
- [ ] 認証・認可の実装

### テスト
- [ ] 単体テストの作成
- [ ] 正常系・異常系のテスト
- [ ] モックの適切な使用

### パフォーマンス
- [ ] N+1クエリなし
- [ ] 並行処理の適切な使用
- [ ] メモリリークなし

---

## 外部リソース

- **Context7**: 言語別公式ドキュメント参照
- **Serena memory**: プロジェクト固有の規約・パターン

---

## 移行ガイド

### 旧スキル名からの移行

**go-backend → backend-dev**:
```bash
# 旧: /skill go-backend
# 新: /skill backend-dev --lang=go
# または環境変数:
export BACKEND_LANG=go
/skill backend-dev
```

**typescript-backend → backend-dev**:
```bash
# 旧: /skill typescript-backend
# 新: /skill backend-dev --lang=typescript
# または自動検出（.tsファイルを変更している場合）:
/skill backend-dev
```

**後方互換性**:
旧スキル名（go-backend, typescript-backend）は detect-from-*.sh が自動的に新スキル名に変換します。
