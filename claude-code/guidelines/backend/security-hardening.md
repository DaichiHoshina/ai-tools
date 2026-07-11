# Security Hardening Guidelines

> **Purpose**: Reference for building authentication/authorization, rate limiting, secret management, and OWASP mitigations in production. For foundations, see `rules/enterprise-security.md`.

## Tier classification

| Tier | Content |
|------|---------|
| Tier 1 (required) | OWASP Top 10 countermeasures, authn/authz, secret management |
| Tier 2 (scale-dependent) | Rate limiting, mTLS, secret rotation |
| Tier 3 (advanced) | Certificate pinning, HSM, zero-trust |

---

## 1. OWASP Top 10 checklist

| ID | Threat | Countermeasure |
|----|--------|---------------|
| A01 | Broken Access Control | RBAC/ABAC, resource owner check |
| A02 | Cryptographic Failures | TLS 1.3, AES-256-GCM, bcrypt/argon2 |
| A03 | Injection (SQL/NoSQL/OS/LDAP) | Parameterized query, ORM, input validation |
| A04 | Insecure Design | Threat modeling, secure-by-default |
| A05 | Security Misconfiguration | Secrets in env, least privilege, CIS benchmark |
| A06 | Vulnerable Components | SBOM, Dependabot, regular audit |
| A07 | Identification & Auth Failures | MFA, password policy, session management |
| A08 | Software & Data Integrity | SRI, signature verification, CI/CD hardening |
| A09 | Logging & Monitoring Failures | Structured logging, SIEM integration |
| A10 | SSRF | URL allow-list, metadata endpoint deny |

---

## 2. Authentication

| Method | Use | Caution |
|--------|-----|---------|
| **JWT** | Stateless API | Hard to revoke (short TTL + refresh token) |
| **Session (cookie)** | Web UI | CSRF protection required, SameSite=Strict |
| **OAuth 2.1 / OIDC** | Third-party | PKCE required, verify state |
| **API Key** | Machine-to-machine | Rotation required, scope-limited |

**Password hash**: `argon2id` (recommended) or `bcrypt cost>=12`. **MD5 / SHA series forbidden**.

---

## 3. Authorization

| Pattern | Mechanism | Use |
|---------|-----------|-----|
| **RBAC** | Role → static permission | Clear organizational roles |
| **ABAC** | Attribute-based dynamic decision | Fine-grained (department/project level) |
| **ReBAC** (Zanzibar-style) | Relationship graph | Sharing/inheritance (Google Drive model) |

**Check rules**:
- Resource owner verification is required (`resource.owner_id == ctx.user_id`)
- Middleware handles authn; handler handles authz (do not mix)
- Failure → 403 (can use 404 to hide existence when preventing information leakage)

---

## 4. Secret management

| Placement | Use | Forbidden |
|-----------|-----|---------|
| **AWS Secrets Manager / Vault** | Production | Hardcode in code |
| **Environment variable (runtime injection)** | Dev/staging | Git commit |
| **K8s Secret + sealed-secrets** | Cluster | Base64 only = effectively plaintext |

**Rotation**:
- DB password: every 90 days; dual-credential period for zero-downtime cutover
- API key: every 6 months; key versioning for grace period
- TLS certificate: cert-manager auto-renewal

---

## 5. Rate limiting

| Algorithm | Mechanism | Use |
|-----------|-----------|-----|
| **Fixed Window** | Reset every N minutes | Simple; boundary burst weakness |
| **Sliding Window** (recommended) | Rolling past N seconds | Fair |
| **Token Bucket** | Replenish at fixed rate; allows burst | General API |
| **Leaky Bucket** | Drain at fixed rate | Smoothing |

**Multi-layer defense**:
- Per-IP (DDoS protection)
- Per-user (abuse prevention)
- Per-endpoint (restrict heavy APIs)

**429 response**:
```text
HTTP/1.1 429 Too Many Requests
Retry-After: 30
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1700000000
```

---

## 6. mTLS / Certificate Pinning

| Use | Application |
|-----|-------------|
| **mTLS** | Service mesh internal comms, B2B API |
| **Certificate Pinning** | Mobile app (man-in-the-middle protection) |
| **Public key pinning** | Easier pin rotation |

**Caution**: expired pin kills all clients → backup pin required.

---

## 7. Input validation and output encoding

| Type | Countermeasure |
|------|---------------|
| **SQL Injection** | Parameterized query, ORM, no raw SQL |
| **XSS** | Output encode (per HTML/JS context), CSP header |
| **CSRF** | SameSite=Strict, CSRF token, Origin/Referer check |
| **SSRF** | URL allow-list, block private IPs (10/8, 169.254/16, 127/8) |
| **Path Traversal** | Sanitize filenames, reject `..`/`/` |
| **XXE** | Disable external entities in XML parser |

---

## 8. Encryption

| Use | Algorithm |
|-----|-----------|
| **In transit** | TLS 1.3 (1.2 minimum) |
| **At rest (symmetric)** | AES-256-GCM |
| **Asymmetric** | RSA 4096 / ECDSA P-256 / Ed25519 |
| **Random number** | Crypto-secure RNG (`/dev/urandom`, `crypto.randomBytes`) |
| **Password** | argon2id / bcrypt cost>=12 |

**Forbidden**: MD5, SHA-1, DES, 3DES, RC4, ECB mode.

---

## 9. Session management

| Item | Recommendation |
|------|---------------|
| Cookie attributes | `Secure; HttpOnly; SameSite=Strict` |
| ID generation | Crypto-secure RNG, 128-bit minimum |
| Expiry | Sliding 30min, absolute 8h |
| Logout | Server-side revoke (blacklist) |
| MFA after sensitive operation | Re-authenticate for payment/password change |

---

## 10. Audit log

**Required events**:
- Authentication success/failure
- Permission change
- Sensitive data access (PII, payment)
- Configuration change
- Data deletion

**Format**: structured, tamper-evident (write-once, hash chain recommended).

---

## 11. Vulnerability management

- Generate SBOM (CycloneDX, SPDX)
- Daily audit via Dependabot / Renovate
- Critical CVE: respond within 24 hours
- Penetration testing: at least once per year

---

## 12. References

- OWASP Top 10: 2025 edition (2026-01 final release。Broken Access Control が #1 継続、Software Supply Chain Failures / Mishandling of Exceptional Conditions が新規)
- Related: `rules/enterprise-security.md` (foundations), `backend/observability-design.md` (audit log integration), `backend/multi-tenancy.md` (tenant isolation, RLS)
