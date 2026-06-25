---
allowed-tools: Read, Grep, Glob
name: uiux-review
description: UI/UX review (MD3/WCAG2.2/Nielsen). Use during screen implementation.
disallowed-tools:
  - Write
  - Edit
  - MultiEdit
requires-guidelines:
  - common
  - nextjs-react
  - tailwind
  - shadcn
---

# uiux-review

Review 3 principles (Material Design 3 / WCAG 2.2 AA / Nielsen 10) in order, flagging Critical → Warning.

## Review Checklist

### Step 1: Material Design 3

#### 🔴 Critical
- [ ] Component states defined (8 types)
- [ ] Design tokens used (no custom color abuse)
- [ ] Spacing on 4px base (4, 8, 12, 16, 24, 32, 48)
- [ ] Radius M3 compliant (sm:8px, md:12px, lg:16px)

### Step 2: WCAG 2.2 AA

#### 🔴 Critical
- [ ] Contrast ≥ 4.5:1 (normal text)
- [ ] Contrast ≥ 3:1 (UI components)
- [ ] Keyboard operable (Tab, Enter, Escape)
- [ ] Focus clearly visible (2px+ ring)
- [ ] Touch target ≥ 44×44px
- [ ] Images have alt text
- [ ] Form inputs have labels
- [ ] Info not conveyed by color alone

### Step 3: Nielsen 10 Heuristics

#### 🟡 Warning
- [ ] 1. System status visibility (Loading, Progress)
- [ ] 2. Match real world (natural language)
- [ ] 3. User control & freedom (Undo, Cancel)
- [ ] 4. Consistency & standards (unified UI)
- [ ] 5. Error prevention (confirmation dialogs)
- [ ] 6. Recognition vs recall (icon + label)
- [ ] 7. Flexibility & efficiency (shortcuts)
- [ ] 8. Aesthetic & minimal (avoid clutter)
- [ ] 9. Error reporting & recovery (clear messages)
- [ ] 10. Help & documentation (tooltips)

---

## Output Format

### Review result

```
## UI/UX Review

### 1️⃣ Material Design 3

🔴 **Critical**: `Button.tsx:15` - component states missing
- Issue: hover/focus/disabled undefined
- Fix: [code example]

🟡 **Warning**: `Card.tsx:8` - design tokens not used
- Issue: custom color #6750A4 hardcoded
- Fix: use bg-primary

### 2️⃣ WCAG 2.2 AA

🔴 **Critical**: `Form.tsx:42` - form label missing
- Issue: input has no associated label
- Fix: [code example]

🔴 **Critical**: `Hero.tsx:20` - insufficient contrast
- Issue: text-gray-300 on bg-gray-200 (2.1:1)
- Fix: use text-gray-900 (7:1)

### 3️⃣ Nielsen 10

🟡 **Warning**: `DeleteButton.tsx:5` - insufficient error prevention
- Issue: delete without confirmation (heuristic 5 violation)
- Fix: add AlertDialog

📊 **Summary**:
- Material Design 3: Critical 1 / Warning 1
- WCAG 2.2 AA: Critical 2 / Warning 0
- Nielsen 10: Warning 1

✅ **Overall**: Address Critical issues first
```

Zero issues:

```
## UI/UX Review

✅ All 3 principles (Material Design 3 / WCAG 2.2 AA / Nielsen 10) compliant

📊 **Summary**:
- Material Design 3: Critical 0 / Warning 0
- WCAG 2.2 AA: Critical 0 / Warning 0
- Nielsen 10: Critical 0 / Warning 0

### Recommended next steps
- Verify visual rendering with screenshots (auto checks miss visual issues)
- Usability testing (real user perspective)
```

No UI files detected:

```
> [WARN] No UI components found (*.tsx / *.jsx / *.vue)
> Skipping review
```

---

