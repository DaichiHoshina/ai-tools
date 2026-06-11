# Tailwind CSS Guidelines

Tailwind CSS v4.3 (2026). Common guidelines: `~/.claude/guidelines/common/`.

---

## Core Principles

- **Utility-First**: utility class-centric design
- **Responsive**: mobile-first breakpoints
- **Customizable**: centralized management via theme/design tokens
- **Performance**: automatic removal of unused CSS

---

## v4.x Features (v4.0 released 2025, v4.3 latest)

### Fast Engine
- Full build: **5x faster**
- Incremental build: **100x+ faster** (microsecond-level)

### Modern CSS
- Cascade Layers
- Registered custom properties via `@property`
- `color-mix()` support

### Simplified Setup
- Reduced dependencies
- Zero config
- Single CSS import: `@import "tailwindcss";`

### Vite Integration
- Official Vite plugin
- Auto content detection (no config needed)
- Maximum performance

---

## New Utilities and Variants

### not-* Variant
Apply styles only when no other variant/selector/media query matches:
```html
<div class="not-hover:opacity-50">...</div>
```

### New Utilities
- `color-scheme` — dark/light mode control
- `field-sizing` — form field sizing
- Complex shadow support
- `inert` — inactive elements

---

## Browser Support

- Safari 16.4+
- Chrome 111+
- Firefox 128+

---

## Best Practices

### Class Naming
- Semantically clear utility combinations
- Extract complex combinations into components

### Responsive Design
```html
<div class="w-full md:w-1/2 lg:w-1/3">
```

### Dark Mode
```html
<div class="bg-white dark:bg-gray-900">
```

### Reuse
- Repeated patterns → componentize with `@apply`
- Avoid excessive `@apply` use (violates Utility-First principle)

---

## Next.js Integration

```bash
npm install tailwindcss@next @tailwindcss/vite@next
```

`app/globals.css`: `@import "tailwindcss";`

`next.config.js`:
```js
import tailwindcss from '@tailwindcss/vite'
export default { experimental: { vitePlugins: [tailwindcss()] } }
```

---

## Customization

### Theme via CSS Variables
```css
@theme {
  --color-primary: #3b82f6;
  --font-display: "Inter", sans-serif;
}
```

### Usage
```html
<h1 class="text-primary font-display">
```

---

## Performance Optimization

- PurgeCSS integrated (automatic in v4)
- JIT (Just-In-Time) mode standard
- Unused CSS auto-removed in production build
