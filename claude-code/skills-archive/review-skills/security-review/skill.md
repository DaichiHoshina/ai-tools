---
name: security-review
description: セキュリティレビュー - OWASP Top 10、インジェクション対策、認証・セッション管理、セキュリティヘッダーの観点からコードをレビュー
requires-guidelines:
  - common
---

# セキュリティレビュー

## 目次

このスキルは以下のファイルで構成されています：

- **skill.md** (このファイル): 概要と使用タイミング
- **[OWASP-TOP10.md](./OWASP-TOP10.md)**: OWASP Top 10 脆弱性と対策
- **[INJECTION.md](./INJECTION.md)**: インジェクション攻撃の防止
- **[AUTH-SESSION.md](./AUTH-SESSION.md)**: 認証・セッション管理
- **[SECURITY-HEADERS.md](./SECURITY-HEADERS.md)**: HTTPセキュリティヘッダー
- **[CHECKLIST.md](./CHECKLIST.md)**: セキュリティチェックリスト

## 使用タイミング

- **コードレビュー時（セキュリティ観点の確認）**
- **新機能実装時（セキュアコーディング）**
- **API設計時（認証・認可の設計）**
- **脆弱性修正時（適切な対策の実装）**

## 基本原則

### Defense in Depth（多層防御）

単一の防御に頼らず、複数の防御層を設ける：

```
1. 入力検証（Input Validation）
   ↓
2. パラメータ化クエリ（Parameterized Queries）
   ↓
3. 出力エンコーディング（Output Encoding）
   ↓
4. セキュリティヘッダー（Security Headers）
```

### Principle of Least Privilege（最小権限の原則）

必要最小限の権限のみを付与：

- データベース接続は読み取り専用が可能なら読み取り専用で
- APIキーのスコープは必要最小限に
- ファイルアクセス権限は制限的に

## OWASP Top 10 (2021)

> **Note**: 2025年版がリリース済み。最新情報は context7 MCPで確認してください。

| ランク | カテゴリ | 概要 |
|--------|----------|------|
| A01 | Broken Access Control | アクセス制御の不備 |
| A02 | Cryptographic Failures | 暗号化の失敗 |
| A03 | Injection | インジェクション攻撃 |
| A04 | Insecure Design | 安全でない設計 |
| A05 | Security Misconfiguration | セキュリティ設定ミス |
| A06 | Vulnerable Components | 脆弱なコンポーネント |
| A07 | Auth Failures | 認証の失敗 |
| A08 | Data Integrity Failures | データ整合性の失敗 |
| A09 | Logging Failures | ログ記録の失敗 |
| A10 | SSRF | サーバーサイドリクエストフォージェリ |

詳細は [OWASP-TOP10.md](./OWASP-TOP10.md) を参照してください。

## 最重要：インジェクション対策

### SQL インジェクション

**危険なコード:**
```java
// 絶対にやってはいけない
String query = "SELECT * FROM users WHERE id = '" + userId + "'";
```

**安全なコード:**
```java
// PreparedStatement を使用
String query = "SELECT * FROM users WHERE id = ?";
PreparedStatement pstmt = connection.prepareStatement(query);
pstmt.setString(1, userId);
ResultSet results = pstmt.executeQuery();
```

詳細は [INJECTION.md](./INJECTION.md) を参照してください。

## 認証・セッション管理

### 脆弱性の兆候

- 自動化攻撃（クレデンシャルスタッフィング、ブルートフォース）を許可
- デフォルトパスワードや弱いパスワードを許可
- 平文や弱いハッシュでパスワードを保存
- 多要素認証がない
- セッションIDがURLに露出
- ログアウト時にセッションを無効化しない

### 対策

- 多要素認証の実装
- 弱いパスワードのチェック（Top 10000 リスト）
- ログイン試行の制限・遅延
- セッションIDはログイン後に再生成
- ログアウト・タイムアウト時のセッション無効化

詳細は [AUTH-SESSION.md](./AUTH-SESSION.md) を参照してください。

## セキュリティヘッダー

### 必須ヘッダー

```http
Content-Security-Policy: default-src 'self'; script-src 'nonce-{random}'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: no-referrer
```

### Cookie設定

```http
Set-Cookie: __Host-SID=<token>; path=/; Secure; HttpOnly; SameSite=Strict
```

詳細は [SECURITY-HEADERS.md](./SECURITY-HEADERS.md) を参照してください。

## クイックチェックリスト

### コードレビュー時

- [ ] ユーザー入力は検証されているか
- [ ] SQLクエリはパラメータ化されているか
- [ ] 出力はエンコードされているか
- [ ] 認証・認可は適切か
- [ ] 機密情報はログに出力されていないか
- [ ] エラーメッセージに機密情報が含まれていないか

### API設計時

- [ ] 認証は必須か
- [ ] レート制限はあるか
- [ ] 入力サイズ制限はあるか
- [ ] HTTPS強制か

完全なチェックリストは [CHECKLIST.md](./CHECKLIST.md) を参照してください。

## 関連ガイドライン

レビュー実施前に以下のガイドラインを参照:
- `~/.claude/guidelines/common/error-handling-patterns.md`
- `~/.claude/guidelines/languages/typescript.md`（TypeScriptプロジェクトの場合）
- `~/.claude/guidelines/languages/golang.md`（Goプロジェクトの場合）

## 外部知識ベース

最新のセキュリティベストプラクティス確認には context7 を活用:
- OWASP Top 10 公式ドキュメント
- CWE（Common Weakness Enumeration）
- セキュアコーディングガイドライン

## プロジェクトコンテキスト

プロジェクト固有のセキュリティ情報を確認:
- serena memory から認証方式・セキュリティ要件を取得
- プロジェクトの認証・認可パターンを優先
- 既存のセキュリティ対策との一貫性を確認
