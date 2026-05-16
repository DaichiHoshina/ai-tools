---
name: slack-rich-copy
description: Copy rich text (HTML+RTF+plain) to macOS clipboard for Slack/Notion/Gmail. Use when pasting links/tables.
---

# slack-rich-copy

Sets **HTML / RTF / plain text** simultaneously in macOS NSPasteboard, so `⌘V` into Slack/Notion/Gmail/Apple Notes preserves links & formatting.

## Why Needed

- `pbcopy` plain text only. Slack receives `<URL|text>` markdown uninterpreted (renders post-send).
- `pbcopy -Prefer rtf` RTF alone → Slack sometimes ignores.
- osascript `«data HTML...»` & `«class HTML»` alone → insufficient UTI → Slack doesn't recognize.
- **`public.html` UTI + `public.rtf` + plain string together → reliable**.

## Workflow

### Step 1: Generate HTML

Write HTML with lists/links/tables to `/tmp/rich.html` etc.

```html
<ul>
  <li><a href="https://example.com/1">item 1</a> description</li>
  <li><a href="https://example.com/2">item 2</a> description</li>
</ul>
```

### Step 2: Set Pasteboard with Swift Script

```bash
swift ~/.claude/skills/slack-rich-copy/scripts/copy-rich.swift /tmp/rich.html
```

Optional plain text fallback from separate file:

```bash
swift ~/.claude/skills/slack-rich-copy/scripts/copy-rich.swift /tmp/rich.html /tmp/rich.txt
```

Success output: `OK html=...B rtf=...B plain=...chars`.

### Step 3: Verify (Optional)

```bash
osascript -e 'clipboard info'
# → «class HTML», N, «class RTF », N, «class utf8», N, string, N
```

### Step 4: Paste

`⌘V` in Slack/Notion/Gmail composer. Links & list structure preserved.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Slack pastes as plain text | Composer in markdown mode | Toggle **Aa** icon (bottom-right) to rich text |
| `swift` not found | Xcode CLT missing | `xcode-select --install` |
| HTML parse failed | Malformed HTML | Retry with simple structure (`<ul><li>...</li></ul>` etc) |

## Design Notes

- No direct HTML UTI API in pbcopy, use Swift NSPasteboard.
- Python (PyObjC) possible, but macOS bundled python3 lacks AppKit → Swift is dep-free.
- `«class HTML»` alone sometimes ignored by Slack; `public.html` UTI concurrent set is key.

## Trigger Words

"Slack-pasteable", "rich text", "copy list with links", etc.
