# Model Selection Guide

Default: **Sonnet 4.6** (`claude-sonnet-4-6`)

## Manual switching

| Task | Recommended | Model ID | Switch |
|--------|-----------|---------|------|
| Batch processing, type conversion, formatting, bulk file processing | Haiku 4.5 | `claude-haiku-4-5-20251001` | `/model` → haiku |
| Simple fixes, investigation, code reading, normal development | **Sonnet 4.6** (default) | `claude-sonnet-4-6` | keep |
| Root cause analysis, design decisions, complex bug analysis, security audit | Opus 4.7 | `claude-opus-4-7` | `/model` → opus |
| Task difficulty unknown, dynamic switching | Auto (Max subscribers only) | — | `/model` → auto |

**Use explicit `/model` for switching** (natural language triggers risk misfire).

**Auto Mode** (v2.1.111+): Available to Max subscribers with Opus base. `--enable-auto-mode` flag no longer needed. Claude auto-switches model by task difficulty.

## Per-agent auto-assignment

Specified in each agent's frontmatter.

**Policy**: parent (chat) orchestrates with Opus 4.7; subagents split into judgment=Opus 4.7 / execution=Sonnet 4.6 (judgment-Opus is forced to 4.7 since 2026-06-16 due to Opus 4.8 regression — see [[opus-4-8-regression-2026-06]]).

- **Opus 4.7 (judgment subagents)**: po-agent (strategy / design decisions), manager-agent (task decomp / parallelism calculation), root-cause-analyzer (complex bug analysis / 5 Why)
- **Sonnet 4.6 (execution subagents)**: developer-agent (impl / refactor), explore-agent (read-only exploration), verify-app (build / test execution), reviewer-agent (12-perspective review)

## Effort levels

Control thinking depth per session via `--effort` flag or `/effort`.

| Level | Use | Example |
|--------|------|-----|
| `low` | Simple questions, formatting fixes | `claude --effort low -p "fix typo"` |
| `medium` | Light development / investigation (cost-conscious) | `claude --effort medium` |
| `high` | Normal development | `claude --effort high` |
| `xhigh` | High-difficulty tasks / design decisions / deep analysis (Opus only) | `claude --effort xhigh` |
| `max` | Hardest debugging / large-scale RCA. Not for daily use (reports of overthinking backfire) | `claude --effort max` |

> `xhigh` is Opus-only (v2.1.111+; check `claude --help` `--effort` choices). Opus 4.7 default effort is `high`. Other models fall back to `high`.

For scripts with `--print`, also specify `--fallback-model sonnet` for auto-fallback on overload.
