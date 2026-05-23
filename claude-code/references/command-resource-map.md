# Command × Resource Map

## Legend

Resource coverage map for the four primary commands (`/dev` `/plan` `/review` `/flow`).

| Resource type | Auto-fired | Notes |
|-----------|---------|------|
| **rule** | Auto-applied at launch | Loaded from `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`, `claude-code/CLAUDE.md`. Project `.claude/rules/*.md` added if present. No explicit invoke. |
| **hook** | Auto-fired via settings.json | PreToolUse, PostToolUse, SessionStart, UserPromptSubmit, Stop, Notification. **Same across all commands.** No explicit invoke. |
| **agent** | Via Task tool | Parent launches with `Task(subagent_type)`: po-agent, manager-agent, developer-agent, reviewer-agent. |
| **skill** | Lazy-loaded | Step 0 shows recommended list (text only). Body loaded on `Skill()` call or manual Read. |
| **guideline** | Tech-stack detection | `load-guidelines` skill auto-detects. Referenced in Step 0. |

---

## Four primary commands × resources

### /dev - Implementation mode

| Resource | Details |
|---------|-----------|
| **guideline** | **Required core**: `common/code-quality-design.md` / Conditional: `languages/typescript.md` (TypeScript detected), `languages/nextjs-react.md` (Next.js detected), `languages/golang.md` (Go detected) |
| **skill** | UI dev: `ui-skills`, Backend dev: `backend-dev`, Common: `simplify`, `cleanup-enforcement` |
| **agent** | None (direct execution, no Agent Team) |
| **hook** | Common across all commands (see Legend) |
| **rule** | genshijin mode, markdown rules, enterprise security, AI output rules (auto-applied) |

**Step 0**: Conditionally runs `load-guidelines` (summary mode). Shows `ui-skills` for UI / `backend-dev` for backend.

---

### /plan - Design and planning mode

| Resource | Details |
|---------|-----------|
| **guideline** | **Required**: `design/clean-architecture.md`, `design/domain-driven-design.md` / Conditional: `infrastructure/terraform.md` (Terraform detected), `languages/golang.md` (Go detected), etc. |
| **skill** | Recommended: `clean-architecture-ddd`, `api-design`, `microservices-monorepo` (when detected), `load-guidelines`, `terraform` (IaC planning) |
| **agent** | po-agent (for complex planning) |
| **hook** | Common across all commands (see Legend) |
| **rule** | genshijin mode, markdown rules, git merge prohibition (auto-applied) |

**Step 0**: Required guidelines (A) + language auto-detect (B) + infra planning (C) + skill integration (D). Appends reference to `references/command-resource-map.md`.

---

### /review - Review mode

| Resource | Details |
|---------|-----------|
| **guideline** | **Required**: `common/code-quality-design.md` / Conditional: `load-guidelines` auto-loads on language/framework detection |
| **skill** | Recommended: `comprehensive-review` (main), Conditional: `uiux-review` (UI), `cleanup-enforcement` |
| **agent** | reviewer-agent (via PO/Manager path), pr-review-toolkit:* 6 types (with `--deep` option) |
| **hook** | Common across all commands (see Legend) |
| **rule** | AI output rules (auto-applied, generated comment prohibition) |

**Note**: `comprehensive-review` already calls `load-guidelines` internally. No command body change needed.

---

### /flow - Automated workflow execution

| Resource | Details |
|---------|-----------|
| **guideline** | Loads guideline of the matched skill after task-type determination (e.g. RCA determination loads `root-cause` skill guidelines) |
| **skill** | Dynamically selected by task type. Examples: design consultation → `clean-architecture-ddd`, incident → `incident-response`, root cause → `root-cause`, data analysis → `data-analysis`, IaC → `terraform` |
| **agent** | po-agent (Step 1: design consultation) → manager-agent (Step 2: schedule creation) → developer-agent×N (Step 3: parallel implementation) → reviewer-agent (final review) |
| **hook** | Common across all commands (see Legend) |
| **rule** | genshijin mode, markdown rules, git merge prohibition, root cause analysis rules (auto-applied) |

**Step 0**: "Step 0: select skill / agent after task-type determination". Placed before determination table.

---

## Verification procedures

### Static verification

**Link validity (check all references from command-resource-map.md exist)**:

```bash
# Extract file paths in inline code format and verify existence (claude-code/ as root)
# Target: relative paths containing directory only (skip standalone filenames / glob/brace/regex literals)
grep -oE '`[^`]+\.md`' claude-code/references/command-resource-map.md | \
  sed 's/`//g' | sort -u | while read p; do
    [[ "$p" != */* ]] && continue          # Skip no-directory entries (descriptive terms)
    [[ "$p" =~ []*{}+[] ]] && continue     # Skip glob/brace/regex literals
    [[ "$p" =~ ^(~|/) ]] && continue       # Skip absolute paths / home
    if [[ "$p" =~ ^claude-code/ ]]; then
      target="$p"
    elif [[ "$p" =~ ^(common|design|languages|infrastructure|backend|operations)/ ]]; then
      target="claude-code/guidelines/$p"
    else
      target="claude-code/$p"
    fi
    test -e "$target" || echo "BROKEN: $p (resolved: $target)"
  done
```

**Markdown syntax check**:

```bash
mdl claude-code/references/command-resource-map.md
```

### Dynamic verification

1. **`/dev "dummy test task"`** → Step 0 shows skill list
2. **`/flow "dummy test task"`** → Step 0 shows skill list
3. **`/plan "dummy test task"`** → `command-resource-map.md` reference at end of Step 0
4. **`/review`** → `comprehensive-review` calls `load-guidelines` internally

### Resource coverage check

```bash
# command ≤150 lines, skill ≤300 lines
wc -l claude-code/commands/{dev,flow,plan,review}.md
wc -l claude-code/skills/load-guidelines/skill.md
```

---

## Related references

- `references/design-phase-flow.md` - Design phase transitions (brainstorm→prd→design-doc→plan)
- `references/natural-language-triggers.md` - Full natural language trigger list
