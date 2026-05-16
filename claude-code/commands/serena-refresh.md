---
allowed-tools: Bash, Read, AskUserQuestion, mcp__serena__*
description: Refresh Serena data and memory - update symbol DB and organize
---

## /serena-refresh

Update serena symbol database and memory after large changes.

## When to Use

- large refactoring completed
- many files added/deleted
- symbol search not returning expected results
- want to organize old memory

## Flow

1. **Check state** - `pwd`, `ls -la .serena`
2. **Re-activate** - `mcp__serena__activate_project(project=".")`
3. **Confirm onboarding** - run if not done
4. **Update symbols** - run `get_symbols_overview` on main files
5. **Organize memory**
   - list all → review content → identify unused
   - **ask user before deleting** (don't delete unilaterally)
   - propose memory consolidation
6. **Report done**

## Memory Cleanup Criteria

- completed task, now obsolete
- duplicate info
- outdated info
- consolidatable content

**Don't modify code files. Update only .serena database and memory.**
