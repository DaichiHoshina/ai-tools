---
name: incident-response
description: Incident response: error→impact→cause→ticket→doc. Use when responding.
requires-guidelines:
  - operations
---

# incident-response - Incident Response Skill

## Infrastructure Failure Quick Diagnosis

### 403 Forbidden

| Check Order | Item | Command |
|-----------|---------|-----------|
| 1 | IAM role/permission | `aws iam simulate-principal-policy` |
| 2 | ALB/API Gateway rule | ALB console → check rule |
| 3 | CORS header | `curl -v -X OPTIONS <URL>` |
| 4 | Service account | `kubectl describe sa <name>` |
| 5 | Recent deploy change | `git log --oneline -10` / ArgoCD |

### Worker Startup Failure

| Check Order | Item | Command |
|-----------|---------|-----------|
| 1 | Pod status | `kubectl get pods -n <ns>` |
| 2 | Startup log | `kubectl logs <pod> --previous` |
| 3 | Resource shortage | `kubectl describe node` |
| 4 | ConfigMap/Secret | `kubectl describe pod <pod>` → Events |
| 5 | DB connect/external dep | Health check on target service |

> If repeating, run root cause analysis (`/root-cause`), always propose permanent fix.

## Response Flow

```
Receive error → Execute Step 1-5 in order
```

### Step 1: Classify

| Classification | Criteria | Next |
|------|---------|-------------|
| Known, Expected | Auth fail (unregistered email), rate limit | Report to user & done |
| Known, Requires Action | Config error, resource shortage, service down | Proceed to Step 2 |
| Unknown | Never seen this error | Proceed to Step 2 (elevate priority) |
| Unclassifiable | Missing info (no stack trace, no logs) | Request info from user & stop |

### Step 2: Impact Scope

| Level | Condition | Response Time |
|--------|------|---------|
| Critical | Prod user affected, data mismatch | Immediate |
| High | Prod feature down, test env down | Same day |
| Medium | Prod log error only, test partial fail | Next sprint |
| Low | Dev only, warning level | Backlog |

### Step 3: Root Cause Identification

1. Extract stack trace / error code from logs; cross-check related services (k8s pods/logs)
2. Verify recent deploy / config changes (`git log` / ArgoCD); identify root cause (no band-aids → `/root-cause`)

If investigation drags, re-output every 3 steps: "confirmed / unconfirmed / next action / decision needed".

### Step 4: Create Ticket

Use Jira MCP (`mcp__jira__jira_post`). Required fields:

| Field | Rule |
|-------|------|
| summary | `[Impact Level] summary`, <80 chars |
| description | PREP 3: conclusion=action / reason=symptom+scope+cause / next=owner+deadline |
| priority | Matches impact level |
| labels | `["incident"]` |

**Must pass self-check** before post (`~/.claude/guidelines/writing/PRINCIPLES.md` "4 questions"). Detailed logs in `<details>` fold.

MCP failure → include ticket body as draft in output, guide user to manual post.

### Step 5: Document

Create incident record with Confluence MCP (`mcp__confluence__conf_post`), notify Slack if needed.

MCP failure → save locally as `incidents/{YYYY-MM-DD}-{topic}.md`, guide manual upload later.

## Output Format

Normal case:

```markdown
## Incident Report

| Item | Content |
|------|------|
| Classification | Known/Unknown |
| Impact Level | Critical/High/Medium/Low |
| Environment | dev/test/prod |
| Time | YYYY-MM-DD HH:MM |

### Error
(log excerpt)

### Root Cause
(explanation)

### Action
- [ ] Fix approach
- [ ] Ticket URL
```

Cause unconfirmed → add `> [WARN] Root cause not identified. Temporary action only.` and list confirmed / unconfirmed / temporary action sections.

Ticket creation failed → add `> [WARN] Jira MCP failed.` and include Jira draft (summary / description / priority / labels) inline.
