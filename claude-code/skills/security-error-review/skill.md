---
name: security-error-review
description: セキュリティ・エラーハンドリングレビュー - OWASP Top 10、エラー処理、ログ管理を統合評価
requires-guidelines:
  - common
---

# セキュリティ・エラーハンドリングレビュー（統合版）

## 統合スコープ

このスキルは以下2つの観点を統合したレビューを提供します：

1. **セキュリティ** - OWASP Top 10、インジェクション対策、認証・セッション管理
2. **エラーハンドリング** - エラー握りつぶし、適切なログ、エラー伝播

## 使用タイミング

- **API実装時**
- **認証・認可機能実装時**
- **本番エラー発生時の原因調査**
- **セキュリティレビュー時**

---

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. セキュリティ: SQL インジェクション

```java
// ❌ 危険: 文字列結合
String query = "SELECT * FROM users WHERE id = '" + userId + "'";

// ✅ 安全: PreparedStatement
String query = "SELECT * FROM users WHERE id = ?";
PreparedStatement pstmt = connection.prepareStatement(query);
pstmt.setString(1, userId);
```

```typescript
// ❌ 危険: 文字列結合
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// ✅ 安全: パラメータ化クエリ
const query = 'SELECT * FROM users WHERE id = ?';
const result = await db.query(query, [userId]);
```

#### 2. セキュリティ: XSS（クロスサイトスクリプティング）

```typescript
// ❌ 危険: エスケープなし
element.innerHTML = userInput;

// ✅ 安全: エスケープ
element.textContent = userInput;
// または
element.innerHTML = DOMPurify.sanitize(userInput);
```

#### 3. セキュリティ: 認証・セッション管理の不備

```typescript
// ❌ 危険: パスワード平文保存
const user = { email, password };
await db.save(user);

// ✅ 安全: ハッシュ化
const hashedPassword = await bcrypt.hash(password, 10);
const user = { email, password: hashedPassword };
await db.save(user);
```

```typescript
// ❌ 危険: セッションIDがURLに露出
const url = `/dashboard?sessionId=${sessionId}`;

// ✅ 安全: Cookie（HttpOnly, Secure, SameSite）
res.cookie('sessionId', sessionId, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict',
});
```

#### 4. セキュリティ: センシティブ情報の露出

```typescript
// ❌ 危険: エラーに機密情報
catch (e) {
  res.status(500).json({
    error: e.message,  // スタックトレース、DB情報が漏洩
    dbConnectionString: e.connectionString,
  });
}

// ✅ 安全: 一般的なエラーメッセージ
catch (e) {
  logger.error('Database error', { error: e });
  res.status(500).json({
    error: 'Internal server error',
  });
}
```

#### 5. エラーハンドリング: エラーの握りつぶし

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

#### 6. エラーハンドリング: センシティブ情報のログ出力

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

#### 1. セキュリティ: セキュリティヘッダー不足

```http
# ⚠️ 改善推奨: ヘッダーなし
HTTP/1.1 200 OK

# ✅ 推奨: セキュリティヘッダー設定
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
```

#### 2. セキュリティ: レート制限なし

```typescript
// ⚠️ 改善推奨: レート制限なし
app.post('/api/login', loginHandler);

// ✅ 推奨: レート制限
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 5, // 5回まで
});

app.post('/api/login', limiter, loginHandler);
```

#### 3. エラーハンドリング: 汎用的すぎる catch

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

#### 4. エラーハンドリング: リトライなしの外部API呼び出し

```typescript
// ⚠️ 改善推奨
const result = await externalAPI.call(); // 1回だけ

// ✅ リトライロジック
const result = await retry(
  () => externalAPI.call(),
  { maxAttempts: 3, backoff: 'exponential' }
);
```

---

## OWASP Top 10 (2021) クイックリファレンス

| ランク | カテゴリ | 主な対策 |
|--------|----------|----------|
| A01 | Broken Access Control | 認可チェック、最小権限の原則 |
| A02 | Cryptographic Failures | HTTPS強制、ハッシュ化（bcrypt） |
| A03 | Injection | パラメータ化クエリ、入力検証 |
| A04 | Insecure Design | セキュアな設計、脅威モデリング |
| A05 | Security Misconfiguration | セキュリティヘッダー、最新化 |
| A06 | Vulnerable Components | 依存パッケージ更新 |
| A07 | Auth Failures | MFA、セッション管理 |
| A08 | Data Integrity Failures | 署名検証、改ざん防止 |
| A09 | Logging Failures | 構造化ログ、アラート |
| A10 | SSRF | URL検証、ホワイトリスト |

---

## チェックリスト

### セキュリティ
- [ ] SQLクエリはパラメータ化されているか
- [ ] ユーザー入力は検証・エスケープされているか
- [ ] パスワードはハッシュ化されているか
- [ ] セッションIDはCookie（HttpOnly, Secure）で管理されているか
- [ ] セキュリティヘッダーが設定されているか
- [ ] レート制限があるか

### エラーハンドリング
- [ ] 全てのエラーが適切に処理されているか
- [ ] エラーに十分なコンテキストがあるか
- [ ] センシティブ情報をログに含んでいないか
- [ ] エラーを適切にラップしているか（Go: %w）

---

## 出力形式

```
## セキュリティ・エラーハンドリングレビュー結果

### セキュリティ
🔴 **Critical**: `ファイル:行` - SQLインジェクション脆弱性 - 修正案
🔴 **Critical**: `ファイル:行` - 認証不備 - 修正案
🟡 **Warning**: `ファイル:行` - セキュリティヘッダー不足 - 改善案

### エラーハンドリング
🔴 **Critical**: `ファイル:行` - エラー握りつぶし - 修正案
🔴 **Critical**: `ファイル:行` - センシティブ情報ログ - 修正案
🟡 **Warning**: `ファイル:行` - リトライ未実装 - 改善案

📊 **Summary**: Critical X件 / Warning Y件
```

---

## 関連ガイドライン

- `common/error-handling-patterns.md` - エラーハンドリングパターン
- `languages/typescript.md` - TypeScript特有のエラーハンドリング
- `languages/golang.md` - Go言語の型システムとエラーハンドリング

---

## 外部知識ベース

最新のセキュリティ情報確認には context7 を活用:
- OWASP Top 10 公式ドキュメント
- CWE（Common Weakness Enumeration）
- セキュアコーディングガイドライン
- NIST セキュリティガイドライン

---

## プロジェクトコンテキスト

プロジェクト固有の情報を確認:
- serena memory から認証方式・セキュリティ要件を取得
- プロジェクトの認証・認可パターンを優先
- ログ戦略（CloudWatch/Datadog/Sentry等）
- エラーコード体系
- 外部サービス連携時のリトライポリシー
