---
name: ui-skills
description: UI build constraints (Tailwind/motion/react) + design system + Playwright visual checks. Animation & A11y-ready. Use when building UI components.
requires-guidelines:
  - nextjs-react
  - tailwind
  - shadcn
---

# ui-skills

## Tech Stack

| Element | Requirement |
|---------|------------|
| Styling | **MUST** Tailwind CSS defaults |
| Animation | **MUST** `motion/react` |
| Class util | **MUST** `cn` (`clsx` + `tailwind-merge`) |

## Rules

### Components

| Category | Rule |
|----------|------|
| MUST | Use accessible component primitives (Base UI, React Aria, Radix) |
| MUST | Icon-only buttons need `aria-label` |
| NEVER | Don't mix multiple primitive systems in same interaction |
| NEVER | Don't manually implement keyboard/focus behavior |

### Interaction

| Category | Rule |
|----------|------|
| MUST | Destructive action → `AlertDialog` required |
| MUST | Show errors near action location |
| MUST | Respect `safe-area-inset` on fixed elements |
| NEVER | Don't use `h-screen` (use `h-dvh`) |
| NEVER | Don't disable paste on `input`/`textarea` |

### Animation

| Category | Rule |
|----------|------|
| MUST | No animations without explicit request |
| MUST | Animate only `transform` & `opacity` |
| NEVER | Don't animate layout attrs (`width`, `height`, `margin`) |
| NEVER | Interaction feedback must be < 200ms |

### Typography / Layout / Performance / Design

| Category | Rule |
|----------|------|
| MUST | Headings → `text-balance`, body → `text-pretty`, data → `tabular-nums` |
| MUST | Fixed z-index scale (no random `z-[999]`) |
| MUST | Empty states need clear next action |
| NEVER | Don't animate large `blur()` / `backdrop-filter` |
| NEVER | Don't put `useEffect` for render logic |
| NEVER | No gradients/purple/multicolor without request |
| SHOULD | Loading → structural skeleton |
| SHOULD | Respect `prefers-reduced-motion` |
| SHOULD | Square elements use `size-*` (prefer over `w-* h-*`) |
| SHOULD | Prefer existing theme / Tailwind default colors |

## Quality Guard for First Implementation

### Pre-implementation checklist

| # | Item | How |
|---|------|-----|
| 1 | Consistency with existing UI | Check similar screens in project |
| 2 | Modal/popup sizing | Appropriate size for content |
| 3 | Concrete display data | Use titles/names, not IDs |

### Post-implementation self-check

| # | Check | Common failure |
|---|-------|-----------------|
| 1 | z-index conflicts | Modal hidden behind |
| 2 | Loading states | No indicator during async |
| 3 | Empty/error states | Undefined when no data |
| 4 | API latency check | Heavy ops run sync in UI |
| 5 | Responsive check | Size wrong for screen |

## Output Format

Normal case:

```text
Critical: `file:line` - violation → fix
Warning: `file:line` - improvement → suggestion
Summary: Critical X / Warning Y
```

Zero issues:

```text
✅ No UI constraint violations (N components)
Summary: Critical 0 / Warning 0
Recommended: Playwright visual check for render confirmation
```

No files found:

```text
> [WARN] No React/Vue/Svelte components found
> Target: *.tsx / *.jsx / *.vue / *.svelte
> Skipping
```

## References

- [ui-skills](https://github.com/ibelick/ui-skills)
- [Base UI](https://base-ui.com/) / [React Aria](https://react-spectrum.adobe.com/react-aria/) / [Radix UI](https://www.radix-ui.com/)
