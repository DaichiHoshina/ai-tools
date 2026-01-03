---
name: docs-test-review
description: ドキュメント・テスト品質レビュー - コメント品質、API仕様、テストの意味、カバレッジを統合評価
requires-guidelines:
  - common
---

# ドキュメント・テスト品質レビュー（統合版）

## 統合スコープ

このスキルは以下2つの観点を統合したレビューを提供します：

1. **ドキュメント** - コメント品質、API仕様、README、型定義コメント
2. **テスト品質** - テストの意味、カバレッジ、モック適切性、テスタビリティ

## 使用タイミング

- **API実装時**
- **公開ライブラリ作成時**
- **/test コマンド実行時**
- **/docs コマンド実行時**

---

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. ドキュメント: 公開API・型に説明なし

```typescript
// ❌ 危険 - 説明なし
export interface User {
  id: string;
  metadata: unknown; // 何のデータ？
}

// ✅ 安全 - 明確な説明
/**
 * ユーザー情報
 */
export interface User {
  /** ユーザーID（UUID v4） */
  id: string;
  /** カスタムメタデータ（最大1KB、JSON形式） */
  metadata: Record<string, unknown>;
}
```

```go
// ❌ 危険
type Config struct {
    MaxRetries int
    Timeout    time.Duration
}

// ✅ 安全
// Config はクライアント設定を表す
type Config struct {
    // MaxRetries はリトライ最大回数（デフォルト: 3）
    MaxRetries int
    // Timeout は1リクエストあたりのタイムアウト
    Timeout time.Duration
}
```

#### 2. ドキュメント: 嘘のコメント

```typescript
// ❌ 危険 - 実装と不一致
/**
 * ユーザーを削除する
 */
function archiveUser(id: string) {
  // 実際は削除していない
  return db.update({ id, archivedAt: new Date() });
}

// ✅ 安全 - 実装と一致
/**
 * ユーザーをアーカイブする（論理削除）
 */
function archiveUser(id: string) {
  return db.update({ id, archivedAt: new Date() });
}
```

#### 3. テスト: 意味のないテスト

```typescript
// ❌ 危険 - 何もテストしていない
test('user exists', () => {
  const user = { id: 1, name: 'test' };
  expect(user).toBeDefined();
});

// ✅ 安全 - 実際の振る舞いをテスト
test('createUser saves user to database', async () => {
  const user = await createUser({ name: 'test' });
  const saved = await db.findUser(user.id);
  expect(saved.name).toBe('test');
});
```

#### 4. テスト: 実装詳細のテスト

```typescript
// ❌ 危険 - 内部実装に依存
test('button calls handleClick', () => {
  const handleClick = jest.fn();
  render(<Button onClick={handleClick} />);
  expect(handleClick).not.toHaveBeenCalled(); // 意味がない
});

// ✅ 安全 - ユーザー視点でテスト
test('button click shows success message', () => {
  render(<Button />);
  fireEvent.click(screen.getByRole('button'));
  expect(screen.getByText('Success')).toBeInTheDocument();
});
```

#### 5. テスト: 過剰なモック

```typescript
// ❌ 危険 - 全部モック（実際の動作を検証していない）
jest.mock('./api');
jest.mock('./database');
jest.mock('./cache');
test('process works', async () => {
  await process();
  expect(mockApi).toHaveBeenCalled(); // 実際には何も動いていない
});

// ✅ 安全 - 境界のみモック
test('process handles API error', async () => {
  mockApiCall.mockRejectedValue(new Error('Network error'));
  await expect(process()).rejects.toThrow('Failed to process');
});
```

### 🟡 Warning（要改善）

#### 1. ドキュメント: 自明なコメント

```typescript
// ⚠️ 不要
// ユーザーIDを取得
const userId = user.id;

// カウンターをインクリメント
counter++;

// ✅ コメント不要（コード自体が明確）
const userId = user.id;
counter++;
```

#### 2. ドキュメント: 不十分なエラー説明

```typescript
// ⚠️ 改善推奨
/**
 * ユーザー作成
 * @throws Error
 */
function createUser() { ... }

// ✅ 具体的
/**
 * ユーザー作成
 * @throws {ValidationError} 入力データが不正な場合
 * @throws {DuplicateEmailError} メールアドレスが既に存在する場合
 * @throws {DatabaseError} DB接続エラーの場合
 */
function createUser() { ... }
```

#### 3. ドキュメント: TODOの放置

```typescript
// ⚠️ 危険 - 古いTODO
// TODO: バリデーション追加（2020-01-01）
function createUser(data: any) { ... }

// ✅ 安全 - Issue化 or 実装
/**
 * ユーザー作成
 * @throws {ValidationError} バリデーションエラー時
 */
function createUser(data: CreateUserInput) {
  validateUserInput(data);
  return db.insert(data);
}
```

