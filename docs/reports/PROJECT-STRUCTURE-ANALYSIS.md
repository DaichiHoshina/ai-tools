# ai-tools Project Structure Analysis

**Created**: 2026-02-08
**Model**: Claude Opus 4.6
**Target**: /Users/daichi/ai-tools
**Score**: 94/100

---

## 1. Project overview

`/Users/daichi/ai-tools` centrally manages Claude Code (Anthropic) and Codex (OpenAI) configuration, skills, guidelines, and hooks to enable reproducible environments across multiple machines. Primary purpose: optimize AI-assisted development workflows.

---

## 2. Top-level structure

```
ai-tools/
├── claude-code/          # Main component (Claude Code config)
│   ├── agents/           # 8 agent definitions
│   ├── commands/         # 20 command definitions
│   ├── guidelines/       # 28+ guidelines
│   ├── hooks/            # 12 event hooks
│   ├── lib/              # 9 shared libraries
│   ├── skills/           # 26 skill definitions
│   └── tests/            # BATS unit tests + integration tests
├── codex/                # Codex (OpenAI) support
├── docs/                 # Documentation / reports
│   └── reports/          # Analysis reports (organized in Phase 1)
├── scripts/              # CI/test automation
└── .github/workflows/    # CI/CD (5 jobs parallel)
```

---

## 3. Core components

### 3.1 Agent hierarchy (8 types)

```
po-agent (strategy decisions)
  └── manager-agent (task decomposition)
       ├── developer-agent (implementation 1–4, parallelizable)
       ├── explore-agent (read-only exploration)
       └── reviewer-agent (final review)
           └── code-simplifier (complexity reduction)
               └── verify-app (build / test / lint)
```

**Complexity judgment and execution path**:
- Simple (files < 5, lines < 300): direct execution
- TaskDecomposition (files ≥ 5 OR independent features ≥ 3): TaskCreate/TaskUpdate management
- AgentHierarchy (cross-project): PO/Manager/Developer hierarchy

### 3.2 Command system (20 commands)

**Tier 1 (Core 3)**: `/flow` (universal workflow auto-detection, 14 tools) / `/dev` (implementation only, 12 tools) / `/review` (comprehensive code review)

**Tier 2 (frequent)**: `/commit`, `/commit-push-pr`, `/plan`, `/diagnose`

**Tier 3 (specialized)**: `/test`, `/refactor`, `/quick-fix`, `/tdd`, `/explore`, `/retrospective`, etc.

### 3.3 Skill system (26 skills → 14 planned)

- Review (5): code-quality-review, security-error-review, docs-test-review, uiux-review, comprehensive-review
- Development (6): go-backend, typescript-backend, react-best-practices, api-design, clean-architecture-ddd, grpc-protobuf
- Infrastructure (5): dockerfile-best-practices, kubernetes, terraform, microservices-monorepo, docker-troubleshoot
- Utility (6+): load-guidelines, ai-tools-sync, cleanup-enforcement, etc.

### 3.4 Guidelines (28+ files, 5 categories)

| Category | Files | Description |
|---------|-------|-------------|
| common/ | 15 | Universal principles across all languages |
| languages/ | 8 | Go, TS, React, Python, Rust etc. |
| design/ | 2 | Clean Architecture, DDD |
| infrastructure/ | 5 | AWS (ECS, EKS, Lambda, EC2, Terraform) |
| summaries/ | 8 | Token-saving version (~2,500 tokens) |

### 3.5 Hooks (automation foundation, 12 types)

| Hook | Timing | Responsibility |
|------|--------|---------------|
| session-start.sh | Session start | Apply protection-mode, suggest Serena memory |
| user-prompt-submit.sh | On prompt submit | Tech stack detection, skill recommendation (most important) |
| pre-tool-use.sh | Before tool execution | protection-mode 3-tier classification (Safe/Boundary/Forbidden) |
| pre-skill-use.sh | Before skill execution | Auto-load guidelines |
| pre-compact.sh | Before compaction | Force Serena memory auto-save instruction |
| session-end.sh | Session end | Save stats log, notification sound, detect git changes |

Notable design: user-prompt-submit.sh uses bash4+ associative arrays for 4-layer detection (file patterns / keywords / error logs / git status). pre-tool-use.sh: category-theoretic operation classification via Guard functor.

