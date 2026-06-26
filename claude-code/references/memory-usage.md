# Memory Usage Guide

| Memory | Purpose | Auto-loaded |
|--------|---------|------------|
| auto-memory (`~/.claude/projects/{project}/memory/`) | Stable patterns / conventions / user preferences | Every session (200-line limit) |
| Serena memory | Work context / retrospectives / transient investigation results | Manual `read_memory` |

## Rules

- Don't write the same information to both
- Keep auto-memory concise — it consumes tokens every session
- **Task Diary**: propose `/memory-save` only when any of these apply at completion:
  - 3+ files changed
  - Refactor with non-obvious design decisions
  - Incident response
  - Otherwise, automatic accumulation to `~/.claude/logs/task-diary.log` is sufficient

## Recording Targets (Compounding Engineering)

Not only misbehavior but also **non-obvious successes** are recording targets. Boris-style compound improvement to ensure reproducibility.

Config side (CLAUDE.md / skill / hook) is primary; auto-memory is supplementary. Reason: auto-memory is written by Claude's automatic judgment and becomes stale; config side is more explicit and reproducible.

| Type | Example | Primary storage | Supplementary | Write method |
|------|---------|----------------|--------------|--------------|
| Misbehavior (recurrence prevention) | Same path error, unexpected file deletion | CLAUDE.md / skill / hook | auto-memory | User Edit / Claude auto |
| Non-obvious success (reproduction) | Trial-and-error hit, non-standard approach | CLAUDE.md / skill | auto-memory | User instruction / Claude |
| Transient investigation | Incident investigation state, unconfirmed hypothesis | Serena memory | — | User (`/memory-save`) |

**Write path notes:**

- **CLAUDE.md / skill / hook**: User edits directly, or Claude appends in same conversation if prompted "update CLAUDE.md or relevant skill"
- **auto-memory**: Claude auto-writes to `~/.claude/projects/{project}/memory/` from conversation context. Prone to duplication and staleness — config side takes priority
- **Serena memory**: Explicit save via `/memory-save`. Only for 3+ file changes / non-obvious decisions / incident response

Prioritize skill over memory for anything reproducible via config (skill is the right place). Memory is a "supplementary rule" / "pattern" store that Claude auto-references.

## Relocation pattern (optional)

auto-memory dir が encoded path で人間に辜りづらい / project 跨ぎで散逸する問題への対処として、auto-memory dir をやめて project / org / user の scope 別に repo 配下や user 私物 dir に集約する pattern がある。auto-load は失うが、user-readable / git 管理可能 / 横断検索容易の利得を取る。詳細: `memory-relocation-pattern.md`。
