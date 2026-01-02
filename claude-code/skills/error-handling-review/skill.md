---
name: error-handling-review
description: エラーハンドリングレビュー - エラー握りつぶし、不適切なログ、エラー伝播を検出
requires-guidelines:
  - common
---

# エラーハンドリングレビュー

## 使用タイミング

- **API/ハンドラー実装時**
- **本番エラー発生時の原因調査**
- **コードレビュー時（エラー処理確認）**

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. エラーの握りつぶし

```typescript
// ❌ 危険 - エラーを無視
try {
  await criticalOperation();
} catch (e) {
  // 何もしない
}

// ✅ 安全 - 適切な処理
try {
  await criticalOperation();
} catch (e) {
  logger.error('Critical operation failed', { error: e });
  throw new OperationError('Failed to process', { cause: e });
}
```

```go
// ❌ 危険
result, err := repo.SaveUser(user)
if err != nil {
    // 無視
}

// ✅ 安全
result, err := repo.SaveUser(user)
if err != nil {
    log.Error("Failed to save user", "error", err, "userID", user.ID)
    return nil, fmt.Errorf("save user failed: %w", err)
}
```

#### 2. 不適切なエラーログ

```typescript
// ❌ 危険 - コンテキスト不足
catch (e) {
  console.log('error'); // 何のエラー？
}

// ✅ 安全 - 十分なコンテキスト
catch (e) {
  logger.error('Failed to process order', {
    error: e,
    orderId: order.id,
    userId: user.id,
    timestamp: new Date().toISOString(),
  });
}
```

#### 3. センシティブ情報のログ出力

```typescript
// ❌ 危険 - パスワードやトークンをログ
logger.error('Login failed', {
  password: user.password,
  token: authToken,
});

// ✅ 安全 - センシティブ情報除外
logger.error('Login failed', {
  userId: user.id,
  email: user.email,
  // password, token は含めない
});
```

### 🟡 Warning（要改善）

#### 1. 汎用的すぎる catch

```typescript
// ⚠️ 改善推奨
try {
  await processPayment();
} catch (e) {
  return { error: 'Something went wrong' }; // 不親切
}

// ✅ エラー種別で分岐
try {
  await processPayment();
} catch (e) {
  if (e instanceof PaymentDeclinedError) {
    return { error: 'Payment was declined' };
  }
  if (e instanceof InsufficientFundsError) {
    return { error: 'Insufficient funds' };
  }
  throw e; // 予期しないエラーは上位へ
}
```

#### 2. エラーメッセージの不一致

```typescript
// ⚠️ 改善推奨
throw new Error('user not found'); // 小文字
throw new Error('User Not Found'); // タイトルケース
throw new Error('USER_NOT_FOUND'); // スネークケース

// ✅ 統一されたエラー
class UserNotFoundError extends Error {
  constructor(userId: string) {
    super(`User not found: ${userId}`);
    this.name = 'UserNotFoundError';
  }
}
```

#### 3. リトライなしの外部API呼び出し

```typescript
// ⚠️ 改善推奨
const result = await externalAPI.call(); // 1回だけ

// ✅ リトライロジック
const result = await retry(
  () => externalAPI.call(),
  { maxAttempts: 3, backoff: 'exponential' }
);
```

```go
// ⚠️ 改善推奨
resp, err := http.Get(url)

// ✅ リトライ
var resp *http.Response
err := retry.Do(func() error {
    var err error
    resp, err = http.Get(url)
    return err
}, retry.Attempts(3))
```

## チェックリスト

### エラー処理
- [ ] 全てのエラーが適切に処理されているか
- [ ] エラーを握りつぶしていないか
- [ ] エラーに十分なコンテキストがあるか
- [ ] カスタムエラー型を定義しているか

### ログ
- [ ] エラー発生箇所が特定できるか
- [ ] センシティブ情報を含んでいないか
- [ ] ログレベルが適切か（error/warn/info）
- [ ] 構造化ログか

### リカバリー
- [ ] リトライが必要な処理にリトライがあるか
- [ ] 部分的な失敗を許容しているか
- [ ] サーキットブレーカーを実装しているか

### エラー伝播
- [ ] エラーを適切にラップしているか（Go: %w）
- [ ] スタックトレースが保持されているか
- [ ] 上位レイヤーで適切に処理されているか

## 出力形式

🔴 **Critical**: `ファイル:行` - エラー握りつぶし/センシティブ情報ログ - 修正案
🟡 **Warning**: `ファイル:行` - 改善推奨箇所 - 具体的な改善方法
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

- `common/error-handling-patterns.md` - プロジェクト共通のエラーハンドリングパターン
  - カスタムエラー定義
  - エラーラッピング規約
  - リトライ戦略
- `languages/golang.md` - Go言語特有のエラーハンドリング
  - `errors.Is` / `errors.As` の使い方
  - `%w` フォーマット指定子
- `languages/typescript.md` - TypeScript特有のエラーハンドリング
  - カスタムエラークラス定義
  - Error boundaries（React）

## 外部知識ベース

- 言語別エラーハンドリングベストプラクティス
  - Go: `errors` package, `panic`/`recover` 使用指針
  - TypeScript: Error subclassing, Promise rejection handling
  - Python: Exception hierarchy, context managers
- エラーログのベストプラクティス
  - 構造化ログ（JSON形式）
  - ログレベル使い分け（error/warn/info/debug）
  - センシティブ情報のマスキング
- リトライ・サーキットブレーカーパターン
  - Exponential backoff
  - Circuit breaker pattern

## プロジェクトコンテキスト

- プロジェクトのエラーハンドリング規約
  - カスタムエラー型の命名規則
  - エラーコード体系
  - エラーレスポンス形式（API）
- ログ戦略
  - ログ基盤（CloudWatch/Datadog/Sentry等）
  - ログフォーマット
  - アラート設定
- 外部サービス連携時の考慮事項
  - タイムアウト設定
  - リトライポリシー
  - フォールバック戦略
