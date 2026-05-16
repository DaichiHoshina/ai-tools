---
name: skills-manage
description: Manage community skills via gh skill - search/install/update with tree SHA verification, version pinning, source tracking
---

# /skills-manage - Community Skill Management

Use GitHub's `gh skill` command (v2.90.0+, preview) with supply-chain protection (tree SHA check, version pin, source tracking metadata).

**Prerequisite**: `gh` v2.90.0+ (upgrade: `brew upgrade gh`).

## Usage

```text
/skills-manage search <query> [--owner <org>]
/skills-manage preview <owner/repo> <skill>
/skills-manage install <owner/repo> <skill> [--pin <tag>] [--force]
/skills-manage update [--all | <skill-name>] [--dry-run]
/skills-manage list
/skills-manage remove <skill-name>
```

`list` / `remove` not in `gh skill` yet, run locally.

## Execution Flow

### search

```bash
gh skill search "<query>" [--owner <org>]
```

Use `--owner` to narrow trusted org, strengthens supply-chain protection.

### preview

```bash
gh skill preview <owner/repo> <skill>
```

Check SKILL.md before install.

### install

```bash
gh skill install <owner/repo> <skill> --agent claude-code --scope user [--pin <tag>] [--force]
```

- `--scope user` (recommended): place in `~/.claude/skills/`, shared all projects
- `--scope project` (default): place in `<cwd>/.claude/skills/`, repo-local
- `--pin <tag>` freeze version or `skill@v1.2.0` syntax
- `--force` overwrite existing
- SKILL.md frontmatter auto-inject source tracking (source repo / git ref / tree SHA) → `update` detects diff

### update

```bash
gh skill update [--all | <skill-name>] [--dry-run]
```

- tree SHA compare detects diff
- pinned skills skip (unpin via `--unpin`)
- `--dry-run` preview change
- `--force` overwrite local edits, fetch fresh

### list

```bash
ls -1 ~/.claude/skills/
```

### remove

**Confirm before delete**. Guard against typo via shell check:

```bash
SKILL="<skill-name>"; [ -n "$SKILL" ] && rm -rf "$HOME/.claude/skills/$SKILL"
```

## Supported Skill Repos

| Repo | Content |
|------|---------|
| `github/awesome-copilot` | GitHub official |
| `vercel-labs/agent-skills` | React/Next.js |
| `anthropics/skills` | Anthropic official |
| others adhering agentskills.io spec | generic (skills/*/SKILL.md structure) |

## Install Location

- `--scope user` (recommended): `~/.claude/skills/<skill-name>/SKILL.md`
- `--scope project`: `<cwd>/.claude/skills/<skill-name>/SKILL.md`

Not in ai-tools git, so re-run `gh skill install` per machine.

## Plugin Distribution (`--plugin-url` / `--plugin-dir`, CLI 2.1.128+)

For plugin bundles (hooks/commands/skills bundle), not just single skill, use standard plugin install:

```bash
claude plugin install --plugin-url <url>      # fetch URL (2.1.128)
claude plugin install --plugin-dir <path>     # local zip/dir (2.1.129)
```

- use: distribute internal-only plugins via private URL / S3 / Artifactory, trial plugins via local zip
- single skill: stick with `gh skill install` (tree SHA verify + source tracking)
- plugin manifest (`plugin.json`) required, per agentskills.io/specification

## sync.sh Integration

`./claude-code/sync.sh to-local` deletes → redeploy `~/.claude/skills/`, but `gh skill`-installed skills auto-detected (SKILL.md frontmatter `metadata.github-repo`) → backed up/restored. No data loss via sync.

Guard condition: SKILL.md (or skill.md) frontmatter contains `github-repo: https://github.com/...`. To protect manually-installed skill, add same metadata.

## Reference

- Article: <https://zenn.dev/ubie_dev/articles/gh-skill-install-agent-skills>
- Spec: <https://agentskills.io/specification>
