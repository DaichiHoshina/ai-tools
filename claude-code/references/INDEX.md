# References Index

On-demand index from CLAUDE.md.

**Not listed** (`ls references/` to find):
- `*-template.md` (exception: `performance-issue-template.md` included as operational procedure)
- `*-OPPORTUNITIES.md` (feature backlog tracker, unsuitable for index)
- `*-detailed.md` (CLAUDE.md から直接参照される detail 系: `auto-delegation-detailed.md` / `editing-rule-detailed.md` / `session-efficiency-detailed.md` / `memory-clean-detail.md`)
- `health-snapshots/` (monthly snapshots, reference dir directly)
- `retrospectives/` / `on-demand-rules/` / `_archive/` (reference dir directly)
- `INDEX.md` (this file)

## Model Selection / Session Management

| Topic | File |
|-------|------|
| Model selection / effort | `model-selection.md` |
| Session management | `session-management.md` |
| Checkpoint / Rewind | `checkpoint-rewind.md` |
| `claude -p` fan-out | `fanout-recipes.md` |
| Agent cost measurements | `performance-insights.md` |

## Triggers / Commands

| Topic | File |
|-------|------|
| Full natural language trigger list | `natural-language-triggers.md` |
| Review command usage guide | `review-commands.md` |
| Review mode details (deep / multi aggregation) | `review-modes-advanced.md` |
| Command × resource map | `command-resource-map.md` |
| Guideline auto-trigger list | `guideline-triggers.md` |
| Skill tool invocation patterns (forked exec) | `skill-tool-invocation.md` |
| Loop engineering (14-step roadmap, 4-condition test, Ralph Wiggum guard) | `loop-engineering.md` |

## Workflows

| Topic | File |
|-------|------|
| Multi-repo side-by-side | `multi-repo-workflow.md` |
| Design phase transitions | `design-phase-flow.md` |
| Ticket → PR completion stages | `ticket-to-pr-workflow.md` |
| Compounding Engineering | `compounding-engineering-cycle.md` |
| Parallel execution patterns (worktree decisions) | `PARALLEL-PATTERNS.md` |
| /flow 詳細 orchestration 仕様 (pre-delegation / 3 Gate 詳細) | `flow-orchestration.md` |
| Orchestrate mode (parent-led delegation supplement) | `orchestrate-mode.md` |
| Parallel self-review (Gate C 12-lens) | `parallel-self-review.md` |
| Workflow tool templates (fan-out / pipeline / 多数決) | `workflow-templates.md` |
| Agent Team interface schema (canonical) | `agent-team-contract.md` |
| Agent output schema (status / confidence trailer) | `agent-output-schema.md` |
| Developer agent delegation prompt (canonical) | `developer-agent-delegation-prompt.md` |
| bats editing canonical rules (for Developer agents) | `bats-test-writing.md` |
| Hook event payload map | `hook-payload-map.md` |
| Work output routing (報告先の振り分け) | `work-output-routing.md` |

## Thinking Frameworks

| Topic | File |
|-------|------|
| AI thinking essentials | `AI-THINKING-ESSENTIALS.md` |
| Design decision quality checklist | `decision-quality-checklist.md` |

## Architecture & Design Patterns

| Topic | File |
|-------|------|
| Clean Architecture (layer / dependency direction) | `../guidelines/design/clean-architecture.md` |
| Domain-Driven Design (aggregate / bounded context) | `../guidelines/design/domain-driven-design.md` |
| CQRS (read/write split / sync strategies / maturity levels) | `../guidelines/design/cqrs.md` |
| Async job patterns (queue selection / fan-out) | `../guidelines/design/async-job-patterns.md` |

## Documentation Writing

| Topic | File |
|-------|------|
| DesignDoc writing and granularity | `../guidelines/writing/design-doc-protocol.md` |
| PRD review checkpoints | `prd-review-checkpoints.md` |
| Performance improvement issues | `performance-issue-template.md` |
| Universal review patterns | `review-patterns-universal.md` |
| Document rewrite phases | `document-iteration-patterns.md` |
| Writing common principles | `../guidelines/writing/PRINCIPLES.md` |
| Writing supplement patterns (rewrite phases / textlint) | `writing-patterns.md` |
| Writing sentence-level rules (文長 / ひらく漢字 / 漢数字 等 detail) | `writing-sentence-rules.md` |

## Serena / MCP

| Topic | File |
|-------|------|
| Serena cc-system-prompt-override setup | `serena-cc-prompt-setup.md` |
| Serena tool 用途マップ (per-agent canonical) + 事故防止ルール | `serena-tool-map.md` |

## Other

| Topic | File |
|-------|------|
| Memory usage guide | `memory-usage.md` |
| Memory relocation pattern (auto-memory → project-scoped path) | `memory-relocation-pattern.md` |
| Memory → CLAUDE.md / ai-tools promotion flow | `~/.claude/references-private/memory-promotion-flow.md` |
| Plugin marketplace caveats (cascade uninstall) | `plugin-marketplace-caveats.md` |
| CodeRabbit plugin cheat sheet | `coderabbit-plugin.md` |
| Boris 流開発スタイル対応表 | `boris-style-mapping.md` |
| Claude Code official best practices (JA) | https://code.claude.com/docs/ja/best-practices |
