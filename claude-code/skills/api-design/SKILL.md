---
allowed-tools: Read, Glob, Grep
name: api-design
description: API design (REST/GraphQL): versioning, errors, docs. Use when designing APIs. — 実装は backend-dev を使う
requires-guidelines:
  - common
  - clean-architecture
---

# api-design - API Design

## Review Perspectives

### 🔴 Critical (Fix Required)

| Perspective | Detection | Fix |
|------|-------------|------|
| Resource design violation | Verb-based URL (`/createUser`) | Resource noun + HTTP method |
| Status code misuse | 200 even on error | Correct status code |
| Error format inconsistent | Mixed JSON structures | RFC 7807 Problem Details |

### 🟡 Warning (Improve)

| Perspective | Detection | Fix |
|------|-------------|------|
| Versioning not implemented | Fixed `/api/users` | `/api/v1/users` or header |
| Pagination missing | Fetch all | Cursor-based pagination |
| No rate limiting | Auth API unlimited | express-rate-limit etc |

**Need code examples**: Search Context7 for "REST API design", "GraphQL best practices"

---

## REST API Patterns

### Resource Design

| Pattern | URL | Method | Use |
|---------|-----|---------|------|
| Collection | `/users` | GET/POST | List/create |
| Single | `/users/123` | GET/PUT/PATCH/DELETE | CRUD |
| Sub-resource | `/users/123/posts` | GET | Related get |

### API Granularity Decision (New vs Extend)

Always decide before adding endpoint.

| Situation | Recommended | Reason |
|------|------|------|
| Similar existing, add query param | Extend existing (query/header) | Avoid URL explosion |
| Similar but different response | New endpoint | Separation of concerns |
| Same resource, different ops | Same URL, method/param split | RESTful, searchable |
| Different resource, related | Sub-resource `/parent/:id/child` | Show relationship |
| Aggregate/stats (cross-resource) | `/stats/...`, `/reports/...` namespace | Separation |
| Multiple ops, 1 request | Batch `/batch` | Reduce round-trips |
| Client-specific optimize | BFF (Backend-For-Frontend) layer | Server API stays generic |

**Antipatterns**:
- ❌ `/createUser`, `/updateUser`, `/deleteUser` verb-based → ⭕ `/users` + HTTP method
- ❌ 1 use-case 1 endpoint spam → ⭕ Extend existing (data op granularity, not UI action)

**Details**: Follow `~/.claude/references/on-demand-rules/api-design.md` (no UI aggregate values embedded, etc)

### Status Code Decision Table

| Code | Name | Use |
|--------|------|---------|
| **200** | OK | Normal success (GET/PUT/PATCH) |
| **201** | Created | Resource created (POST, Location recommended: RFC 9110 SHOULD) |
| **202** | Accepted | Async process accepted (not immediately complete) |
| **204** | No Content | Success, no body (DELETE) |
| **301/302/307** | Redirect | URL change notification |
| **400** | Bad Request | Request format error (validation fail) |
| **401** | Unauthorized | Auth missing/invalid |
| **403** | Forbidden | Auth OK, permission denied |
| **404** | Not Found | Resource missing (also for auth hiding) |
| **405** | Method Not Allowed | Unsupported method (Allow header required: RFC 9110 MUST) |
| **409** | Conflict | Conflict (optimistic lock fail, duplicate) |
| **410** | Gone | Permanently deleted (distinct from 404) |
| **422** | Unprocessable Entity | Format OK, semantic error (business rule) |
| **429** | Too Many Requests | Rate limit exceeded (Retry-After recommended: RFC 6585 MAY) |
| **500** | Internal Server Error | Server error (hide details) |
| **502/503/504** | Gateway/Unavailable/Timeout | Upstream failure, Retry-After recommended |

**Boundary decisions**:
- **400 vs 422**: Syntax error (JSON parse fail) = 400, syntax OK semantic error (business rule) = 422
- **403 vs 404**: Can reveal authz failure = 403. Hide resource existence (other org, authz level) = 404
- **404 vs 410**: Explicitly "gone" (prevent retry) = 410, unknown = 404

---

## GraphQL Patterns

| Perspective | Rule | Note |
|------|--------|------|
| Naming & type | Consistent naming, explicit types | Unify snake_case / camelCase across schema |
| Pagination | Connection pattern (Relay spec) | `edges` / `pageInfo` / `cursor` |
| N+1 fix | Batch via DataLoader | No direct queries in resolvers |
| Null design | Mark required/optional in schema | Default nullable, required = `!` |
| Common | Auth, authz, CORS, docs, security headers | Same as REST, persistedQueries recommended |

---

## Output Format

Normal case:

```
🔴 Critical: endpoint - problem - fix
🟡 Warning: endpoint - problem - improvement
📊 Summary: Critical X / Warning Y
```

Zero findings:

```
🔴 Critical: 0
🟡 Warning: 0
📊 Summary: No findings (N endpoints / N schemas)
```

No review target (API definition not found):

```
> [WARN] OpenAPI / GraphQL schema not found. Skip review.
> Search: openapi.yaml / *.graphql / *Controller.{ts,go,py} / routes/*
```

External references: Context7 for OpenAPI 3.x / GraphQL official / Google/Microsoft API Design Guide / RFC 7807 (fetch fail → fallback to knowledge cutoff, warning log)
