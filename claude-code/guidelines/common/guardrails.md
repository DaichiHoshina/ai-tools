# Guardrails

Classify operations into 3 layers (Safe/Boundary/Forbidden) to guarantee safety.

## Operation Guard

```
Guard : Action → {Allow, AskUser, Deny}
Guard(a) = Allow   ⟺ a ∈ Mor(Safe)
Guard(a) = AskUser ⟺ a ∈ Mor(Boundary)
Guard(a) = Deny    ⟺ a ∈ Mor(Forbidden)
```

Safety theorem: Safe is always safe / Boundary is safe with approval / Forbidden cannot be executed.

| Layer | Handling | Description |
|-------|----------|-------------|
| **Safe** | Execute immediately | Harmless operations |
| **Boundary** | Execute after confirmation | Has impact (confirmation level changes by mode) |
| **Forbidden** | Cannot execute | Dangerous, always rejected |

## Safe (auto-allowed)

- File read, code analysis/search, directory listing
- Suggestions, explanations, code review (read-only), doc reference
- git status / log / diff, environment info check

## Boundary (confirmation required, varies by mode)

### Git Operations

| Operation | strict | normal | fast |
|-----------|--------|--------|------|
| git add | confirm | auto | auto |
| git commit | confirm | confirm | auto |
| git push | confirm | confirm | confirm |
| git merge | confirm | confirm | confirm |
| git rebase (local) | confirm | confirm | auto |

### File Operations

| Operation | strict | normal | fast |
|-----------|--------|--------|------|
| Edit | confirm | auto | auto |
| Create | confirm | auto | auto |
| Normal delete | confirm | confirm | auto |
| Important delete | confirm | confirm | confirm |

Important files: `src/`, `.git/`, `node_modules/`, `.env`, `package.json`, `go.mod` etc.

### Package Management

| Operation | strict | normal | fast |
|-----------|--------|--------|------|
| npm install (safe) | confirm | auto | auto |
| npm install (unknown) | confirm | confirm | confirm |
| go get | confirm | auto | auto |

Safe packages: high download count + active maintenance + no known vulnerabilities.

### Config Changes

| Operation | strict | normal | fast |
|-----------|--------|--------|------|
| .env change | confirm | confirm | confirm |
| package.json | confirm | confirm | auto |
| tsconfig.json | confirm | auto | auto |
| Dockerfile | confirm | confirm | auto |

## Forbidden (auto-detected by Hooks)

| Forbidden | Reason |
|-----------|--------|
| format | prettier/eslint/go fmt are user-run |
| commit | AI auto-execution forbidden (use `/git-push`) |
| auto_test | Auto test creation forbidden (template suggestion OK) |
| unused | "Just in case" code forbidden (YAGNI) |

## Quality Standards

| Metric | Standard |
|--------|----------|
| Function size | ≤50 lines |
| Arguments | ≤3 |
| Cyclomatic complexity | ≤10 |
| Nesting | ≤3 levels |

## Forbidden (rejected in all modes)

- **System destruction**: `rm -rf /`, `dd if=/dev/zero of=/dev/sda`, `kill -9 -1`, `shutdown -h now`, `mkfs.*`
- **Security**: `chmod 777 -R /`, secret leaks, credential exposure, `.env` commit, secrets push
- **Dangerous git**: `git push --force` / `git reset --hard` remote / `git clean -fdx`
- **External connection**: `curl | bash`, `wget | sh`, arbitrary code eval from user input
- **YAGNI violations**: generating unused code / "just in case" / "might use later" implementations

## Confirmation Flow

```
strict: Confirm all Boundary → notification sound → wait for approval → execute
normal: Confirm only important Boundary, others auto
fast:   Confirm only most important Boundary, Forbidden rejected, others auto
```

Notification: `afplay ~/notification.mp3` on confirmation and completion.

## Exception Handling

- On Boundary rejection: explain reason → suggest alternative → reload `/protection-mode` if needed
- On Forbidden detection: immediate rejection → explain danger → suggest safe alternative

## Related

- `session-modes.md` — mode definitions
- `/protection-mode` — load category-theory thinking
- `claude-code/references/AI-THINKING-ESSENTIALS.md` — includes 5-phase workflow
