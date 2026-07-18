# References Index

On-demand index from CLAUDE.md.

**Not listed** (`ls references/` to find):
- `*-template.md` (exception: `performance-issue-template.md` included as operational procedure)
- `*-OPPORTUNITIES.md` (feature backlog tracker, unsuitable for index)
- `*-detailed.md` (CLAUDE.md から直接参照される detail 系: `auto-delegation-detailed.md` / `editing-rule-detailed.md` / `session-efficiency-detailed.md` / `memory-clean-detail.md`)
- `health-snapshots/` (不定期 snapshot、最終 2026-05-17。reference dir directly)
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
| WCAG a11y checklist (canonical, 2.2 AA) | `wcag-a11y-checklist.md` |
| Loop engineering (14-step roadmap, 4-condition test, Ralph Wiggum guard) | `loop-engineering.md` |

## Workflows

| Topic | File |
|-------|------|
| Design phase transitions | `design-phase-flow.md` |
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
| Writing self-check protocol (閾値 / loop 上限 canonical) | `writing-check-protocol.md` |
| Performance improvement issues | `performance-issue-template.md` |
| Universal review patterns | `review-patterns-universal.md` |
| Document rewrite phases | `document-iteration-patterns.md` |
| Writing common principles | `../guidelines/writing/PRINCIPLES.md` |
| Writing supplement patterns (rewrite phases / textlint) | `writing-patterns.md` |
| Writing sentence-level rules (文長 / ひらく漢字 / 漢数字 等 detail) | `writing-sentence-rules.md` |

## Serena / MCP

| Topic | File |
|-------|------|
| Serena tool 用途マップ (per-agent canonical) + 事故防止ルール | `serena-tool-map.md` |

## Other

| Topic | File |
|-------|------|
| Memory usage guide | `memory-usage.md` |
| Memory relocation pattern (auto-memory → project-scoped path) | `memory-relocation-pattern.md` |
| Boris 流開発スタイル対応表 | `boris-style-mapping.md` |
| Claude Code official best practices (JA) | https://code.claude.com/docs/ja/best-practices |
