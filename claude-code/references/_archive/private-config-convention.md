# Private Config Storage Convention

Convention for running personal/project-specific commands, skills, and hooks directly under `~/.claude/` without including them in the public repo.

## Motivation

- The public repo (`ai-tools`) is on GitHub with permanent history. Do not mix in confidential strings like company names, project names, or codenames
- Project-specific commands and skills are essential for personal workflows, but non-generalizable ones pollute the repo
- Extends the existing `~/.claude/references-private/` convention to commands/skills/hooks

## Naming Convention

| Use | Location | Example |
|-----|----------|---------|
| Personal command | `~/.claude/commands/private-*.md` | `private-deploy-staging.md` |
| Personal skill | `~/.claude/skills/private-*/` | `private-domain-rules/` |
| Personal hook | `~/.claude/hooks/private-*.sh` | `private-postedit-checker.sh` |
| Equivalent alternative | `local-*` prefix treated the same | `local-foo.md` |

**Prohibited**: Do not place `private-*` / `local-*` prefixed files/directories in the public repo (`ai-tools`). Do not include project names, company names, or codenames anywhere (including comments and commit messages).

## Protection Mechanism (install.sh / sync.sh)

`private-*` and `local-*` prefixes are protected from destructive sync:

- **install.sh**: Uses `rsync --exclude='private-*' --exclude='local-*'` when overwriting skills/hooks
- **sync.sh sync_to_local**: `preserve_private` → `rm -rf` → `cp -r` → `restore_private` evacuation pattern for all directories
- **sync.sh sync_from_local**: `rsync --exclude` prevents leakage to repo (most critical)

When adding new directories to SYNC_ITEMS / install targets, inherit the same protection.

## Intended Workflow

1. A project-specific command becomes necessary
2. Create `~/.claude/commands/private-{purpose}.md` directly (don't create in repo `commands/`)
3. Claude Code loads it automatically
4. Protection mechanism prevents deletion when `install.sh` / `sync.sh` runs
5. Backup is the owner's responsibility (outside repo management). Use a separate private repo or tar if desired

## Anti-Patterns

- Place `commands/private-foo.md` inside repo and exclude with `.gitignore` → accidental commit risk
- Write project name in repo comments → discoverable by grep, potential leak
- Hardcode project names in protection mechanism implementation → string remains in public repo (implement with generic prefix)
