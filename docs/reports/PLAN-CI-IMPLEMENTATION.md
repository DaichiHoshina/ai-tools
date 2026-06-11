# Implementation Plan: CI Setup

## Architecture overview

```
GitHub PR/Push
    ↓
GitHub Actions Workflow
    ↓
┌─────────────────────────────────┐
│ Job 1: shellcheck (parallel)    │
│ Job 2: markdownlint (parallel)  │
│ Job 3: install test (parallel)  │
│ Job 4: sync test (parallel)     │
└─────────────────────────────────┘
    ↓
All jobs pass → CI success
Any job fails → CI failure
```

## File structure

```
.github/
  workflows/
    ci.yml                    # Main CI workflow
.shellcheckrc                 # shellcheck config
.markdownlintrc               # markdownlint config
scripts/
  test-install.sh             # install.sh test script
  test-sync.sh                # sync.sh test script
```

## Implementation details

### 1. .github/workflows/ci.yml

**Triggers**: pull_request (all branches) / push (main branch only)

#### Job 1: shellcheck
- Ubuntu latest
- Install shellcheck (apt-get)
- Validate all .sh files
- Detect SC2086, SC2155 etc.

#### Job 2: markdownlint
- Ubuntu latest
- Install markdownlint-cli (npm)
- Validate all .md files
- Apply .markdownlintrc config

#### Job 3: install-test
- Ubuntu latest
- Run in temp directory
- Verify install.sh operation

#### Job 4: sync-test
- Ubuntu latest
- Test sync.sh each mode (to-local, from-local, diff)

### 2. .shellcheckrc

**Excluded rules**: SC1090 (source with variable), SC1091 (source file not found in CI)  
**Enabled rules**: SC2086 (unquoted variables), SC2155 (declare -r with assignment), SC2164 (cd without error handling)

### 3. .markdownlintrc

**Relaxed rules**: MD013 line length (up to 200 chars), MD033 HTML tags, MD041 first H1  
**Strict rules**: MD001 header level increment, MD003 header style, MD022 blank lines around headers

### 4. scripts/test-install.sh

Test flow:
1. Create temp directory
2. Run install.sh in syntax-check mode
3. Exit code 1 on error

### 5. scripts/test-sync.sh

Test flow:
1. Create temp directory
2. Run sync.sh diff mode
3. Exit code 1 on error

## Parallel execution strategy

All 4 jobs run in parallel (independent). Benefits: all complete within 5 minutes; all errors detected in one run even if one fails.

## Error handling

| Type | Behavior |
|------|---------|
| shellcheck SC2086 etc. (critical) | CI failure |
| shellcheck SC1090 etc. (info) | Warning only |
| markdownlint MD001 etc. (structural) | CI failure |
| markdownlint MD013 (line length) | Warning only (relaxed config) |
| install.sh / sync.sh execution error | CI failure |

## Implementation steps

1. Create config files (.shellcheckrc, .markdownlintrc)
2. Create test scripts (test-install.sh, test-sync.sh)
3. Create GitHub Actions workflow (ci.yml)
4. Local verification

## Verification plan

### Phase 1: Local
```bash
shellcheck claude-code/install.sh
markdownlint README.md
bash scripts/test-install.sh
bash scripts/test-sync.sh
```

### Phase 2: CI
- Create PR to trigger CI
- Confirm all jobs succeed
- Check error logs on failure

## Performance targets

- shellcheck: within 1 min
- markdownlint: within 2 min
- install-test: within 30s
- sync-test: within 30s
- Total: within 5 min (parallel)

## Security

- No secrets required (public repo)
- No external script execution
- Only public npm packages
