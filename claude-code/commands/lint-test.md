---
allowed-tools: Bash, Read, Glob, Grep, mcp__serena__*
description: Run CI-equivalent checks locally in batch (build, lint, test, typecheck etc)
---

# /lint-test - CI in batch

Run all CI steps locally. Final check before push.

## Flow

1. **CI config detection**
   ```bash
   # Find CI config (priority order)
   ls .gitlab-ci.yml     # GitLab CI
   ls .github/workflows/ # GitHub Actions
   ls Makefile            # make ci / make check
   ls package.json        # ci-related in scripts
   ls docker-compose.yml  # docker compose run test etc
   ```

2. **Parse CI config, extract steps**
   - `.gitlab-ci.yml` → extract build, lint, test from stages/jobs
   - GitHub Actions → extract run commands from steps
   - `package.json` → extract build, lint, test, typecheck from scripts
   - `Makefile` → extract targets: ci, check, test, lint

3. **Run all detected steps in order**

   Typical order:
   | # | Step | Example |
   |---|------|---------|
   | 1 | **Dependency resolve** | `pnpm install`, `go mod download` |
   | 2 | **Code generation** | `pnpm generate`, `go generate ./...` |
   | 3 | **Typecheck** | `pnpm tsc --noEmit`, `go vet ./...` |
   | 4 | **Lint** | `pnpm lint`, `golangci-lint run` |
   | 5 | **Build** | `pnpm build`, `go build ./...` |
   | 6 | **Test** | `pnpm test`, `go test ./...` |

4. **Result summary**
   ```
   1. install  : ✓ passed
   2. generate : ✓ passed
   3. typecheck: ✓ passed
   4. lint     : ✗ 3 errors
   5. build    : - skipped (lint failed)
   6. test     : - skipped (lint failed)

   Result: FAILED at step 4 (lint)
   ```
   - on failure: show errors, suggest fixes
   - all pass: "CI equivalent checks all passed. Ready to push."

## Options

| Arg | Description | Example |
|-----|-------------|---------|
| (none) | run all CI steps | `/lint-test` |
| `--fix` | w/ lint auto-fix | `/lint-test --fix` |
| `--continue` | continue after failure | `/lint-test --continue` |

## Notes

- if no CI config found, infer from package.json/go.mod etc
- default stops on first failure (`--continue` to proceed)

## Fallback behavior

| Scenario | Action |
|----------|--------|
| no CI config + no manifest detected | report "CI not configured", ask user for explicit `lint` / `test` commands & stop |
| inferred command not found | warn + skip, note "skipped (command not found)" in Result |
| all steps skipped | Result: "N/A: no checks to run" (not PASS) |

ARGUMENTS: $ARGUMENTS
