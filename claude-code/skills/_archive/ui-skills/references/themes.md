# UI Design System - Themes

## Theme presets

| Preset | Vibe | Use case | radius |
|--------|------|----------|--------|
| **corporate** | Polished, trust, clean | Business dashboards, admin panels | 0.5rem |
| **modern-dark** | Dark, sharp, technical | Data analysis, monitoring, dev tools | 0.375rem |
| **soft** | Soft, approachable | Team tools, SaaS, internal tools | 0.75rem |

## Templates (by framework)

| Framework | Path | Format |
|-----------|------|--------|
| **shadcn/ui** | `~/.claude/templates/ui-themes/shadcn/` | oklch CSS vars + @theme inline |
| **Tailwind CSS / vanilla CSS** | `~/.claude/templates/ui-themes/tailwind/` | CSS Custom Properties |
| **Any (token ref)** | `~/.claude/templates/ui-themes/tokens/` | JSON design tokens |

## Auto-detect framework

```text
On UI impl request:
1. CSS vars in globals.css → use as-is
2. No theme → detect framework (top-down):
   a. components.json exists → shadcn/ui → apply ui-themes/shadcn/
   b. tailwind.config.{js,ts,mjs} → apply ui-themes/tailwind/
   c. Neither → reference ui-themes/tokens/ JSON
3. AskUserQuestion for preset (or auto-detect)
4. Apply theme:
   - shadcn → overwrite app/globals.css
   - tailwind → create src/styles/theme.css, @import in globals.css
   - tokens → ref JSON, manually convert to project CSS vars
```

## Auto-detect theme

If user doesn't choose:

| Keyword | Theme |
|---------|-------|
| "management", "business", "admin", "report", "sales" | corporate |
| "monitoring", "analytics", "logs", "metrics", "API", "dev" | modern-dark |
| "team", "internal", "task", "project", "collab" | soft |
| No match | corporate (most generic) |

## Design brief (--detailed option)

| # | Element | Question |
|---|---------|----------|
| 1 | Information priority | Most critical info on screen? |
| 2 | Layout density | High data density? Whitespace priority? |
| 3 | Tone | Formal? Casual? |
| 4 | Color accent | Brand color? |
| 5 | Reference design | Similar style? (Linear-like, Vercel-like) |
