---
argument-hint: "[--ui]"
description: Analyze Claude Code usage & present insights (--ui launches dashboard)
---

# /analytics - Claude Code usage analysis

Analyze usage patterns, auto-generate improvement suggestions. Two modes: CLI (text) + UI (browser).

## Execution modes

| Mode | Launch | Use |
|------|--------|-----|
| CLI (default) | `/analytics` | Text summary, suggestions, bot-friendly |
| UI | `/analytics --ui` | Interactive browser dashboard |

## CLI mode

```bash
python3 "$HOME/.claude/scripts/analytics-report.py" --mode full
```

Output markdown with contextual commentary. "Suggestions" section customized to actual workflow.

### Auto-follow: dependency audit

After analytics summary, run `/audit --severity high` (scan package CVEs). CLI mode only; UI mode skips audit. Show detail only if Critical/High detected; else report "audit clear" in one line.

## UI mode

```bash
bash "$HOME/.claude/scripts/dashboard.sh"
```

Requires `~/.claude/analytics/analytics.db` (hooks が逐次生成)。Launch `http://localhost:8765`, auto-open browser.

## Related

- `/retrospective` — session review + memory-based improvement suggestions
- `/cursor-review` — Cursor settings/rules/memories audit (`cursor/MAINTENANCE.md`)
