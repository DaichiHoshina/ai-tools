---
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
description: Local verification + screenshot → PR comment
---

# /test-local - Local Verification & PR Attach

Confirm changes locally, capture screenshot, attach results to PR.

## Step 1: PR Confirm

```bash
gh pr view --json number,title,url
```

If no PR, offer to create.

## Step 2: Run lint-test (only if `--with-test`)

If arg has `--with-test`, execute `/lint-test` and record results. Otherwise skip.

## Step 2.5: Test Data Confirm/Create

Before screenshot, verify page in meaningful state. AskUserQuestion:
- "Need test data? (auto-create / manual ready / skip)"

If auto-create selected, detect & run seed method:

| Detect | Command |
|--------|---------|
| `db/seeds.rb` or `seeds/` | `rails db:seed` or `bundle exec rails db:seed` |
| `prisma/seed.ts` | `npx prisma db seed` |
| `scripts/seed.*` | execute it |
| `Makefile` seed target | `make seed` |
| none | AskUserQuestion "what's the seed command?" |

After seed, visit URL to verify data shown, then screenshot.

## Step 3: Screenshot (Playwright)

AskUserQuestion:
- "Screenshot URL? (e.g. http://localhost:3000/items)"

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCREENSHOT=/tmp/test-local-${TIMESTAMP}.png
URL="<input>"

# Playwright CLI screenshot
npx playwright screenshot "${URL}" "${SCREENSHOT}" --full-page

# copy to clipboard (macOS)
osascript -e "set the clipboard to (read (POSIX file \"${SCREENSHOT}\") as JPEG picture)"
```

If Playwright missing:
```bash
npm install -D @playwright/test && npx playwright install chromium
```

`--fullscreen` → add `--full-page` (default).
`--viewport WxH` specify (e.g. `--viewport 375x812` mobile).

## Step 4: PR Comment

Post test results as comment. **Must pass `~/.claude/rules/ai-output.md` PREP 3-point + `PRINCIPLES.md` "4 pre-write questions" + "6 pre-output checks"**. If lengthy, use `<details>` fold.

```bash
gh pr comment --body "$(cat <<'BODY'
## Conclusion
local verification ✅ / no blockers → review continue

## Reasoning
{1-2 line lint-test summary. concrete numbers or counts}

## Next
{reviewer todo or none. if none: "none"}

<details>
<summary>test output detail</summary>

\`\`\`
{full lint-test output}
\`\`\`
</details>

### screenshot
<!-- paste from clipboard or drag-drop file -->
BODY
)"
```

## Step 5: Screenshot Location Guide

Show:

```
📸 saved: /tmp/local-test-{timestamp}.png
📋 copied to clipboard

→ gh pr view --web, paste in comment
```

Auto-open browser:
```bash
gh pr view --web
```

## Options

| Arg | Behavior |
|-----|----------|
| (none) | URL specify→Playwright screenshot→PR comment |
| `--with-test` | also run lint-test → attach |
| `--no-screenshot` | skip screenshot |
| `--viewport 375x812` | mobile size screenshot |

## Notes

- GitHub auto-upload screenshot: not supported (CLI limit)
- `gh pr view --web` + manual paste = fastest
- `ARGUMENTS` with PR number: `gh pr comment {num}`

ARGUMENTS: $ARGUMENTS
