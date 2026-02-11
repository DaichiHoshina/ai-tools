---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
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
