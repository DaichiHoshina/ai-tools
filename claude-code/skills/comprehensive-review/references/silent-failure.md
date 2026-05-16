# Silent Failure Detection

Detect error suppression, empty catch blocks, inappropriate fallbacks.

## Checklist

| Check | Bad example | Level |
|-------|-------------|-------|
| **Empty catch / except** | `catch (e) {}` / `except: pass` | Critical |
| **Error suppression** | Go `_ = err` / `if err != nil { return nil }` (no log) | Critical |
| **Broad catch + log only** | Catch all, log, swallow | Critical |
| **Inappropriate fallback** | API fails → return empty array as success | Critical |
| **Unhandled Promise.catch** | `.catch(() => {})` / unhandled rejection | Critical |
| **Boolean return masks cause** | `success bool` only, root cause hidden | Warning |
| **Error type info lost** | `throw new Error(String(e))` loses stack | Warning |
| **Default suppresses error** | `parseInt(x) \|\| 0` (hides NaN) | Warning |

## Fix principles

- Error must **propagate OR be handled** (no suppression)
- If handled: express cause & recovery via type (Result, Either)
- Logging necessary but insufficient (caller must decide action)
