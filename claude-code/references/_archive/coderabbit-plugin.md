# CodeRabbit Claude Code Plugin

## Configuration

| Item | Value |
|------|-------|
| marketplace | `claude-plugins-official` |
| host | `coderabbitai/claude-plugin` |
| CLI | `~/.local/bin/coderabbit` (v0.4.3) |
| plugin version | v1.1.0 |

## Setup

```bash
# Install
claude plugin install coderabbit@claude-plugins-official

# Authenticate (GitHub integration)
coderabbit auth login
```

## Commands

| Command | Target |
|---------|--------|
| `/coderabbit:review` | All changes |
| `/coderabbit:review committed` | Committed changes only |
| `/coderabbit:review uncommitted` | Uncommitted changes only |
| `/coderabbit:review --base main` | Diff against main |

Also triggered by natural language "review the changes".

## Pricing (as of 2026-04)

| Plan | Details |
|------|---------|
| Free | Unlimited public/private, PR summary, IDE review |
| OSS public repo | Fully free (permanent) |
| Pro trial | 14 days (no credit card required) |
| Pro | $24/user/month |
| Pro Plus | $48/user/month |
| Enterprise | Contact sales |

## Docs

https://docs.coderabbit.ai/cli/claude-code-integration

## Note

Removing the `claude-plugins-official` marketplace does not remove the CodeRabbit plugin (managed separately). See `references/_archive/plugin-marketplace-caveats.md`.
