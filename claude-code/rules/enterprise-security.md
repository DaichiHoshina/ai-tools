---
paths:
  - "**/*"
---
# Enterprise Security Rules

## 1. Secret Leak Prevention

**Strictly forbidden** (responses excluded): API keys / tokens / passwords / cloud credentials / SSH private keys / TLS certs / `.env` / env dumps (env, printenv, set)

Detection: mask with `[REDACTED: type]` + notify user "secret info masked"

## 2. Pre-commit Git Check

Detect and **warn + stop** on:

| Pattern | Type |
|---------|-----|
| `AKIA[0-9A-Z]{16}` | AWS Access Key |
| `ghp_[a-zA-Z0-9]{36}` | GitHub PAT |
| `sk-[a-zA-Z0-9]{48}` | OpenAI/Anthropic Key |
| `xoxb-`, `xoxp-` | Slack Token |
| `-----BEGIN.*PRIVATE KEY-----` | Private Key |
| 64+ char Base64 continuous alphanum | Encoded secret |

**Code-enforced (hook layer, not LLM judgment)**:
- Input: `hooks/pre-tool-use.sh` inspects Write/Edit input, blocks on detection
- Output: `hooks/post-tool-use.sh` passes Bash `tool_response.stdout` through `lib/output-sanitizer.sh` for `[REDACTED]` replacement (Phase 1, top-5 patterns, updates `hookSpecificOutput.updatedToolOutput` + notifies Claude via `additionalContext`)

## 3. Cloud Metadata Protection (SSRF Prevention)

Forbidden access: `169.254.169.254` (AWS/Azure) / `metadata.google.internal` (GCP) / `100.100.100.200` (Alibaba)

- **Primary defense**: `permissions.deny` with `Bash(curl*169.254*)` etc
- **Secondary defense**: sandbox-only `sandbox.network.deniedDomains` (activated via `claude --sandbox`, worktree isolation, `EnterWorktree`)

## 4. MCP / External API Data Classification

| Category | Examples | Handling |
|------|------|---------|
| Forbidden | PII, auth secrets, private messages | Do not fetch |
| Restricted | Source code, internal API specs | Context only, confirm on file save |
| Internal | Metric aggregates, dashboard defs | Fetch OK, no external share |
| Public | Published docs, OSS code | No restrictions |

## 5. Output Sanitization

Auto-masked: internal IPs (10.x / 172.16-31.x / 192.168.x) / corporate email / AWS account ID (12 digits) / DB connection strings

## 6. PII Protection (MCP / External API)

Conversations sent to Anthropic API; external tool data treated as input.

- Do not fetch PII (user_id / IP / email / phone) via MCP
- No raw individual records (aggregate only: count, GROUP BY, SUM)
- Individual user investigation → direct to tool UI URL
- File save → anonymize (User-A, User-B style)

**Per-MCP**: Datadog no `extra_fields` PII / Slack DMs forbidden / Notion private page expansion forbidden
