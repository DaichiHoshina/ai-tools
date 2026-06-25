---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit
name: react-best-practices
description: React/Next.js optimization: 45 rules, 8 categories. Use for React/Next.js impl.
requires-guidelines:
  - nextjs-react
hooks:
  - event: PreSkillUse
    command: "~/.claude/hooks/pre-skill-use.sh"
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

## Quick Reference

### 1. Eliminating Waterfalls (CRITICAL)

- `async-defer-await` - Move await to needed branches
- `async-parallel` - Promise.all() for independent ops
- `async-dependencies` - Partial deps with better-all
- `async-api-routes` - Early Promise start in API routes
- `async-suspense-boundaries` - Stream with Suspense

### 2. Bundle Size Optimization (CRITICAL)

- `bundle-barrel-imports` - Avoid barrel, import direct
- `bundle-dynamic-imports` - Heavy components with next/dynamic
- `bundle-defer-third-party` - Load analytics post-hydration
- `bundle-conditional` - Load modules on feature enable
- `bundle-preload` - Preload on hover/focus

### 3. Server-Side Performance (HIGH)

- `server-cache-react` - React.cache() per request
- `server-cache-lru` - LRU across requests
- `server-serialization` - Minimal data to Client Component
- `server-parallel-fetching` - Parallelize fetches in component tree
- `server-after-nonblocking` - Non-blocking with after()

### 4. Client-Side Data Fetching (MEDIUM-HIGH)

- `client-swr-dedup` - Auto dedup with SWR
- `client-event-listeners` - Dedup global listeners

### 5. Re-render Optimization (MEDIUM)

- `rerender-defer-reads` - Don't subscribe to state used only in callbacks
- `rerender-memo` - Extract expensive work to memo component
- `rerender-dependencies` - Keep effect deps primitive
- `rerender-derived-state` - Subscribe to derived boolean, not raw value
- `rerender-functional-setstate` - Functional setState for stable callback
- `rerender-lazy-state-init` - Expensive init = function with useState
- `rerender-transitions` - startTransition for non-urgent updates

### 6. Rendering Performance (MEDIUM)

- `rendering-animate-svg-wrapper` - Animate div wrapper, not SVG
- `rendering-content-visibility` - content-visibility for long lists
- `rendering-hoist-jsx` - Extract static JSX outside component
- `rendering-svg-precision` - Reduce SVG coordinate precision
- `rendering-hydration-no-flicker` - Inline script to prevent flicker
- `rendering-activity` - Activity component for show/hide
- `rendering-conditional-render` - Ternary, not && for conditionals

### 7. JavaScript Performance (LOW-MEDIUM)

- `js-batch-dom-css` - Batch CSS with class or cssText
- `js-index-maps` - Build Map for repeated lookups
- `js-cache-property-access` - Cache property access in loops
- `js-cache-function-results` - Cache results in module-level Map
- `js-cache-storage` - Cache localStorage/sessionStorage reads
- `js-combine-iterations` - Combine multiple filter/map → 1 loop
- `js-length-check-first` - Check array length before expensive compare
- `js-early-exit` - Early return from function
- `js-hoist-regexp` - Hoist RegExp creation outside loop
- `js-min-max-loop` - Use loop, not sort for min/max
- `js-set-map-lookups` - Use Set/Map for O(1) lookup
- `js-tosorted-immutable` - toSorted() for immutability

### 8. Advanced Patterns (LOW)

- `advanced-event-handler-refs` - Store event handlers in refs
- `advanced-use-latest` - useLatest for stable callbacks

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
