---
allowed-tools: Bash, Read, Glob, Grep, mcp__serena__*
description: Dependency security audit — detect manifests, scan CVE (CVSS), aggregate, suggest fixes
---

# /audit - Security audit

Detect package dependencies across languages/ecosystems, scan CVEs (CVSS basis), aggregate, recommend fixes.

## Current repo state

!`git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"`
!`find . -maxdepth 4 \( -path '*/node_modules' -o -path '*/vendor' -o -path '*/.venv' -o -path '*/dist' -o -path '*/.git' -o -path '*/target' \) -prune -o -type f \( -name "package.json" -o -name "go.mod" -o -name "requirements.txt" -o -name "pyproject.toml" -o -name "Pipfile" -o -name "Cargo.toml" -o -name "Gemfile" -o -name "composer.json" -o -name "pom.xml" -o -name "build.gradle*" \) -print 2>/dev/null | head -30`

## Manifest detection → audit command map

| Manifest | Ecosystem | Audit command | Auto-fix |
|---|---|---|---|
| `package-lock.json` | npm | `npm audit --json` | `npm audit fix` |
| `pnpm-lock.yaml` | pnpm | `pnpm audit --json` | `pnpm update` |
| `yarn.lock` (v1) | yarn classic | `yarn audit --json` | `yarn upgrade` |
| `yarn.lock` (Berry) | yarn berry | `yarn npm audit --json` | `yarn up` |
| `go.mod` | Go | `govulncheck -json ./...` | `go get -u <pkg>` |
| `requirements.txt` | pip | `pip-audit -r requirements.txt -f json` | `pip-audit --fix` |
| `pyproject.toml` (poetry) | poetry | `pip-audit -f json` | manual |
| `Cargo.lock` | cargo | `cargo audit --json` | `cargo update` |
| `Gemfile.lock` | bundler | `bundle audit check --update` | `bundle update --conservative` |
| `composer.lock` | composer | `composer audit --format json` | `composer update` |
| `pom.xml` | maven | `mvn org.owasp:dependency-check-maven:check` | manual |
| `build.gradle*` | gradle | `gradle dependencyCheckAnalyze` | manual |
| `Dockerfile` | container | `trivy fs .` (run only w/ `--include-container`) | base image bump |

**yarn v1 vs Berry**: detect `.yarnrc.yml` or `packageManager: yarn@>=2` in package.json → Berry; else v1.

**Monorepo aggregation**: detect `pnpm-workspace.yaml` / `turbo.json` / `nx.json` / `lerna.json` / `go.work` / Cargo workspace → run audit once at root (skip per-package).

## Options

| Option | Description | Default |
|---|---|---|
| (none) | detect all → audit → report | - |
| `--severity <level>` | `critical`/`high`/`medium`/`low` threshold (CVSS) | `medium` |
| `--scope <path>` | scan only specified dir | whole repo |
| `--ecosystem <name>` | filter to `npm`/`go`/`python` etc | auto-detect all |
| `--no-dev` | exclude devDependencies | false |
| `--apply` | auto-update minor/patch only (SemVer) | false |
| `--pr` | create PR w/ fixes (via `/git-push --pr`) | false |
| `--report md\|json` | file output format | console only |
| `--include-container` | run trivy/docker scout (slow) | false |
| `--offline` | cache only, no network (tools that support) | false |
| `--no-temp-lock` | skip ecosystems missing lockfile (no temp gen) | false |

## Flow

### Phase 1: Detection

1. `git rev-parse --show-toplevel` → confirm repo root
2. `find -prune` manifest list (skip node_modules/vendor/.venv/dist/.git/target)
3. detect workspace files → determine aggregation mode
4. check each ecosystem audit tool via `command -v`
5. missing tools → show install hints, continue (e.g. `pip install pip-audit` / `cargo install cargo-audit` / `go install golang.org/x/vuln/cmd/govulncheck@latest`)
6. if `--offline`, skip network-required tools (govulncheck etc)
7. **lockfile-required tools** (npm/pnpm/yarn/composer/bundler/cargo) w/ no lockfile:
   - default: temp-generate via `npm i --package-lock-only` → audit → **delete temp lockfile** (prevent repo pollution)
   - w/ `--no-temp-lock`: skip that ecosystem

### Phase 2: Parallel execution

Run audit **in parallel** per detected ecosystem (Bash background).

- timeout: 60s per tool (prevent hangs)
- capture JSON where available
- stderr saved to `/tmp/audit-<eco>.err`

### Phase 3: Aggregation

Normalize each audit output to common schema: `{ecosystem, package, current, fixed, severity, cve, scope, patchType}`.

`patchType` decision (SemVer-compliant):
- `patch`: within same minor (auto-fixable)
- `minor`: within same major (auto-fixable, may contain breaking changes)
- `major`: breaking changes likely (manual review required)

### Phase 4: Output

Filter by severity threshold (default: medium+), output format:

```text
# Security Audit Report — YYYY-MM-DD

Detected: npm (web/), pnpm (admin/), Go (api/)
Skipped:  python (pip-audit not installed)

## Summary
| Severity | Count | Auto-fixable |
|----------|-------|--------------|
| Critical | 2     | 2            |
| High     | 5     | 4            |

## Critical
- [npm/web] lodash 4.17.20 → 4.17.21 (CVE-2021-23337) [patch] auto
- [go/api]  golang.org/x/net v0.0.5 → v0.23.0 (CVE-2023-45288) [minor] auto

## Requires Review (major)
- [npm/web] react 17.x → 18.x (breaking changes) manual
```

**Mandatory sanitization for `--report md` file output** (per enterprise-security §5):
- internal IPs (10.x / 172.16-31.x / 192.168.x)
- internal domain emails / AWS account IDs (12 digits)
- DB connection strings / private registry URLs (e.g. `@<scope>:registry=`)

Replace with `[REDACTED]`, save as `audit-report-YYYY-MM-DD.md` at repo root.

### Phase 5: Apply fixes (with `--apply` only)

1. Create lockfile backup in `$(mktemp -d)/lock-backup-YYYYMMDD/` (never create `.bak` in repo)
2. Run update commands for minor/patch only
3. Display lockfile diff via `git diff --stat`
4. Get user confirmation (destructive operation → plain JP confirm)
5. commit w/ `chore(security): patch N vulnerabilities`
6. If `--pr`: delegate to `/git-push --pr`

## Safety guards

- **No auto-update of major versions** (display only)
- `--apply` requires user confirm after diff display
- if session-mode is `strict`, reject `--apply` (protection-mode check required)
- parallel timeout: 60s per tool
- if secret/PII detected, mask w/ `[REDACTED]` (console + `--report` output)
- if `--offline`, skip network-required tools (govulncheck etc)

## Related commands

- `/lint-test` — CI-wide checks (code quality); this is **dependency-audit specific**
- `/review --focus security` — security review of code itself
- `/git-push --pr` — create PR after applying fixes

## Post-run verification

- after `--apply`: run `/lint-test` to confirm build/test pass
- after `--pr`: cross-check CI security scan results

ARGUMENTS: $ARGUMENTS
