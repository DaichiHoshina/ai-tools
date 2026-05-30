# Dashboard Design Patterns

## Visual Hierarchy (Critical)

```text
Bad: All elements same size, color, spacing
Good: Large KPI → medium trend → small detail table
```

### 3-tier structure

| Tier | Purpose | Style |
|------|---------|-------|
| Layer 1: Hero Metrics | Critical KPI | text-3xl/4xl + bold, primary accent |
| Layer 2: Trends | Trend spotting | Charts, medium cards |
| Layer 3: Details | Detail data | Table, text-sm, muted style |

## Layout principles

| Principle | Implementation |
|-----------|-----------------|
| Grid weight | `grid-cols-3` with one `col-span-2` |
| Whitespace rhythm | `gap-6` between sections, `p-6` in cards |
| Color hierarchy | primary accent 1 place only, rest muted/secondary |
| Typography levels | Min 3 levels (h2 text-2xl / h3 text-lg / body text-sm) |
| Numeric display | `font-mono tabular-nums` |
