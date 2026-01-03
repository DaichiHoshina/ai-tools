# 認証・セッション管理

## 認証の脆弱性

### 脆弱性の兆候

| 問題 | 説明 |
|------|------|
| 自動化攻撃許可 | クレデンシャルスタッフィング・ブルートフォースを防げない |
| 弱いパスワード許可 | "Password1", "admin/admin" 等を受け入れる |
| 弱い復旧プロセス | 「秘密の質問」等の知識ベース認証 |
| 平文/弱いハッシュ | パスワードが平文・暗号化・弱いハッシュで保存 |
| MFA なし | 多要素認証が実装されていない |
| セッションID露出 | URLにセッションIDが含まれる |
| セッション無効化なし | ログアウト・アイドル時にセッションが残る |

---

## 認証の対策

### 多要素認証（MFA）

```
必須シナリオ:
- 管理者アカウント
- 高権限操作
- 機密データアクセス
- 金融取引
```

### パスワードポリシー

**NIST 800-63B ガイドライン準拠:**

```
推奨設定:
- 最小長: 8文字（ユーザー）/ 15文字（管理者）
- 最大長: 64文字以上を許可
- 文字種制限: 不要（複雑さより長さ）
- 定期変更: 不要（漏洩時のみ）
- 弱いパスワードチェック: 必須
```

### 弱いパスワードチェック

```python
# Top 10000 の弱いパスワードリストと照合
def is_weak_password(password: str) -> bool:
    weak_passwords = load_weak_password_list()
    return password.lower() in weak_passwords
```

### パスワードハッシュ

```
推奨アルゴリズム（優先順）:
1. Argon2id（メモリハード）
2. bcrypt（コスト係数 10以上）
3. scrypt
4. PBKDF2-HMAC-SHA256（反復 310,000回以上）

禁止:
- MD5
- SHA1
- SHA256（単純ハッシュ）
```

### ログイン試行制限

```python
# レート制限の実装例
def check_login_attempts(username: str) -> bool:
    attempts = get_failed_attempts(username, window_minutes=15)
    if attempts >= 5:
        delay_seconds = min(2 ** attempts, 3600)  # 最大1時間
        sleep(delay_seconds)
        return False
    return True
```

### アカウント列挙防止

```
同一レスポンス:
- 「ユーザー名が存在しません」 ← 漏洩
- 「パスワードが間違っています」 ← 漏洩
- 「認証情報が正しくありません」 ← 安全
```

---

## セッション管理

### セッションID生成

```
要件:
- 高エントロピー（128bit以上）
- 暗号論的乱数生成器を使用
- 予測不可能であること
```

### セッションIDのライフサイクル

```
1. ログイン成功時 → 新しいセッションIDを発行
2. 権限変更時 → セッションIDを再生成
3. ログアウト時 → セッションを完全に無効化
4. アイドルタイムアウト → セッションを無効化
5. 絶対タイムアウト → セッションを無効化
```

### Cookie設定

**最もセキュアな設定:**

```http
Set-Cookie: __Host-SID=<session-token>; path=/; Secure; HttpOnly; SameSite=Strict
```

| 属性 | 説明 |
|------|------|
| `__Host-` プレフィックス | Secure必須、パス=/必須、Domain禁止 |
| `Secure` | HTTPS接続でのみ送信 |
| `HttpOnly` | JavaScriptからアクセス不可 |
| `SameSite=Strict` | クロスサイトリクエストで送信しない |
| `path=/` | 全パスで有効 |

### セッション固定攻撃対策

```java
// ログイン成功後にセッションを再生成
HttpSession oldSession = request.getSession(false);
if (oldSession != null) {
    oldSession.invalidate();
}
HttpSession newSession = request.getSession(true);
newSession.setAttribute("user", authenticatedUser);
```

---

## OAuth/OIDC セキュリティ

### PKCE（Proof Key for Code Exchange）

SPAやモバイルアプリでは必須：

```
フロー:
1. code_verifier（ランダム文字列）を生成
2. code_challenge = SHA256(code_verifier)
3. 認可リクエストに code_challenge を含める
4. トークンリクエストに code_verifier を含める
```

### リダイレクトURI検証

```
要件:
- 完全一致で検証（ワイルドカード禁止）
- ホワイトリスト方式
- localhost は開発環境のみ
```

### クリックジャッキング対策

```http
X-Frame-Options: DENY
Content-Security-Policy: frame-ancestors 'none'
```

---

## チェックリスト

### 認証

- [ ] MFAを実装しているか
- [ ] 弱いパスワードをチェックしているか
- [ ] パスワードは適切にハッシュしているか
- [ ] ログイン試行を制限しているか
- [ ] アカウント列挙を防いでいるか
- [ ] デフォルトパスワードは存在しないか

### セッション

- [ ] セッションIDは十分なエントロピーか
- [ ] ログイン後にセッションIDを再生成しているか
- [ ] ログアウトでセッションを無効化しているか
- [ ] Cookie属性は適切か（Secure, HttpOnly, SameSite）
- [ ] アイドル・絶対タイムアウトがあるか
- [ ] セッションIDがURLに露出していないか

### OAuth/OIDC

- [ ] PKCEを使用しているか
- [ ] リダイレクトURIを厳密に検証しているか
- [ ] stateパラメータでCSRF対策しているか
- [ ] nonceパラメータでリプレイ攻撃対策しているか
