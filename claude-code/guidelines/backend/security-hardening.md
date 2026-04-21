# セキュリティ硬化 ガイドライン

本番運用で必要な認証/認可、rate limit、secret管理、OWASP対策を構築する時に参照。基礎は `rules/enterprise-security.md` 参照。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | OWASP Top 10対策、authn/authz、secret管理 |
| Tier 2（規模別） | rate limiting、mTLS、secret rotation |
| Tier 3（深掘り） | certificate pinning、HSM、zero-trust |

---

## 1. OWASP Top 10 対策チェック表

| ID | 脅威 | 対策 |
|----|------|------|
| A01 | Broken Access Control | RBAC/ABAC、resource owner check |
| A02 | Cryptographic Failures | TLS 1.3、AES-256-GCM、bcrypt/argon2 |
| A03 | Injection（SQL/NoSQL/OS/LDAP） | parameterized query、ORM 使用、input validation |
| A04 | Insecure Design | threat modeling、secure-by-default |
| A05 | Security Misconfiguration | secret in env、最小権限、CIS benchmark |
| A06 | Vulnerable Components | SBOM、Dependabot、定期 audit |
| A07 | Identification & Auth Failures | MFA、PW policy、session management |
| A08 | Software & Data Integrity | SRI、署名検証、CI/CD 防御 |
| A09 | Logging & Monitoring Failures | 構造化ログ、SIEM 連携 |
| A10 | SSRF | URL allow-list、metadata endpoint deny |

---

## 2. 認証（Authentication）

| 方式 | 用途 | 注意 |
|------|------|------|
| **JWT** | stateless API | 失効困難（短TTL + refresh token） |
| **Session（cookie）** | Web UI | CSRF対策必須、SameSite=Strict |
| **OAuth 2.1 / OIDC** | サードパーティ | PKCE 必須、state 検証 |
| **API Key** | machine-to-machine | rotation必須、scope限定 |

**PW hash**: `argon2id`（推奨）or `bcrypt cost>=12`。**SHA系・MD5禁止**。

---

## 3. 認可（Authorization）

| パターン | 仕組み | 適用 |
|---------|--------|------|
| **RBAC** | role → permission 静的 | 組織ロール明確 |
| **ABAC** | 属性ベース動的判定 | 細粒度（部門/案件単位） |
| **ReBAC**（Zanzibar型） | リレーションシップグラフ | 共有/継承（Google Drive型） |

**チェック原則**:
- リソース owner 検証は必須（`resource.owner_id == ctx.user_id`）
- middleware で auth、handler で authz（混同しない）
- 失敗時は 403（404 で隠す手法もあり、漏洩防止）

---

## 4. Secret 管理

| 配置 | 適用 | 禁止 |
|------|------|------|
| **AWS Secrets Manager / Vault** | 本番 | コードに hardcode |
| **環境変数（runtime注入）** | dev/stg | git commit |
| **K8s Secret + sealed-secrets** | クラスタ | base64 のみは平文同等 |

**rotation**:
- DB password: 90日毎、dual-credential 期間設けてダウンタイム0
- API key: 半年毎、key versioning で gracePeriod
- TLS 証明書: cert-manager 自動更新

---

## 5. Rate Limiting

| アルゴリズム | 仕組み | 適用 |
|-------------|--------|------|
| **Fixed Window** | 1分毎 reset | 簡素、境界 burst 弱い |
| **Sliding Window**（推奨） | 過去 N 秒を rolling | 公平 |
| **Token Bucket** | 一定速度で token 補充、burst 許可 | 通常 API |
| **Leaky Bucket** | 一定速度で消費 | 平準化 |

**多層防御**:
- IP 単位（DDoS防御）
- user 単位（abuse 防止）
- endpoint 単位（重い API の制限）

**429 応答**:
```
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1700000000
```

---

## 6. mTLS / Certificate Pinning

| 用途 | 適用 |
|------|------|
| **mTLS** | service mesh 内通信、B2B API |
| **Certificate Pinning** | mobile app（中間者攻撃対策） |
| **public key pinning** | pin の rotation 容易 |

**注意**: pin 失効で全 client 死亡 → backup pin 必須。

---

## 7. Input Validation & Output Encoding

| 種別 | 対策 |
|------|------|
| **SQL Injection** | parameterized query、ORM、生 SQL 禁止 |
| **XSS** | output encode（HTML/JS context別）、CSP header |
| **CSRF** | SameSite=Strict、CSRF token、Origin/Referer 検証 |
| **SSRF** | URL allow-list、private IP block（10/8, 169.254/16, 127/8） |
| **Path Traversal** | ファイル名 sanitize、`..`/`/` 拒否 |
| **XXE** | XML parser で external entity 無効化 |

---

## 8. 暗号化

| 用途 | アルゴリズム |
|------|-------------|
| **転送中** | TLS 1.3（1.2 最低） |
| **保存時 対称** | AES-256-GCM |
| **非対称** | RSA 4096 / ECDSA P-256 / Ed25519 |
| **乱数** | crypto-secure RNG（`/dev/urandom`、`crypto.randomBytes`） |
| **PW** | argon2id / bcrypt cost>=12 |

**禁止**: MD5、SHA-1、DES、3DES、RC4、ECB mode。

---

## 9. セッション管理

| 項目 | 推奨 |
|------|------|
| Cookie 属性 | `Secure; HttpOnly; SameSite=Strict` |
| ID生成 | crypto-secure RNG、128bit以上 |
| 有効期限 | sliding 30min、絶対 8h |
| ログアウト | server側で revoke（blacklist） |
| MFA after sensitive op | 決済/PW変更で再認証 |

---

## 10. 監査ログ（Audit Log）

**記録必須イベント**:
- 認証成功/失敗
- 権限変更
- 機密データ参照（PII、決済）
- 設定変更
- データ削除

**フォーマット**: 構造化、改ざん防止（write-once、ハッシュチェーン推奨）。

---

## 11. 脆弱性管理

- SBOM 生成（CycloneDX、SPDX）
- Dependabot / Renovate で日次 audit
- 重大 CVE は 24h 以内対応
- ペネトレーションテスト 年1回以上

---

## 12. 参考

- OWASP Top 10: 2021版（2026更新予定）
- 関連: `rules/enterprise-security.md`（基礎）, `backend/observability-design.md`（監査ログ統合）
