# Command × Resource Map

## Legend

Resource coverage map for the four primary commands (`/dev` `/plan` `/review` `/flow`).

| Resource type | Auto-fired | Notes |
|---------------|-----------|-------|
| **rule** | Auto-applied at launch | Loaded from `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`, `claude-code/CLAUDE.global.md`. Project `.claude/rules/*.md` added if present. No explicit invoke. |
| **hook** | Auto-fired via settings.json | PreToolUse, PostToolUse, SessionStart, UserPromptSubmit, Stop, Notification. **Same across all commands.** No explicit invoke. |
| **agent** | Via Task tool | Parent launches with `Task(subagent_type)`: po-agent, manager-agent, developer-agent, reviewer-agent. |
| **skill** | Lazy-loaded | Step 0 shows recommended list (text only). Body loaded on `Skill()` call or manual Read. |
| **guideline** | Tech-stack detection | `load-guidelines` skill auto-detects. Referenced in Step 0. |

---

## Four primary commands × resources

### /dev - Implementation mode

| Resource | Details |
|----------|---------|
| **guideline** | **Required core**: `common/code-quality-design.md` / Conditional: `languages/typescript.md` (TypeScript), `languages/nextjs-react.md` (Next.js), `languages/golang.md` (Go) |
| **skill** | UI dev: `ui-skills`, Backend dev: `backend-dev`, Common: `cleanup-enforcement` |
| **agent** | None (direct execution, no Agent Team) |
| **hook** | Common across all commands (see Legend) |
| **rule** | plain JP style, markdown rules, enterprise security, AI output rules (auto-applied) |

**Step 0**: Conditionally runs `load-guidelines` (summary mode). Shows `ui-skills` for UI / `backend-dev` for backend.

---

### /plan - Design and planning mode

| Resource | Details |
|----------|---------|
| **guideline** | **Required**: `design/clean-architecture.md`, `design/domain-driven-design.md` / Conditional: `infrastructure/terraform.md` (Terraform), `languages/golang.md` (Go), etc. |
| **skill** | Recommended: `clean-architecture-ddd`, `api-design`, `microservices-monorepo` (when detected), `load-guidelines`, `terraform` (IaC planning) / mino design suite: 設計前提整理 `mino-problem-framing`, モデル欠落監査 `mino-domain-model-completeness`, 契約化 `mino-design-by-contract`, system-wide 品質 `mino-architecture-quality-strategy` |
| **agent** | po-agent (for complex planning) |
| **hook** | Common across all commands (see Legend) |
| **rule** | plain JP style, markdown rules, git merge prohibition (auto-applied) |

**Step 0**: Required guidelines (A) + language auto-detect (B) + infra planning (C) + skill integration (D). Appends reference to `references/command-resource-map.md`.

---

### /review - Review mode

| Resource | Details |
|----------|---------|
| **guideline** | **Required**: `common/code-quality-design.md` / Conditional: `load-guidelines` auto-loads on language/framework detection |
| **skill** | Recommended: `comprehensive-review` (main), Conditional: `uiux-review` (UI), `cleanup-enforcement`, 設計レビュー時: `mino-domain-model-completeness` / `mino-interface-implementation-separation` |
| **agent** | reviewer-agent (via PO/Manager path), pr-review-toolkit:* 6 types (with `--deep` option) |
| **hook** | Common across all commands (see Legend) |
| **rule** | AI output rules (auto-applied, generated comment prohibition) |

**Note**: `comprehensive-review` already calls `load-guidelines` internally. No command body change needed.

---

### /flow - Automated workflow execution

| Resource | Details |
|----------|---------|
| **guideline** | Loads guideline of matched skill after task-type determination (e.g., RCA loads `root-cause` skill guidelines) |
| **skill** | Dynamically selected by task type: design consultation → `clean-architecture-ddd`, 問題定義 → `mino-problem-framing`, 契約設計 → `mino-design-by-contract`, incident → `incident-response`, root cause → `root-cause`, data analysis → `data-analysis`, IaC → `terraform` |
| **agent** | po-agent (Step 1) → manager-agent (Step 2) → developer-agent×N (Step 3) → reviewer-agent (final review) |
| **hook** | Common across all commands (see Legend) |
| **rule** | plain JP style, markdown rules, git merge prohibition, root cause analysis rules (auto-applied) |

**Step 0**: "Step 0: select skill / agent after task-type determination". Placed before determination table.

---

## Verification Procedures

### Static verification

**Link validity (check all references from command-resource-map.md exist)**:

```bash
grep -oE '`[^`]+\.md`' claude-code/references/command-resource-map.md | \
  sed 's/`//g' | sort -u | while read p; do
    [[ "$p" != */* ]] && continue
    [[ "$p" =~ []*{}+[] ]] && continue
    [[ "$p" =~ ^(~|/) ]] && continue
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
wc -l claude-code/skills/load-guidelines/SKILL.md
```

---

## Related References

- `references/design-phase-flow.md` - Design phase transitions (brainstorm→prd→design-doc→plan)
- `references/natural-language-triggers.md` - Full natural language trigger list
