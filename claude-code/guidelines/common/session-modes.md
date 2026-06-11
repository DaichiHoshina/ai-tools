# Session Modes

Defines the operation mode for the entire session. Confirmation flow and constraint level change based on mode.

---

## Mode List

| Mode | Confirmation Level | Use Case |
|------|--------------------|---------|
| **strict** | Confirm all Boundary operations | Production work, critical refactoring |
| **normal** | Standard confirmation (default) | Normal development |
| **fast** | Minimize confirmation | Prototyping, exploratory development |

---

## Mode Operation Matrix

| Aspect | strict | normal (default) | fast |
|--------|--------|------------------|------|
| **Operations requiring confirmation** | git commit/push/merge / file delete / config file change / package add / DB ops | git commit/push/merge / important file delete / config file change | git push / important file delete (src//.git/) |
| **Auto-allowed operations** | File read / code analysis / suggestions | File read/edit / code analysis / npm install / lint | git commit (local) / file edit/delete / npm install / lint/test |
| **Use scenario** | Production / critical refactor / security changes / large teams | Daily dev / feature add / bug fix | Prototype / exploratory dev / personal project |

---

## Load Thinking

```
/protection-mode        # Basic (operation guard + 3-layer classification)
/protection-mode full   # Full (+ mode definition)
```

Mode is a guide for thinking strictness. Loading `/protection-mode` enables context-appropriate judgment.

---

## Mode Persistence

Mode is saved in Serena Memory and persists across sessions.

```yaml
memory_key: "session-mode"
content:
  mode: "strict" | "normal" | "fast"
  activated_at: ISO8601
  previous_mode: string | null
```

---

## Relationship to 8 Principles

The 8 principles are **valid in all modes**. Mode only controls the strictness of the confirmation flow.

| Principle | strict | normal | fast |
|-----------|--------|--------|------|
| mem (Serena memory) | ✅ | ✅ | ✅ |
| serena (MCP use) | ✅ | ✅ | ✅ |
| guidelines (auto-load) | ✅ | ✅ | ✅ |
| No auto-processing | ✅ strict | ✅ | ⚡ relaxed |
| Completion notification | ✅ | ✅ | ✅ |
| Type safety | ✅ | ✅ | ✅ |
| Command suggestion | ✅ | ✅ | ✅ |
| Confirmed | ✅ strict | ✅ | ⚡ relaxed |

---

## Context Management

| Item | Limit / Threshold | Action |
|------|-------------------|--------|
| MCP configured | ≤20 | (exceeding this greatly reduces context) |
| MCP enabled | ≤8 | Disable unused MCPs |
| MCP tools | <50 | — |
| Usage 70% | — | Consider `/compact` |
| Usage 85% | — | Disable unnecessary MCPs |
| Usage 95% | — | Start new session |

**Memory management**: Load once at startup / delete completed tasks immediately / no repeated loading

---

## Related

- `guardrails.md` — operation classification (Safe/Boundary/Forbidden)
- `/protection-mode` command — load category-theory thinking
