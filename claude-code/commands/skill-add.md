---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Skill, TaskCreate, TaskUpdate
description: Add new skill - run skill-creator → validate with skill-lint → sync
---

## /skill-add - New Skill Addition

Create `claude-code/skills/<name>/skill.md`, validate via `scripts/skill-lint.sh`, then sync to `~/.claude/`.

**Source of truth**: lowercase `skill.md` (per `commands/claude-update-fix.md` convention).

> **skill-creator note**: expect external plugin (Anthropic Superpowers etc). This repo doesn't bundle it. On missing, auto-fallback to minimal template. To use skill-creator, install plugin separately. For template-only, pass `--skip-creator`.

## Arguments

```
/skill-add <skill-name> [--skip-creator]
```

| Argument | Desc |
|----------|------|
| `<skill-name>` | new skill name (kebab-case recommended, matches `skills/<name>/` dir) |
| `--skip-creator` | skip skill-creator, use minimal template (manual edit expected) |

## Execution Flow

```yaml
steps:
  - id: validate-name
    rule: |
      - kebab-case only (`^[a-z][a-z0-9-]+$`)
      - no existing skill name duplicate (`skills/<name>/` must not exist)
      - if dup, offer alternative names + stop

  - id: create-dir
    action: mkdir -p claude-code/skills/<name>

  - id: invoke-skill-creator
    when: not --skip-creator
    action: |
      call Skill("skill-creator") (fallback to minimal template if missing)
      dialog: name / description / requires-guidelines / body

  - id: minimal-template
    when: --skip-creator OR skill-creator absent
    action: |
      write `claude-code/skills/<name>/skill.md` with minimal frontmatter + skeleton

  - id: lint
    action: |
      ./claude-code/scripts/skill-lint.sh --skill <name>
      if fail: fix frontmatter, re-run (max 3x)

  - id: sync
    action: ./claude-code/sync.sh
    note: always run to check install.sh/sync.sh impact range

  - id: report
    action: show final status (pass/warn/fail) + bench-ref
```

## Rollback on Lint Failure

If lint fails 3x consecutive, try:

- **retry**: manual edit `skills/<name>/skill.md`, re-run `skill-lint --skill <name>`
- **restart**: `rm -rf claude-code/skills/<name>`, run `/skill-add <name>` again
- **defer**: WIP note in `skill.md` header, push for later completion

If skill-creator fails after create-dir, cleanup: `rm -rf claude-code/skills/<name>`.

## Minimal Template

Lint-passing minimum. Trigger words required (see below). New `claude-code/skills/<name>/skill.md`:

```markdown
---
name: <name>
description: <concise desc 30-200 chars, must include trigger word>
requires-guidelines:
  - common
---

# <name> - <title>

## When to Use

- <condition 1>
- <condition 2>

## Main Points

<body>
```

## Description Trigger Words (required)

`scripts/skill-lint.sh` checks for these in `description:`:

| Word | Example |
|------|---------|
| when used / when | "Use when refactoring …" |
| corresponding | "Docker/Kubernetes support" |
| for | "guide for backend" |
| Use this / When | "Use this when refactoring …" |

Missing → lint warning, fails on `--strict`. Add one to pass.

## Validate

```bash
# single skill
./claude-code/scripts/skill-lint.sh --skill <name>

# all (recommended, keep warn=0)
./claude-code/scripts/skill-lint.sh --strict

# fire rate later (few days after)
./claude-code/scripts/skill-eval.sh --skill <name> --days 7
```

## Lint Failures

| Error | Fix |
|------|-----|
| `name does not match dir name` | fix frontmatter `name:` to `<name>` |
| `description too short/long` | fit 30-200 chars |
| `description lacks trigger phrase` | add one from table above |
| `requires-guidelines must be list` | `- common` YAML format |
| sync.sh conflict | stash `~/.claude/skills/<name>/`, re-sync |

## Out of Scope

- skill content quality (use `comprehensive-review` separately)
- existing skill description rewrite (separate PR)
- direct add to global `~/.claude/skills/` (outside this repo)

