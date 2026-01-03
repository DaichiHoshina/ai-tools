---
name: test-quality-review
description: テスト品質レビュー - テストの意味、カバレッジ、モック適切性、テスタビリティを評価
requires-guidelines:
  - common
---

# テスト品質レビュー

## 使用タイミング

- **/test コマンド実行時**
- **テストコード作成後のレビュー**
- **CI/CDでテストが不安定な時**

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. 意味のないテスト

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

#### 2. 実装詳細のテスト

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

#### 3. 過剰なモック

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

#### 1. テストの独立性欠如

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

#### 2. 不安定なテスト（Flaky Test）

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

#### 3. カバレッジ不足

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

## チェックリスト

### テストの品質
- [ ] 何をテストしているか明確か
- [ ] ユーザー視点でテストしているか
- [ ] 実装詳細に依存していないか
- [ ] テスト名が振る舞いを説明しているか

### テストの構造
- [ ] Arrange-Act-Assert パターンか
- [ ] 1テスト1アサーション（概ね）
- [ ] テストが独立しているか
- [ ] setup/teardown が適切か

### モック
- [ ] 必要最小限のモックか
- [ ] 境界（外部API等）のみモックしているか
- [ ] モックの振る舞いが現実的か

### カバレッジ
- [ ] 正常系・異常系両方テストしているか
- [ ] エッジケースをカバーしているか
- [ ] 境界値テストがあるか

## 出力形式

🔴 **Critical**: `ファイル:行` - 意味のないテスト - 改善案
🟡 **Warning**: `ファイル:行` - 改善推奨 - 具体的な修正方法
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

- `common/testing-guidelines.md` - プロジェクト共通のテストガイドライン
  - テスト構造（AAA パターン）
  - モックの使い方
  - カバレッジ目標

## 外部知識ベース

- テスティングフレームワーク公式ドキュメント
  - Jest/Vitest - JavaScript/TypeScript
  - Go testing package - Go
  - pytest - Python
- テストピラミッド原則
- Testing Trophy（Kent C. Dodds）
- Test-Driven Development（TDD）パターン

## プロジェクトコンテキスト

- プロジェクトのテスト戦略
  - ユニットテスト vs 統合テスト vs E2Eテストの比率
  - テスト実行環境（CI/CD設定）
- カバレッジ目標
  - 最低カバレッジ率（branch/line/function）
  - 除外ファイル・ディレクトリ
- テストファイル命名規則
  - `*.test.ts` / `*_test.go` 等のパターン
