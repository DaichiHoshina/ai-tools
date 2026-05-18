---
allowed-tools: Read, Glob, Grep, mcp__serena__*
description: Legacy command. Use /dev or /diagnose (Serena MCP available in both)
---

# /serena (deprecated)

Legacy command, redirect to newer.

**Phase out**: keep file for backwards compat (`feedback_command_deletion.md` rule). No new doc links to this command. All refs replaced with `/dev` `/diagnose` `/refactor` `/plan` (see `docs/commands-quickref.md` `claude-code/COMMANDS-GUIDE.md`).

> When user runs `/serena`, Claude converts args (`-q`/`-d`/`-c`/`-s`/`-r`/`--lang`) per table below and auto-exec new command. Args not in table → infer closest intent.

## Migration Paths

| Old Option | New Command |
|------------|---------|
| `/serena "..." -q` | `/dev --quick "..."` |
| `/serena "..." -d` | `/diagnose "..."` or `/refactor "..."` (deep analysis) |
| `/serena "..." -c` | `/dev "..."` (code ops default use Serena MCP) |
| `/serena "..." -s` | `/plan "..."` → `/dev "..."` (phase split) |
| `/serena "..." -r` | `/dev "..." --research` (Context7 integration) |
| `/serena "..." --lang=go` | `/dev "..." --lang=go` (auto-load language guideline) |
| `/serena onboarding` | `Skill(load-guidelines)` + `mcp__serena__list_memories` |

## Why Deprecated

Serena MCP is default in `/dev` `/diagnose` `/refactor` `/plan` `/explore`. `/serena` only unique thing: onboarding memory bridge, now done via `Skill(load-guidelines)`.

ARGUMENTS: $ARGUMENTS
