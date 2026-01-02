---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__delete_memory, mcp__serena__find_file, mcp__serena__find_referencing_symbols, mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__insert_after_symbol, mcp__serena__insert_before_symbol, mcp__serena__list_dir, mcp__serena__list_memories, mcp__serena__onboarding, mcp__serena__read_memory, mcp__serena__remove_project, mcp__serena__replace_regex, mcp__serena__replace_symbol_body, mcp__serena__restart_language_server, mcp__serena__search_for_pattern, mcp__serena__switch_modes, mcp__serena__think_about_collected_information, mcp__serena__think_about_task_adherence, mcp__serena__think_about_whether_you_are_done, mcp__serena__write_memory, mcp__context7__resolve-library-id, mcp__context7__get-library-docs
description: Token-efficient Serena MCP command for structured app development and problem-solving
---

## Options

| Option | Description | Usage |
|--------|-------------|-------|
| `-q` | Quick mode | `/serena "fix button" -q` |
| `-d` | Deep analysis | `/serena "architecture design" -d` |
| `-c` | Code-focused | `/serena "optimize" -c` |
| `-s` | Step-by-step + todos | `/serena "build feature" -s` |
| `-r` | Research with Context7 | `/serena "choose lib" -r` |
| `--lang` | Load language guidelines | `/serena "fix api" --lang=go` |

## Language Guidelines

When `--lang` specified, read the file first:

| Option | File |
|--------|------|
| `--lang=go` | `~/.claude/guidelines/languages/golang.md` |
| `--lang=ts` | `~/.claude/guidelines/languages/typescript.md` |
| `--lang=react` | `~/.claude/guidelines/languages/nextjs-react.md` |

Multiple: `--lang=go,ts`

## Onboarding Optimization

When `オンボーディング` is requested:

1. **Check memory first**: `list_memories` → look for `onboarding-{project-name}*`
2. **If exists**: Read memory and report "前回のオンボーディング情報を使用"
3. **If not exists**: Perform full analysis → Save to `onboarding-{project-name}-YYYY-MM`

## Execution

Use Serena MCP for all tasks:

1. **Detect** problem type (debug/design/implement/optimize/onboarding)
2. **Read** language guidelines if `--lang` specified
3. **Check memory** for onboarding (skip if exists)
4. **Analyze** with Serena's semantic code tools
5. **Research** with Context7 if `-r` specified
6. **Execute** with specific, actionable steps
7. **Save memory** if onboarding (for future reuse)
8. **Create todos** if `-s` specified

**Guidelines:**
- Use Serena MCP tools for all code operations
- If `--lang` specified, strictly follow language guidelines
- `-q`: minimal analysis, `-d`: thorough analysis
- End with concrete actions
