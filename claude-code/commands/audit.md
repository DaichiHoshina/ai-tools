---
allowed-tools: Bash, Read, Glob, Grep, mcp__serena__*
description: Dependency security audit — detect manifests, scan CVE (CVSS), aggregate, suggest fixes
argument-hint: "[scope]"
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

**yarn v1 vs Berry**: `.yarnrc.yml` or `packageManager: yarn@>=2` in package.json → Berry; else v1.

**Monorepo**: `pnpm-workspace.yaml` / `turbo.json` / `nx.json` / `lerna.json` / `go.work` / Cargo workspace → audit once at root.

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
| `--offline` | cache only, no network | false |
| `--no-temp-lock` | skip ecosystems missing lockfile | false |

## Flow

**Phase 1: Detection** — find manifests, detect workspace aggregation mode, check tool availability via `command -v` (show install hints for missing), temp-generate lockfile if absent (delete after audit; `--no-temp-lock` to skip).

**Phase 2: Parallel execution** — run audit per ecosystem concurrently (Bash background), 60s timeout per tool, capture JSON, stderr → `/tmp/audit-<eco>.err`.

**Phase 3: Aggregation** — normalize to `{ecosystem, package, current, fixed, severity, cve, scope, patchType}`. `patchType`: `patch` (same minor, auto-fixable) / `minor` (same major, auto-fixable) / `major` (breaking, manual review).

**Phase 4: Output** — filter by severity threshold, report format:

```text
# Security Audit Report — YYYY-MM-DD
Detected: npm (web/), Go (api/) | Skipped: python (pip-audit not installed)
## Critical
- [npm/web] lodash 4.17.20 → 4.17.21 (CVE-2021-23337) [patch] auto
- [go/api]  golang.org/x/net v0.0.5 → v0.23.0 (CVE-2023-45288) [minor] auto
## Requires Review (major)
- [npm/web] react 17.x → 18.x (breaking changes) manual
```

`--report md`: sanitize internal IPs / corporate emails / AWS account IDs / DB connection strings → `[REDACTED]`, save as `audit-report-YYYY-MM-DD.md` at repo root.

**Phase 5: Apply fixes** (`--apply` only) — backup lockfiles to `$(mktemp -d)/lock-backup-YYYYMMDD/`, run minor/patch updates, show `git diff --stat`, get user confirmation (plain JP), commit `chore(security): patch N vulnerabilities`, optionally `--pr` → `/git-push --pr`.

## Safety guards

- **No auto-update of major versions** (display only)
- `--apply` requires user confirm after diff display
- `strict` session-mode → reject `--apply` (protection-mode check required)
- Parallel timeout: 60s per tool
- Secret/PII detected → mask w/ `[REDACTED]` (console + `--report` output)
- `--offline`: skip network-required tools (govulncheck etc)
- **Post-run verification**: after `--apply` run `/lint-test` (build/test pass 確認)、after `--pr` cross-check CI security scan results

## Related commands

- `/lint-test` — CI-wide checks (code quality); this is **dependency-audit specific**
- `/review --focus security` — security review of code itself
- `/git-push --pr` — create PR after applying fixes

ARGUMENTS: $ARGUMENTS
