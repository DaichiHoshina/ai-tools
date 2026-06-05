---
name: mcp-setup-guide
description: MCP server setup/troubleshoot for Claude Code. Use when setting up MCP.
---

# mcp-setup-guide - MCP Setup Guide

## Config Files

| Scope | Path |
|---------|------|
| Global | `~/.claude.json` |
| Project | `.claude/mcp.json` |

## Config Example

```json
{
  "mcpServers": {
    "serena": {
      "command": "serena",
      "args": ["start-mcp-server", "--context", "ide-assistant"]
    },
    "jira": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-jira"],
      "env": {
        "JIRA_HOST": "https://your.atlassian.net",
        "JIRA_EMAIL": "your@email.com",
        "JIRA_API_TOKEN": "your-token"
      }
    },
    "confluence": {
      "command": "node",
      "args": ["/path/to/confluence-mcp/dist/index.js"],
      "env": {
        "CONFLUENCE_HOST": "https://your.atlassian.net",
        "CONFLUENCE_EMAIL": "your@email.com",
        "CONFLUENCE_API_TOKEN": "your-token"
      }
    }
  }
}
```

## Troubleshoot

### 1. Failed to Connect

```bash
# Confirm command exists
which serena
# or
ls /path/to/command

# Manual run to check error
serena start-mcp-server --context ide-assistant
```

### 2. Permission Error

```bash
chmod +x /path/to/command
```

### 3. Environment Variable Issue

```bash
# Test directly in shell
JIRA_HOST="..." JIRA_EMAIL="..." npx -y @anthropic/mcp-jira
```

### 4. npx/node Path Issue

```json
{
  "command": "node",
  "args": ["/path/to/script.js"]
}
```

## Common MCP Servers

| Name | Purpose | Install |
|------|------|-------------|
| Serena | Code analysis | `pip install serena` |
| Jira | Ticket management | `npx @anthropic/mcp-jira` |
| Confluence | Documentation | Custom impl |
| Context7 | Library docs | `npx @anthropic/mcp-context7` |
| Codex | AI completion | `codex-mcp` |

## Verify Connection

```bash
# Inside Claude Code
/mcp
# → Check connection status
```

## Full Troubleshoot Failure

| Stage | Check |
|------|------|
| All steps 1-4 tried, still no connection | Restart Claude Code (reload config) |
| Still fails after restart | Run `claude --debug` to check startup logs |
| No clue in logs | Validate syntax: `jq . ~/.claude.json` |
| All OK but still no connection | Report issue to MCP server impl (identify repo URL from "Common MCP Servers" table) |

## Config Example Assumptions

| Item | Behavior |
|------|------|
| Env var is placeholder like `your-token` | Connection fails, ask user to set value |
| `command` path is relative, not absolute | Depends on Claude Code cwd, unstable. Use absolute path. |