### 3.6 Shared libraries (9 files)

| File | Responsibility | Dependency |
|------|---------------|-----------|
| security-functions.sh | OWASP countermeasures, input validation | none |
| colors.sh | ANSI color codes | none |
| print-functions.sh | Output helpers | colors.sh |
| i18n.sh | Internationalization (JP/EN) | bash 4.2+ |
| hook-utils.sh | Hook common processing | jq |
| detect-from-files.sh | File path detection | git |
| detect-from-keywords.sh | Keyword detection + cache | jq, md5sum |
| detect-from-errors.sh | Error log detection | none |
| detect-from-git.sh | Git status detection | git |

---

## 4. Tech stack

| Technology | Purpose | Files |
|-----------|---------|-------|
| Bash | Hooks, installers, sync, tests | ~30 |
| JavaScript (Node.js) | Status line | 1 |
| Markdown | Commands, skills, guidelines, agents | ~120 |
| YAML | CI/CD, frontmatter | ~3 |
| JSON | Config, MCP | ~5 |
| Python | skill-creator/installer scripts | ~5 |

Tools: Claude Code / Serena MCP / Context7 / BATS / ShellCheck / GitHub Actions

---

## 5. CI/CD (5 jobs parallel)

1. **shellcheck**: static analysis of all .sh files
2. **markdownlint**: linting of all .md files
3. **bats-test**: BATS unit tests
4. **install-test**: install.sh verification
5. **sync-test**: sync.sh verification

---

## 6. Sync mechanism

### install.sh (initial setup)
`ai-tools/claude-code/` → `~/.claude/` via cp

### sync.sh (bidirectional sync)
- `to-local`: ai-tools/ → ~/.claude/
- `from-local`: ~/.claude/ → ai-tools/
- `diff`: diff display only

Security: converts `$HOME` path to `__HOME__`; converts tokens/keys in `.env` to placeholders.

---

## 7. Strengths (7 points)

1. Comprehensive automation foundation: consistent automation with 12 event hook types
2. Token efficiency optimization: 2-tier loading via guidelines/summaries/, Safe message omission
3. High security awareness: OWASP countermeasures, token masking, 3-tier classification
4. High extensibility: loose coupling of skills / guidelines / hooks
5. Multi-tool support: Claude Code + Codex (shared resources)
6. CI/CD integration: ShellCheck, markdownlint, BATS, install/sync tests
7. Context protection: automatic backup to Serena memory

---

## 8. Potential issues (10 points)

1. skill.md / SKILL.md inconsistency → Resolved in Phase 1
2. Shebang environment dependency → Resolved in Phase 1
3. Document bloat → Resolved in Phase 1
4. detect function duplication → Phase 2 planned
5. Skill count growth trend (25 → 14 integration plan) → Phase 2 planned
6. Codex support incompleteness → Phase 3 planned
7. settings.json template hardcoding → Phase 2 planned
8. Test coverage skew → Phase 2 planned
9. guidelines-archive management → Phase 3 planned
10. Shared library dependency chain → Phase 2 planned

---

## 9. Naming conventions

| Pattern | Example | Purpose |
|---------|---------|---------|
| kebab-case.md | code-quality-review | Skill names, guideline names |
| kebab-case.sh | session-start.sh | Hook scripts |
| UPPER-CASE.md | CLAUDE.md, SKILLS-MAP.md | Project-level documents |

---

## 10. Summary

ai-tools systematically realizes configuration management for AI-assisted development environments centered on Claude Code. With 12 event hooks, 26 skills, 28 guidelines, 20 commands, and 8 agents, it builds a consistent pipeline: tech stack auto-detection → skill recommendation → guideline application → agent hierarchy execution → verification → PR creation.

Design philosophy: "Guard functor" (category-theoretic operation classification), "Progressive Disclosure" (staged token loading), "Boris style" (maximum results from minimal instructions). This is a framework for AI development workflows beyond mere configuration files.

**Score**: 94/100  
**Improvement direction**: Phase 1 (done) → Phase 2 (in progress) → Phase 3 (long-term) toward 100

---

**Related reports**:
- PHASE1-3-IMPROVEMENT-PROPOSAL.md
- PHASE2-3-IMPLEMENTATION-PLAN.md
