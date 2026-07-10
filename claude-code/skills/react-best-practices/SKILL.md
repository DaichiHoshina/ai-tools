---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit
name: react-best-practices
description: React/Next.js optimization: 45 rules, 8 categories. Use for React/Next.js impl.
requires-guidelines:
  - nextjs-react
---

# react-best-practices - React/Next.js Performance Optimization

> **Version**: 0.1.0 | **Source**: [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills)

## Rule Categories (Priority Order)

| Priority | Category | Impact | Prefix |
|--------|----------|--------|----------------|
| 1 | Eliminating Waterfalls | CRITICAL | `async-` |
| 2 | Bundle Size Optimization | CRITICAL | `bundle-` |
| 3 | Server-Side Performance | HIGH | `server-` |
| 4 | Client-Side Data Fetching | MEDIUM-HIGH | `client-` |
| 5 | Re-render Optimization | MEDIUM | `rerender-` |
| 6 | Rendering Performance | MEDIUM | `rendering-` |
| 7 | JavaScript Performance | LOW-MEDIUM | `js-` |
| 8 | Advanced Patterns | LOW | `advanced-` |

check 内容 canonical: `guidelines/languages/nextjs-react.md` 参照。rule ID は上記 prefix + 個別 slug 形式 (例: `async-parallel`, `bundle-barrel-imports`) で報告する。

## Output Format

Normal case:

```
🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM `file:line` - rule ID - problem & fix
📊 Summary: Critical X / High Y / Medium Z
```

Zero findings:

```
✅ No performance findings (N files / 45 rules checked)
📊 Summary: Critical 0 / High 0 / Medium 0

### Recommended Actions
- Continue monitoring (re-run on next Lighthouse/Web Vitals)
```

No review target (React/Next.js detection failed):

```
> [WARN] React/Next.js detection failed
> Search: package.json (react/next deps) / *.tsx / *.jsx
> Not found → skip
```

Guidelines: `~/.claude/guidelines/languages/nextjs-react.md`
