# Architecture Diagram Design System

## Color Palette

| Component | Fill (rgba) | Stroke |
|-----------|-------------|--------|
| Frontend | `rgba(8, 51, 68, 0.4)` | `#22d3ee` (cyan-400) |
| Backend | `rgba(6, 78, 59, 0.4)` | `#34d399` (emerald-400) |
| Database | `rgba(76, 29, 149, 0.4)` | `#a78bfa` (violet-400) |
| AWS/Cloud | `rgba(120, 53, 15, 0.3)` | `#fbbf24` (amber-400) |
| Security | `rgba(136, 19, 55, 0.4)` | `#fb7185` (rose-400) |
| Message Bus | `rgba(251, 146, 60, 0.3)` | `#fb923c` (orange-400) |
| External/Generic | `rgba(30, 41, 59, 0.5)` | `#94a3b8` (slate-400) |

## Typography

JetBrains Mono:
```html
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
```

Sizes: 12px component names, 9px sublabels, 8px annotations, 7px tiny.

## Visual Elements

**Background:** `#020617` (slate-950) with grid:
```svg
<pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
  <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#1e293b" stroke-width="0.5"/>
</pattern>
```

**Boxes:** Rounded (`rx="6"`), 1.5px stroke, semi-transparent.

**Security groups:** Dashed (`stroke-dasharray="4,4"`), rose.

**Region bounds:** Dashed (`stroke-dasharray="8,4"`), amber, `rx="12"`.

**Arrows:** SVG marker:
```svg
<marker id="arrowhead" markerWidth="10" markerHeight="7" refX="9" refY="3.5" orient="auto">
  <polygon points="0 0, 10 3.5, 0 7" fill="#64748b" />
</marker>
```

Arrow z-order: draw after grid, before boxes.

**Mask arrows:** opaque rect then semi-transparent:
```svg
<rect x="X" y="Y" width="W" height="H" rx="6" fill="#0f172a"/>
<rect x="X" y="Y" width="W" height="H" rx="6" fill="rgba(76, 29, 149, 0.4)" stroke="#a78bfa" stroke-width="1.5"/>
```

**Auth/security:** Dashed rose (`#fb7185`).

**Message buses:** Orange (`#fb923c` stroke, `rgba(251, 146, 60, 0.3)` fill).

## Spacing Rules

- Component height: 60px (service), 80-120px (larger)
- Vertical gap min: 40px
- Connectors: place in gap, not overlapping

## Legend placement

Outside all boundaries. Calculate lowest y + height, place 20px+ below. Expand viewBox if needed.

## Layout structure

1. Header - Title with pulsing dot, subtitle
2. Main SVG - Rounded card
3. Summary cards - 3-card grid
4. Footer - Minimal metadata

## Component box pattern

```svg
<rect x="X" y="Y" width="W" height="H" rx="6" fill="FILL" stroke="STROKE" stroke-width="1.5"/>
<text x="CX" y="Y+20" fill="white" font-size="11" font-weight="600" text-anchor="middle">LABEL</text>
<text x="CX" y="Y+36" fill="#94a3b8" font-size="9" text-anchor="middle">sublabel</text>
```

## Info card pattern

```html
<div class="card">
  <div class="card-header">
    <div class="card-dot COLOR"></div>
    <h3>Title</h3>
  </div>
  <ul><li>• Item</li></ul>
</div>
```
