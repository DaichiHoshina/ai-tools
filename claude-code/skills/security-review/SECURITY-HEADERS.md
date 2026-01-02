# HTTP セキュリティヘッダー

## 必須ヘッダー

### Content-Security-Policy (CSP)

XSSやデータインジェクション攻撃を軽減する**第二の防御層**。

**基本設定:**
```http
Content-Security-Policy: default-src 'self'; script-src 'nonce-{random}'; object-src 'none'; base-uri 'none'
```

**厳格な設定:**
```http
Content-Security-Policy:
  default-src 'self';
  script-src 'nonce-{random}';
  style-src 'self' 'nonce-{random}';
  img-src 'self' data: https:;
  font-src 'self';
  object-src 'none';
  base-uri 'none';
  form-action 'self';
  frame-ancestors 'none';
  upgrade-insecure-requests
```

| ディレクティブ | 説明 |
|----------------|------|
| `default-src` | デフォルトのソースポリシー |
| `script-src` | JavaScriptの読み込み元 |
| `style-src` | CSSの読み込み元 |
| `img-src` | 画像の読み込み元 |
| `object-src 'none'` | Flash等のプラグイン禁止 |
| `base-uri 'none'` | base要素の悪用防止 |
| `frame-ancestors 'none'` | クリックジャッキング防止 |

**Nonce の使用:**
```html
<!-- サーバーで毎回ランダムなnonceを生成 -->
<script nonce="r4nd0m">
  // 信頼できるスクリプト
</script>
```

---

### X-Content-Type-Options

MIMEタイプのスニッフィングを防止。

```http
X-Content-Type-Options: nosniff
```

---

### X-Frame-Options

クリックジャッキング攻撃を防止。

```http
X-Frame-Options: DENY
```

| 値 | 説明 |
|----|------|
| `DENY` | 全てのフレーム埋め込み禁止 |
| `SAMEORIGIN` | 同一オリジンのみ許可 |

**注**: CSPの `frame-ancestors` が優先されるが、後方互換性のため両方設定推奨。

---

### Strict-Transport-Security (HSTS)

HTTPS接続を強制。

```http
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

| パラメータ | 説明 |
|------------|------|
| `max-age` | HTTPS強制期間（秒）。1年以上推奨 |
| `includeSubDomains` | サブドメインも対象 |
| `preload` | ブラウザのプリロードリストに登録 |

---

### Referrer-Policy

リファラー情報の送信を制御。

```http
Referrer-Policy: no-referrer
```

| 値 | 説明 |
|----|------|
| `no-referrer` | リファラーを送信しない |
| `strict-origin-when-cross-origin` | クロスオリジンではオリジンのみ |
| `same-origin` | 同一オリジンでのみ送信 |

**危険な設定:**
```http
Referrer-Policy: unsafe-url  ← 禁止
```

---

### Permissions-Policy (旧 Feature-Policy)

ブラウザ機能へのアクセスを制御。

```http
Permissions-Policy: geolocation=(), camera=(), microphone=(), payment=()
```

---

## CORS設定

### 安全な設定

```http
Access-Control-Allow-Origin: https://trusted.example.com
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: GET, POST
Access-Control-Allow-Headers: Content-Type, Authorization
```

### 危険な設定

```http
Access-Control-Allow-Origin: *  ← 危険
Access-Control-Allow-Credentials: true  ← * と組み合わせ禁止
```

**ワイルドカードは認証不要のパブリックAPIのみで使用。**

---

## Cookie設定

### 最もセキュアな設定

```http
Set-Cookie: __Host-SID=<token>; path=/; Secure; HttpOnly; SameSite=Strict
```

### 属性の説明

| 属性 | 必須 | 説明 |
|------|------|------|
| `Secure` | Yes | HTTPS接続でのみ送信 |
| `HttpOnly` | Yes | JavaScriptからアクセス不可（XSS対策） |
| `SameSite=Strict` | Yes | クロスサイトリクエストで送信しない（CSRF対策） |
| `path=/` | Yes | 適切なパスに制限 |
| `__Host-` プレフィックス | 推奨 | 最も厳格な設定を強制 |

### SameSite 値

| 値 | 説明 |
|----|------|
| `Strict` | クロスサイトでは一切送信しない |
| `Lax` | トップレベルナビゲーションのみ送信 |
| `None` | 常に送信（Secure必須） |

---

## 推奨ヘッダー設定一覧

```http
# 必須
Content-Security-Policy: default-src 'self'; script-src 'nonce-{random}'; object-src 'none'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: no-referrer

# 推奨
Permissions-Policy: geolocation=(), camera=(), microphone=()
X-Permitted-Cross-Domain-Policies: none
Cache-Control: no-store

# 削除すべき（情報漏洩）
# X-Powered-By: Express
# Server: Apache/2.4.1
```

---

## チェックリスト

### ヘッダー設定

- [ ] CSPが設定されているか
- [ ] X-Content-Type-Options: nosniff が設定されているか
- [ ] X-Frame-Options が設定されているか
- [ ] HSTS が設定されているか（HTTPS必須）
- [ ] Referrer-Policy が適切か
- [ ] サーバー情報ヘッダーを削除しているか

### Cookie設定

- [ ] Secure属性が設定されているか
- [ ] HttpOnly属性が設定されているか
- [ ] SameSite属性が設定されているか
- [ ] セッションCookieに__Host-プレフィックスを使用しているか

### CORS設定

- [ ] Access-Control-Allow-Originがワイルドカードでないか
- [ ] 認証付きエンドポイントで適切なオリジン検証をしているか
