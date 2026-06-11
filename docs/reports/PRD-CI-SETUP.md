# PRD: CI Setup — Regression Prevention Automation

## Purpose

Add CI configuration to the ai-tools repository to prevent regressions with automatic checks per PR.

## Background

Current problems:
- No automatic verification when modifying install.sh/sync.sh
- Cannot detect syntax errors in shell scripts
- Markdown formatting issues go unnoticed
- Risk of regressions mixed into PRs

## Scope

### Target files

**Shell scripts (22 files)**:
- claude-code/install.sh
- claude-code/sync.sh
- claude-code/hooks/*.sh (10 files)
- claude-code/scripts/*.sh (4 files)
- claude-code/lib/*.sh (6 files)

**Markdown (134 files)**:
- claude-code/**/*.md (skills, commands, guidelines, agents etc.)
- README.md, CLAUDE.md, CANONICAL.md, AGENTS.md etc.

### Verification items

| Item | Tool | Target | Content |
|------|------|--------|---------|
| Shell check | shellcheck | All .sh | Syntax errors, best practice violations |
| Markdown lint | markdownlint | All .md | Format errors, broken links |
| install.sh test | Manual script | install.sh | Install success, error detection |
| sync.sh test | Manual script | sync.sh | Sync operation verification |

## Requirements

### Functional

- **FR-1**: GitHub Actions Workflow — auto-run on PR creation and push events
- **FR-2**: shellcheck — validate all .sh; fail CI on error
- **FR-3**: markdownlint — validate all .md; CI success on warnings only (no strict mode)
- **FR-4**: install.sh test — run in temp directory; fail CI on error
- **FR-5**: sync.sh test — test to-local, from-local, diff modes; fail CI on error

### Non-functional

- **NFR-1**: CI total execution time within 5 minutes
- **NFR-2**: Simple, readable GitHub Actions workflow; each step independently executable
- **NFR-3**: Structure that allows easy addition of future tests

## Success criteria

1. CI auto-runs per PR
2. shellcheck and markdownlint check all files
3. install.sh and sync.sh tests pass
4. CI fails and blocks merge when regression is mixed in

## Tech stack

- CI: GitHub Actions
- shellcheck: Shell script static analysis
- markdownlint-cli: Markdown lint
- Bash: Test scripts

## Schedule

| Phase | Content | Time |
|-------|---------|------|
| Phase 1 | PRD creation | Done |
| Phase 2 | Plan (design) | 10 min |
| Phase 3 | Dev (implementation) | 20 min |
| Phase 4 | Simplify | 5 min |
| Phase 5 | Test (verification) | 10 min |
| Phase 6 | Review | 5 min |
| Phase 7 | Verify | 5 min |
| Phase 8 | PR creation | 5 min |

## Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| shellcheck false positives | Medium | Adjust rules in .shellcheckrc |
| markdownlint strict | Medium | Relax in .markdownlintrc |
| CI execution time over | Low | Optimize with parallel execution |

## Appendix: File statistics

- Shell scripts: 22 files
- Markdown: 134 files
- Total: 156 files
