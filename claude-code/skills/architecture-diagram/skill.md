---
name: architecture-diagram
description: Architecture diagram generation. HTML/SVG system, cloud, microservice, network diagrams in dark theme. Use when creating diagrams.
---

# architecture-diagram

Create professional technical architecture diagrams as self-contained HTML files with inline SVG graphics and CSS styling.

## Design System

Dark theme (slate-950 bg), JetBrains Mono, semantic colors (cyan=Frontend, emerald=Backend, violet=DB, amber=Cloud, rose=Security). ≥40px spacing between SVG components. Legend placed outside all boundaries.

## Template

Copy and customize `assets/template.html`. Key points:

1. Update `<title>` and header
2. Adjust SVG viewBox if needed (default: 1000 × 680)
3. Add/remove/reposition component boxes
4. Draw arrows between components
5. Update summary cards
6. Update footer metadata

## Output

Single self-contained `.html` file:
- Embedded CSS (Google Fonts only external)
- Inline SVG (no external images)
- No JS (CSS animations only)

Renders in any modern browser.

## Error handling

| Case | Behavior |
|------|----------|
| `assets/template.html` missing | Generate minimal template (slate-950 + JetBrains Mono), log warning |
| Output filename conflict | Auto-suffix `-2`, `-3` |
| ViewBox calc fails | Default 1000 × 680, request `--viewbox` flag |
