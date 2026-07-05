---
allowed-tools: Read
name: load-guidelines
description: Auto-load guidelines by tech stack, save tokens. Use when loading guidelines.
---

# load-guidelines - Auto-Load Guidelines

## Usage

```
/load-guidelines        # Summary only (lightweight, recommended)
/load-guidelines full   # Summary + detailed guidelines
```

> **⚠️ Token Saving**
> Default (summary only) recommended. `full` = +~5,500 tokens. Use Context7 for detailed code examples.

## Mode 1: Project Detection (Session Start)

### Step 1: Tech Stack Detection

| File | Detected |
|---------|------|
| `package.json` + next dep | Next.js |
| `package.json` + react dep | React |
| `package.json` + typescript dep | TypeScript |
| `go.mod` | Go |
| `pyproject.toml` / `requirements.txt` / `Pipfile` | Python |
| `Cargo.toml` | Rust |
| `.eslintrc*` / `eslint.config.*` | ESLint (TypeScript bonus) |
| `*.tf` | Terraform |
| `Dockerfile` / `docker-compose.yml` | Docker |
| `serverless.yml` / `template.yaml` | Lambda |
| `kubernetes/` / `k8s/` | Kubernetes |
| `package.json` + (express\|nest\|fastify\|koa) | Backend (Node) |
| `go.mod` + (gin\|echo\|fiber\|chi) | Backend (Go) |
| `requirements.txt` + (fastapi\|django\|flask) | Backend (Python) |

### Step 2: Load Guidelines (2-phase)

#### Default: Essential Core Only (~2,500 tokens)

| Condition | Must Load |
|-----|---------|
| Common (required) | `~/.claude/guidelines/common/code-quality-design.md` |
| TypeScript | `~/.claude/guidelines/languages/typescript.md` |
| Next.js/React | `~/.claude/guidelines/languages/nextjs-react.md` |
| Go | `~/.claude/guidelines/languages/golang.md` |

#### `full` Option: Add Details (+~5,500 tokens)

**Common (required 3)**:
- `~/.claude/guidelines/common/claude-code-tips.md`
- `~/.claude/guidelines/common/code-quality-design.md`
- `~/.claude/guidelines/common/development-process.md`

**By language (if detected)**: Load `languages/{id}.md`. Extra exceptions:
- TypeScript + ESLint detected → add `languages/eslint.md`
- Go detected → add `languages/go-test-stability.md`
- Next.js/React + Tailwind detected → add `languages/tailwind.md`
- Next.js/React + shadcn/ui detected → add `languages/shadcn.md`

**Infra (if detected)**:
- Terraform → `infrastructure/terraform.md`
- Lambda → `infrastructure/aws-lambda.md`
- ECS/Fargate → `infrastructure/aws-ecs-fargate.md`
- EKS/Kubernetes → `infrastructure/aws-eks.md`
- EC2 → `infrastructure/aws-ec2.md`

**On sub-topic keyword**: Check `~/.claude/references/guideline-triggers.md`, add only 1-2 relevant (forbid bulk Backend FW load, save tokens).

### Step 3: Report Results

Report detected (comma-sep lang or `common`, mode `summary`/`full`).

**Zero findings**: no lang match → `summary` loads `common/code-quality-design.md` (`fallback: common-summary`); `full` loads mandatory 3 (`fallback: common-full`). Never skip common 3 when `full`.

---

## Mode 2: Skill Integration (requires-guidelines)

Auto-load Skill frontmatter `requires-guidelines` IDs (skip dups).

### ID Resolution Convention

Basic: Resolve to `~/.claude/guidelines/<category>/<id>.md`. Category auto-detected.

**Exceptions (id → path)**:
- `common` → `common/code-quality-design.md`
- `ddd` → `design/domain-driven-design.md`
- `operations` → `operations/monitoring-runbook.md`

**Category detection**:
- `typescript|golang|nextjs-react|tailwind|shadcn|python|rust|eslint|go-test-stability|go-performance|go-concurrency` → `languages/`
- `terraform` → `infrastructure/terraform.md`, `kubernetes` → `infrastructure/aws-eks.md`
- `clean-architecture|ddd|async-job-patterns` → `design/`
- `database-performance|mysql-performance|caching-strategies|distributed-transactions|observability-design|security-hardening|scalability-patterns|event-driven-architecture|multi-tenancy` → `backend/`

**On-demand ID mapping (not auto-loaded, resolve when `requires-guidelines` names them)**:

| ID | Path |
|---|---|
| `guardrails` | `common/guardrails.md` |
| `investigation-protocol` | `common/investigation-protocol.md` |
| `logging-standards` | `common/logging-standards.md` |
| `notion-database` | `common/notion-database.md` |
| `notion-design` | `common/notion-design.md` |
| `notion-operations` | `common/notion-operations.md` |
| `notion-writing` | `common/notion-writing.md` |
| `release-management` | `common/release-management.md` |
| `session-modes` | `common/session-modes.md` |
| `technical-pitfalls` | `common/technical-pitfalls.md` |
| `technique-selection` | `common/technique-selection.md` |
| `testing-guidelines` | `common/testing-guidelines.md` |
| `type-safety-principles` | `common/type-safety-principles.md` |
| `cqrs` | `design/cqrs.md` |
| `async-messaging` | `languages/async-messaging.md` |
| `vue3` | `languages/vue3.md` |
| `prompt-caching` | `operations/prompt-caching.md` |

**Unresolved ID**: not in above → warn log `[load-guidelines] unresolved id: <id>`, skip only that ID, continue loading rest.

---

## Mode 3: Command-Specific Skill Recommendations

Main command recommendations (`/dev` `/plan` `/review` `/flow`) in `references/command-resource-map.md` (lazy load).
