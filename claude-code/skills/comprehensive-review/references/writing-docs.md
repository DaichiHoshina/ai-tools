# Writing: Document Quality

## Scope

md files (Design Docs, READMEs, ADRs, reports), Notion drafts, PR descriptions, PRDs. Excludes code & code comments (code covered under `readability`).

## First principle

All checks derive from: "reduce reader cognitive load", "one read → understand", "avoid 'so what?'", "clarity over cleverness". When unsure: "does this reduce reader burden?". Details: `claude-code/guidelines/writing/PRINCIPLES.md`.

## Checklist

Single source of truth: `claude-code/lib/writing-self-check.sh` arrays `_WRITING_NG_EVAL` (evaluative) / `_WRITING_NG_STOCK` (stock). When divergent, trust lib/.

| Check | Bad example | Level |
|-------|-------------|-------|
| **Conclusion late** | "This document explains...", actual conclusion paragraphs later | Warning |
| **Unsupported claims** | Evaluative words ("appropriate", "optimal", "critical") without supporting sentence | Critical |
| **Vague abstractions** | "improve", "optimize", "enhance" with no adjacent numbers/examples | Critical |
| **Term dump** | "Observability", "loose coupling", "scalability" strung together, no context | Critical |
| **Implicit knowledge** | "As you know", "obviously", content not in 1 sentence | Warning |
| **Technical term undefined** | idempotency / Saga / RLS / CQRS first use without definition | Warning |
| **Paragraph role unclear** | Paragraph neither context / reason / example / conclusion / caveat | Warning |
| **Heading label-only** | Noun only ("Architecture", "Design decision") vs assertive ("Separate read/write to distribute load") | Warning |
| **Unanswered question** | Natural next question at end, not answered next | Info |
| **Implicit subject** | "Implemented", "will execute" — who/what unclear | Warning |
| **Missing 5W1H** | Decision lacking When / Where / Who | Warning |
| **Bullet no context** | 3+ bullets with no prose before/after | Warning |
| **AI stock phrases** | "effectively", "seamlessly", "innovative", "is considered" | Warning |
| **No reader action** | Missing "Reviewer check X", "Next: run Y" | Warning |

## Judgment

- **Critical**: 1+ → rewrite
- **Warning**: ≤3 → fix, ≥4 → rewrite

## Example

```
🔴 Critical: [writing] Unsupported "required" (docs/design/<feature>.md:45)
Fix: "SET LOCAL required" → "SET LOCAL required; session-scoped SET on pool leaks tenant to next request"
```
