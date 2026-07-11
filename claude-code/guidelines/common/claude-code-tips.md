# Claude Code Practical Tips

> **Purpose**: Context management / compaction tips for Claude Code operation. Reference when session length or token consumption is a concern.

## Context Management

| Item | Detail |
|------|--------|
| Monitor | Brain mark in statusLine = context size |
| Compaction threshold | Auto compact triggers above 80% → quality degrades |
| **Rule** | **Restart after task completion** (Ctrl-C ×2 or `/exit`) |
| Check | `/context` to view usage |

### Handling Compaction

| Avoid | Recommended |
|-------|-------------|
| Ignore frequent compaction | Turn off auto-compact → use manual `/compact` |
| Do nothing after compact | Run `/reload` after compact to re-read CLAUDE.md |
| Leave session open after task | Restart after completing a task set |

---

## Sub-agents

Delegation の使い分け (inline vs 並列 fan-out) は `CLAUDE.global.md` の Auto-Delegation 表が正。本節は CLI 操作のみ扱う。

| Item | Detail |
|------|--------|
| Worktree isolation | `isolation: "worktree"` for independent copy per agent (v2.1.47+) |
| Manage | `claude agents` to list running agents (CLI) |
| Stop | Ctrl+F to stop background agents |

---

## Common Commands

| Command | Purpose |
|---------|---------|
| `/resume` | Resume past session |
| `/rename` | Rename session (no arg → auto-generate) |
| `mcp__serena__onboarding` | Initialize new project (replaces deprecated `/serenaオンボーディング`) |
| `/memory-clean` | Auto-memory 整理 (default dry-run、Serena symbol DB refresh は `/serena-update-fix` で独立実行) |
| `/reload` | Recovery after compact |
| `/doctor` | Check environment |
| `/status` | Check settings |
| `/context` | Check context size |
| `claude auth login` | Authenticate (CLI) |
| `claude auth status` | Check auth status (CLI) |
| `claude auth logout` | Log out (CLI) |
| `claude agents` | List running agents (CLI) |

---

## File Reference (v2.1.41+)

| Syntax | Description |
|--------|-------------|
| `@README.md` | Reference entire file |
| `@README.md#installation` | Reference a specific section (anchor fragment) |

**Use case**: Useful when you need to reference a specific documentation section precisely during a conversation.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Unexpected behavior | Esc / rewind の使い分けは `references/checkpoint-rewind.md` 参照 |
| Background runaway | Ctrl+F to stop background agent |
| Frequent compaction | Restart after task completion |
| Auth error | Check `claude auth status` → re-auth with `claude auth login` |
| AWS auth hang | v2.1.41 added 3-min timeout (auto-recovers) |

---

## Git Worktree

Useful for parallel work across multiple Claude Code instances. For simple tasks, instruct "no worktree needed, just branch."

---

## Cost Management

| Item | Detail |
|------|--------|
| Check cost | View in statusLine |
| MCP | Keep to minimum (heavy context consumption) |
| Skill | Load knowledge only when needed |
| Task split | Restart after finishing |