#### 4. テスト: テストの独立性欠如

```typescript
// ⚠️ テスト間で状態共有
let sharedUser;
test('create user', () => {
  sharedUser = createUser();
});
test('update user', () => {
  updateUser(sharedUser); // 前のテストに依存
});

// ✅ 各テストで独立したデータ
test('create user', () => {
  const user = createUser();
  expect(user).toBeDefined();
});
test('update user', () => {
  const user = createUser();
  const updated = updateUser(user);
  expect(updated.updatedAt).toBeDefined();
});
```

#### 5. テスト: 不安定なテスト（Flaky Test）

```typescript
// ⚠️ タイミング依存
test('animation completes', async () => {
  startAnimation();
  await new Promise(r => setTimeout(r, 100)); // 環境依存
  expect(isComplete()).toBe(true);
});

// ✅ イベント待機
test('animation completes', async () => {
  const promise = waitForAnimationEnd();
  startAnimation();
  await promise;
  expect(isComplete()).toBe(true);
});
```

#### 6. テスト: カバレッジ不足

```go
// ⚠️ エラーケースのテストなし
func TestProcess(t *testing.T) {
    result := Process("valid input")
    assert.NotNil(t, result)
    // エラーケースがない
}

// ✅ 正常・異常両方
func TestProcess(t *testing.T) {
    t.Run("valid input", func(t *testing.T) {
        result := Process("valid")
        assert.NotNil(t, result)
    })
    t.Run("invalid input", func(t *testing.T) {
        result := Process("")
        assert.Nil(t, result)
    })
}
```

---

## チェックリスト

### ドキュメント
- [ ] 公開API全てに説明があるか
- [ ] パラメータの制約が明記されているか
- [ ] 戻り値の説明があるか
- [ ] エラー条件が明記されているか
- [ ] コメントと実装が一致しているか
- [ ] 自明なコメントを避けているか

### テスト品質
- [ ] 何をテストしているか明確か
- [ ] ユーザー視点でテストしているか
- [ ] テスト名が振る舞いを説明しているか
- [ ] Arrange-Act-Assert パターンか
- [ ] テストが独立しているか
- [ ] 必要最小限のモックか

### カバレッジ
- [ ] 正常系・異常系両方テストしているか
- [ ] エッジケースをカバーしているか
- [ ] 境界値テストがあるか

---

## 出力形式

```
## ドキュメント・テスト品質レビュー結果

### ドキュメント
🔴 **Critical**: `ファイル:行` - 公開API説明なし - 修正案
🔴 **Critical**: `ファイル:行` - 嘘のコメント - 修正案
🟡 **Warning**: `ファイル:行` - 自明なコメント - 削除推奨

### テスト品質
🔴 **Critical**: `ファイル:行` - 意味のないテスト - 改善案
🔴 **Critical**: `ファイル:行` - 過剰なモック - 修正案
🟡 **Warning**: `ファイル:行` - テスト独立性欠如 - 改善案

### カバレッジ
🟡 **Warning**: `ファイル:行` - エラーケース未テスト - 追加推奨

📊 **Summary**: Critical X件 / Warning Y件
```

---

## 関連ガイドライン

- `common/document-management.md` - ドキュメント管理指針
- `common/testing-guidelines.md` - テストガイドライン
- `languages/typescript.md` - TypeScript型安全性ベストプラクティス
- `languages/golang.md` - Go言語の型システムとエラーハンドリング

---

## 外部知識ベース

最新情報確認には context7 を活用:
- **テクニカルライティングガイド**
  - Microsoft Writing Style Guide
  - Google Developer Documentation Style Guide
- **API documentation standards**
  - OpenAPI/Swagger仕様
  - JSDoc/TSDoc規約
  - GoDoc規約
- **テスティングフレームワーク公式ドキュメント**
  - Jest/Vitest - JavaScript/TypeScript
  - Go testing package - Go
  - pytest - Python
- **テストピラミッド原則**
- **Testing Trophy（Kent C. Dodds）**
- **Test-Driven Development（TDD）パターン**

---

## プロジェクトコンテキスト

プロジェクト固有の情報を確認:
- ドキュメント規約（コメント記述言語、JSDoc/TSDoc記法）
- 必須ドキュメント（README.md、CONTRIBUTING.md、API.md、CHANGELOG.md）
- テスト戦略（ユニット vs 統合 vs E2Eテストの比率）
- カバレッジ目標（最低カバレッジ率）
- テストファイル命名規則（*.test.ts / *_test.go 等）
