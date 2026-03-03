---
name: skill-creator
description: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Codex's capabilities with specialized knowledge, workflows, or tool integrations.
metadata:
  short-description: Create or update a skill
---

# Skill Creator

## About Skills

Skills are modular, self-contained folders extending Codex's capabilities with specialized workflows, tool integrations, domain expertise, and bundled resources.

## Core Principles

### Concise is Key

Context window is a shared resource. Only add context Codex doesn't already have. Challenge each piece: "Does Codex really need this?" Prefer concise examples over verbose explanations.

### Degrees of Freedom

| Level | When to use |
|-------|-------------|
| High (text instructions) | Multiple valid approaches, context-dependent decisions |
| Medium (pseudocode/scripts with params) | Preferred pattern exists, some variation acceptable |
| Low (specific scripts, few params) | Fragile operations, consistency critical |

### Skill Structure

```
skill-name/
├── skill.md (required) - YAML frontmatter + Markdown instructions
├── agents/openai.yaml (recommended) - UI metadata
└── (optional)
    ├── scripts/   - Executable code for deterministic reliability
    ├── references/ - Documentation loaded into context as needed
    └── assets/    - Output files (templates, images, fonts)
```

**Skill naming:** lowercase, hyphens only, under 64 chars, verb-led (e.g., `rotate-pdf`, `gh-address-comments`).

**Do NOT include:** README.md, CHANGELOG.md, or other auxiliary docs.

### SKILL.md Frontmatter

- `name`: skill name
- `description`: Primary trigger mechanism. Include what skill does AND when to use it. Example:
  > "Comprehensive document editing with tracked changes support. Use when working with .docx files for: (1) Creating, (2) Editing, (3) Tracked changes, (4) Comments"

### Progressive Disclosure

Three-level loading:
1. Metadata (name + description) - always in context (~100 words)
2. skill.md body - when skill triggers (<5k words, keep under 500 lines)
3. Bundled resources - loaded as needed

Keep skill.md lean: move variant-specific details to references files. Reference them clearly with when-to-read guidance. Keep references one level deep; no nested references.

## Skill Creation Process

1. Understand - Gather concrete examples
2. Plan - Identify scripts/references/assets needed
3. Initialize - Run `init_skill.py`
4. Edit - Implement resources and write skill.md
5. Validate - Run `quick_validate.py`
6. Iterate - Improve based on real usage

### Step 1: Understand

Collect concrete usage examples from the user. Key questions:
- "What functionality should this skill support?"
- "Can you give examples of how it would be used?"
- "What would trigger this skill?"

Avoid asking too many questions at once.

### Step 2: Plan Reusable Contents

For each example, identify reusable resources:
- Repeated code → `scripts/`
- Repeated schema/doc lookup → `references/`
- Boilerplate output files → `assets/`

### Step 3: Initialize

For new skills, always run:

```bash
scripts/init_skill.py <skill-name> --path skills/public [--resources scripts,references,assets]
```

Skip if skill already exists. After init, customize skill.md and add resources.

Generate `agents/openai.yaml` with:

```bash
scripts/generate_openai_yaml.py <path/to/skill-folder> --interface key=value
```

See `references/openai_yaml.md` for field definitions.

### Step 4: Edit

Write for another Codex instance: include non-obvious procedural knowledge and domain-specific details.

**Design guides:**
- Multi-step processes → `references/workflows.md`
- Output formats/quality → `references/output-patterns.md`

**Scripts:** Test by actually running them. Test a representative sample if many similar scripts exist.

### Step 5: Validate

```bash
scripts/quick_validate.py <path/to/skill-folder>
```

Checks YAML frontmatter, required fields, naming rules. Fix reported issues and rerun.

### Step 6: Iterate

After real usage:
1. Notice struggles or inefficiencies
2. Identify skill.md or resource improvements
3. Implement and test again
