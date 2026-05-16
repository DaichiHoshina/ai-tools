---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: UI unified command - theme/implementation/review/perf/verify/audit in 1 entry
---

# /ui - UI Unified Command

Single entry for all UI ops. Route via argument keywords.

## Routing

### `$ARGUMENTS` present → auto-detect keyword

Infer action from arg keywords.

| Keyword | Action |
|-----------|-----------|
| theme, color | apply theme |
| implement, build, create, page, component | UI implementation |
| review, check, a11y, ui-review | UI/UX review (not code review like `/review`) |
| performance, perf, bundle | performance review |
| screenshot, verify, visual | visual verify |
| fix, ugly, improve, broken | full UI audit |

Unrecognized → AskUserQuestion with 6 choices (below).

### `$ARGUMENTS` absent → AskUserQuestion

```yaml
question: "What?"
header: "UI Action"
options:
  - label: "Apply Theme"
    description: "choose/apply design theme"
  - label: "UI Implementation"
    description: "build component/page"
  - label: "UI/UX Review"
    description: "review via MD3/WCAG/Nielsen"
  - label: "Performance Review"
    description: "diagnose React/Next.js perf"
```

If "Other" selected, show second question:

```yaml
question: "Other Action"
header: "UI Action"
options:
  - label: "Visual Verify"
    description: "Playwright screenshot/confirm"
  - label: "Full UI Audit"
    description: "review→perf→verify→fix 1-shot"
```

**Note**: 4 options max per question, high-frequency = 1st. Visual/Full via "Other" → 2nd. `$ARGUMENTS` keyword bypasses to direct exec.

## Action Details

### 1. Apply Theme

Delegate `ui-skills` skill.

AskUserQuestion theme choice:

```yaml
question: "Which theme?"
header: "Theme"
options:
  - label: "Corporate (Linear/Stripe style)"
    description: "business dashboard, admin. Indigo tone, modest radius"
  - label: "Modern Dark (Raycast/Vercel style)"
    description: "data analysis, monitoring. Cyan tone, tight spacing"
  - label: "Soft (Notion/Loom style)"
    description: "team tools, SaaS. Violet tone, large radius"
```

Framework detect → apply theme per `ui-skills` "auto-detect" / "apply" flow.

If custom theme exists, AskUserQuestion overwrite confirm.

Post-apply, AskUserQuestion next (implement/visual verify/done).

### 2. UI Implementation

Delegate `ui-skills` skill.

Post-theme, UI implementation follows `ui-skills` "dashboard design pattern" (3-layer, grid variance, color economy).

### 3. UI/UX Review

Delegate `uiux-review` skill. Unclear target? AskUserQuestion.
Angles: MD3 / WCAG 2.2 AA / Nielsen 10 principles.

### 4. Performance Review

Delegate `react-best-practices` skill. Non-React? skip.
Angles: waterfall elimination / bundle optimize / Server-Client split / re-render optimize.

### 5. Visual Verify

Per `ui-skills` "Playwright visual verify". Prerequisite: dev server up, `npx playwright install chromium` done. Custom port via `BASE_URL=http://localhost:5173`.

### 6. Full UI Audit

Run all serially, gen integrated report.

```
Step 1: uiux-review → MD3/WCAG/Nielsen
Step 2: react-best-practices → perf diagnose (React only)
Step 3: Playwright → visual verify (if dev-server up)
Step 4: report issues + priority
Step 5: AskUserQuestion → fix?
Step 6: ui-skills execute fix (user approve)
```

## Dependent Skills

| Skill | Purpose |
|--------|------|
| `ui-skills` | apply theme, implement UI, visual verify |
| `uiux-review` | UI/UX review (MD3/WCAG/Nielsen) |
| `react-best-practices` | React perf review |
| `load-guidelines` | tailwind, shadcn auto-load |

## Notes

- 3x fix still no improve? ask user
- full audit: confirm each step before next
- `/review` + `/flow` existing UI flow maintained (add, not replace)
