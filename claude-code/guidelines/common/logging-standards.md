# Logging Standards

Standards for log level usage and structured field design. Reference when adding new logs or reviewing existing ones.

## Principles

**Short English messages + structured fields — sufficient. What to record matters more than language.** Do not use debug level.

## Levels

| Level | Purpose | Example |
|-------|---------|---------|
| error | Processing cannot continue; immediate action required. Includes unreachable paths | DB connection failure, external API failure, switch default reached, unhandled enum value |
| warn | Abnormal but processing can continue; needs monitoring | authz.denied, ID-specified NotFound (context-dependent), rate_limited |
| info | Important events in the normal flow | Request start/completion, state transition, batch processing result |

**When in doubt**: normal flow → info; abnormal but expected → warn. Even with fallback, rare events should be warn or above (using info risks missing the anomaly).

### Unhandled Data → Error

When reaching a switch default or unknown type, use **Error** even if processing continues with a fallback. Reason: the code should handle this data; developer action is required.

| Pattern | Level | Example |
|---------|-------|---------|
| Unknown type/enum (switch default reached) | error | unknown carrier type, unknown EC provider, unknown service level |
| DB connection failure (service non-functional) | error | DB connection retry |
| External connection failure → recoverable via retry | warn | SFTP/SSH connection retry |
| Has fallback but rarely occurs | warn | JSON unmarshal failure → default value used, SFTP delete failure → continue |
| Async processing wait/polling | info | Waiting for PDF generation retry, batch type ignored |

## Required Fields

| Category | Fields |
|----------|--------|
| All logs | msg, event, request_id/trace_id, duration_ms, result |
| On error | error (with stack), error_type, error_code |
| HTTP | method, path, status |
| Domain | resource_type, resource_id |
| Multi-tenant | tenant_id/owner_id |

## NotFound Decision

List search with 0 results: no log needed. ID-specified NotFound: warn based on context (event: `resource.get.not_found`, suspicion: `possible_id_probe`)

## Security Events That Should Be warn

`authz.denied`, `resource.get.not_found`, `validation.failed`, `rate_limited`, `auth.login_failed`

## Forbidden (do not include in logs)

password, token, Cookie, Authorization header, raw PII (mask/hash required), entire request body (use body_hash instead)
