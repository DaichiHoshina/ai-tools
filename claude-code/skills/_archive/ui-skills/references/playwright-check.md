# Playwright Visual Check

## Workflow

```text
UI impl complete → start dev server → Playwright screenshot
  → Claude reads /tmp/ui-visual-check/*.png
  → Evaluate 5 aspects (hierarchy / whitespace / color / typography / alignment)
  → Issues found → fix → re-screenshot (max 3 times) → quality OK → done
```

Template: `~/.claude/templates/ui-themes/playwright-visual-check.ts`

## Prerequisites

- Dev server running (default: `http://localhost:3000`)
- Different port: `BASE_URL=http://localhost:5173 npx tsx ...`
- `npx playwright install chromium` (first time only)
