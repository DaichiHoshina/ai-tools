# OWASP Top 10 (2021) 詳細

## A01: Broken Access Control（アクセス制御の不備）

### 概要

ユーザーが許可された範囲を超えて行動できる脆弱性。

### 脆弱性パターン

- 直接オブジェクト参照（IDOR）
- パストラバーサル
- 権限昇格
- CORS設定ミス
- 強制ブラウジング

### 脆弱なコード例

```java
// ユーザーIDを信頼してしまう
pstmt.setString(1, request.getParameter("acct"));
ResultSet results = pstmt.executeQuery();
```

### 対策

- デフォルトで拒否（deny by default）
- アクセス制御をサーバーサイドで実装
- 直接オブジェクト参照を避ける（UUID使用）
- ディレクトリリスティングを無効化
- ファイルメタデータをダウンロード時に削除

---

## A02: Cryptographic Failures（暗号化の失敗）

### 概要

機密データの保護における暗号化の不備。

### 脆弱性パターン

- 平文でのデータ送信・保存
- 弱い暗号アルゴリズム（MD5, SHA1, DES）
- ハードコードされた暗号鍵
- 不適切な証明書検証

### CWE関連

| CWE ID | 名称 |
|--------|------|
| CWE-311 | Missing Encryption of Sensitive Data |
| CWE-312 | Cleartext Storage of Sensitive Information |
| CWE-319 | Cleartext Transmission of Sensitive Information |
| CWE-326 | Inadequate Encryption Strength |
| CWE-327 | Use of a Broken or Risky Cryptographic Algorithm |

### 対策

- TLS 1.2以上を使用
- HSTS（HTTP Strict Transport Security）を有効化
- パスワードは bcrypt/Argon2/scrypt でハッシュ
- 暗号鍵は環境変数・シークレットマネージャーで管理

---

## A03: Injection（インジェクション）

### 概要

信頼されていないデータがコマンド・クエリの一部として送信される脆弱性。

### 脆弱性パターン

- SQL インジェクション
- NoSQL インジェクション
- OS コマンドインジェクション
- LDAP インジェクション
- XPath インジェクション
- Expression Language インジェクション

### CWE関連

| CWE ID | 名称 |
|--------|------|
| CWE-77 | Command Injection |
| CWE-78 | OS Command Injection |
| CWE-79 | Cross-site Scripting (XSS) |
| CWE-89 | SQL Injection |
| CWE-90 | LDAP Injection |
| CWE-94 | Code Injection |

### 対策

詳細は [INJECTION.md](./INJECTION.md) を参照。

---

## A04: Insecure Design（安全でない設計）

### 概要

設計段階でのセキュリティ考慮の欠如。

### 脆弱性パターン

- 脅威モデリングの欠如
- セキュリティ要件の不在
- 信頼境界の不明確さ
- ビジネスロジックの欠陥

### 対策

- 開発ライフサイクルにセキュリティを組み込む
- 脅威モデリングを実施
- セキュリティ要件を明文化
- 参照アーキテクチャを使用

---

## A05: Security Misconfiguration（セキュリティ設定ミス）

### 概要

セキュリティ設定の不備・デフォルト設定の使用。

### 脆弱性パターン

- 不要な機能の有効化
- デフォルトアカウント・パスワード
- 詳細すぎるエラーメッセージ
- 最新パッチ未適用
- サーバーヘッダー情報の露出

### 対策

- 最小限の構成（不要な機能を無効化）
- 設定のハードニング
- 自動化されたセキュリティスキャン
- セグメント化されたアーキテクチャ

---

## A06: Vulnerable and Outdated Components（脆弱なコンポーネント）

### 概要

脆弱性のある・サポート切れのコンポーネントの使用。

### 対策

- 定期的な依存関係の監査
- 自動脆弱性スキャン（Dependabot, Snyk等）
- 未使用の依存関係を削除
- 公式ソースからのみ取得

---

## A07: Identification and Authentication Failures（認証の失敗）

### 概要

ユーザーの識別・認証における不備。

### 脆弱性パターン

- クレデンシャルスタッフィング許可
- ブルートフォース許可
- 弱いパスワード許可
- 平文・弱いハッシュでパスワード保存
- 多要素認証なし
- セッションID露出

詳細は [AUTH-SESSION.md](./AUTH-SESSION.md) を参照。

---

## A08: Software and Data Integrity Failures（データ整合性の失敗）

### 概要

コード・データの整合性検証の欠如。

### 脆弱性パターン

- 安全でないデシリアライゼーション
- CI/CDパイプラインのセキュリティ不備
- 自動更新の署名検証なし

### CWE関連

| CWE ID | 名称 |
|--------|------|
| CWE-502 | Deserialization of Untrusted Data |

### 対策

- デジタル署名の検証
- 依存関係の整合性チェック
- CI/CDパイプラインのセキュリティ強化

---

## A09: Security Logging and Monitoring Failures（ログ記録の失敗）

### 概要

セキュリティイベントのログ記録・監視の不備。

### 脆弱性パターン

- ログインの失敗がログされない
- 警告・エラーのログが不十分
- ログが監視されていない
- ログの保持期間が短い

### 対策

- 重要なセキュリティイベントをログ
- ログの改ざん防止
- 集中ログ管理
- アラートの設定

---

## A10: Server-Side Request Forgery (SSRF)

### 概要

サーバーが攻撃者指定のURLにリクエストを送信する脆弱性。

### 対策

- URL検証（ホワイトリスト方式）
- 内部ネットワークへのアクセス制限
- ファイアウォールでの制御
- DNS再バインディング対策
