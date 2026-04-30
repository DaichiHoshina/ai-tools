---
name: architecture-diagram
description: アーキテクチャ図生成。HTML/SVGでシステム構成・クラウド・マイクロサービス・ネットワーク図をダークテーマで作成、図作成時に使用
---

# Architecture Diagram Skill

Create professional technical architecture diagrams as self-contained HTML files with inline SVG graphics and CSS styling.

## Design System

ダークテーマ（slate-950背景）、JetBrains Mono、セマンティックカラー（cyan=Frontend, emerald=Backend, violet=DB, amber=Cloud, rose=Security）。SVGコンポーネント間は40px以上の間隔。Legend は全boundary外側に配置。

## Template

Copy and customize the template at `assets/template.html`. Key customization points:

1. Update the `<title>` and header text
2. Modify SVG viewBox dimensions if needed (default: `1000 x 680`)
3. Add/remove/reposition component boxes
4. Draw connection arrows between components
5. Update the three summary cards
6. Update footer metadata

## Output

Always produce a single self-contained `.html` file with:
- Embedded CSS (no external stylesheets except Google Fonts)
- Inline SVG (no external images)
- No JavaScript required (pure CSS animations)

The file should render correctly when opened directly in any modern browser.
