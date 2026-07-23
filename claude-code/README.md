# Claude Code Config

Centralized management of commands, skills, agents, guidelines, and Hooks for Claude Code. Synced to `~/.claude/` using `install.sh`.

Changelog: git log (Conventional Commits、[CHANGELOG.md](CHANGELOG.md) は 2026-07-16 で凍結) / Global instructions: [CLAUDE.global.md](CLAUDE.global.md) / CLI tracking: [VERSION](VERSION)

## Quick Start

```bash
# First time (assumes ~/ai-tools is already cloned)
./claude-code/install.sh

# Sync
./claude-code/sync.sh from-local      # ~/.claude → repo (pull in)
./claude-code/sync.sh to-local --yes  # repo → ~/.claude (apply)
```

See [#setup-details](#setup-details) for full setup instructions.

## Core 3 Commands

When in doubt, use just these three.

| Command | Purpose | When to Use |
|---|---|---|
| `/flow` | All-purpose, auto-detection | 3+ files / unclear / multi-step |
| `/dev` | Straight to implementation | 1-2 files / clear |
| `/review` | Review (internally: `comprehensive-review` skill / `reviewer-agent` for team path) | After code changes |

### Tier 2 (frequently used)

| Command | Purpose |
|---|---|
| `/git-push` | commit → push → PR/MR in one step |
| `/plan` | Design/planning only (PO agent) |
| `/diagnose` | Error analysis and fix suggestions |
| `/review-fix-push` | Review → fix → push in one step |

### Tier 3 (specialized)

- **Development**: `/test` (`--tdd`) / `/refactor` / `/lint-test`
- **Design phase**: `/brainstorm`→`/fact-check`→`/prd`→`/design-doc`→`/plan` (order: `references/design-phase-flow.md`)
- **Documentation**: `/docs`
- **Investigation**: `/analytics` (`--ui`) / `/retrospective` / `/cursor-review`
- **Utilities**: `/reload` / `/memory-save` / `/memory-clean` / `/onboard` / `/protection-mode` / `/claude-update-fix` / `/serena-update-fix`

Full command list: `commands/` directory.

## Structure

Load 欄の意味と「新規 file をどこに置くか」の判断基準:

- **auto-load**: 毎 session 冒頭で必ず読まれる。ここに置く条件は「全 project / 全 turn で必要な短い規範」。原則 100 行以内。
- **on-demand**: 特定 trigger (slash command / 用語 / tech stack 検出 / 明示指定) 時のみ読まれる。domain 別の詳細規範 / 手順書 / trigger 付き rule はここ。
- **auto-invoke**: user 発話 / event を契機に harness 側から読み込まれる (skill / hook / command)。frontmatter の description が起動 trigger を決める。
- **manual**: user が `/reload` 等で明示的に呼ぶまで読まれない。
- **build-time**: sync.sh / install.sh 実行時にだけ参照される。session context には入らない。

| Directory / File | Content | Load | Details |
|---|---|---|---|
| `commands/` | Slash commands | auto-invoke (`/name` 発火) | `commands/*.md` |
| `skills/` | Skills | auto-invoke (description match) | `skills/<name>/SKILL.md` |
| `agents/` | Agents (po/manager/developer etc.) | auto-invoke (Task tool) | [agents/README.md](agents/README.md) |
| `guidelines/` | Guidelines (language/design/infra/ops/quality) | on-demand (tech stack / topic trigger) | By category |
| `hooks/` | Event hooks | auto-invoke (event 発火) | [hooks/README.md](hooks/README.md) |
| `templates/` | settings / MCP / workflow templates | build-time | [templates/README.md](templates/README.md) |
| `output-styles/` | Response format definitions | manual (`/output-style` 切替) | [output-styles/README.md](output-styles/README.md) |
| `references/` | 詳細層 (`references/*.md`) と on-demand rule (`references/on-demand-rules/*.md`) | on-demand (CLAUDE.md / trigger 経由) | `references/*.md` |
| `rules/` | 全 project 共通の短い規範 (文体 / 質問抑制 / 思考原則 等) | **auto-load** (毎 session 冒頭) | |
| `scripts/` | analytics / dashboard / cleanup helpers | manual (CLI 実行) | |
| `lib/` | Shell utilities | build-time (hook / script が source) | [lib/README.md](lib/README.md) |
| `tests/` | Hook / lib tests | manual (`npm run test:bats`) | [tests/README.md](tests/README.md) |
| `settings/` | MCP server settings | build-time | |
| `config/` | Shell utility settings | build-time | |
| `githooks/` | Repo git hooks | build-time (git 操作契機) | |
| `CLAUDE.md` | Global instructions specific to claude-code | auto-load | |
| `VERSION` | CLI tracking version (manual update: `/claude-update-fix`) | build-time | |

新規 file 配置の判断: 全 project 共通の短い規範 → `rules/`、domain 別の詳細 → `guidelines/`、特定 trigger でだけ読ませたい詳細 → `references/on-demand-rules/`、既存 rule / CLAUDE.md の補足詳細 → `references/`。

## Skills

Most skills are **auto-selected**. No explicit invocation needed. `UserPromptSubmit Hook` detects tech stack, `/review` selects skills by problem type, `requires-guidelines` auto-loads related guidelines.

### By Category

| Category | Skills |
|---|---|
| Review | comprehensive-review / uiux-review / ui-skills |
| Development | backend-dev / react-best-practices / api-design / clean-architecture-ddd / grpc-protobuf |
| Infrastructure | container-ops / terraform / microservices-monorepo |
| Utilities | load-guidelines / cleanup-enforcement / session-mode / context7 / data-analysis / techdebt / incident-response / root-cause / architecture-diagram |

### Recommended Combinations

| Scene | Skills |
|---|---|
| Full review | `comprehensive-review --focus=all` |
| Go backend | `backend-dev --lang=go` + `clean-architecture-ddd` + `api-design` |
| TypeScript backend | `backend-dev --lang=typescript` + `api-design` |
| React/Next.js | `react-best-practices` + `ui-skills` + `uiux-review` |
| Container investigation | `container-ops --mode=troubleshoot` |
| Incident | `incident-response` + `root-cause` |

### Quality Validation

- `scripts/skill-lint.sh` — frontmatter validation (`--strict` for pre-push hook)
- `scripts/skill-eval.sh` — measure activation rate, surface unused skills
- `/skill-add <name>` — skill-creator → lint → sync in one step

## Agents

| Agent | Role |
|---|---|
| `po-agent` | Strategy decision, Worktree management |
| `manager-agent` | Task breakdown and allocation planning |
| `developer-agent` | Implementation (dev1-4 parallel) |
| `explore-agent` | Exploration/analysis (explore1-4) |
| `reviewer-agent` | Review |
| `verify-app` | Build/test verification |
| `root-cause-analyzer` | Root cause analysis |
| `design-review-agent` | Live UI/UX review (Playwright MCP) |

Details, cost, command mapping: [agents/README.md](agents/README.md)

## Glossary

- **Agent**: Role executor launched by `Task` tool
- **MCP** (Model Context Protocol): External tool integration protocol (serena / context7 / codex etc.)
- **Hook**: Script auto-executed on specific events (details: [hooks/README.md](hooks/README.md))
- **Skill**: Specialized knowledge set for a specific technical domain, invoked with `/skill-name`
- **Command**: Shortcut in `/command` format
- **Guideline**: Language/framework-specific best practices (on-demand load)
- **Worktree**: Git feature, parallel development with multiple working directories
- **additionalContext**: JSON mechanism for hooks to provide additional info to the model (v2.1.9+)
- **protection-mode**: 3-layer classification of operation safety (safe/confirm/forbidden)

## Setup Details

### Prerequisites

Git / Node.js v20+ / Python 3.x / uv

### Initial Setup

```bash
cd ~
git clone https://github.com/DaichiHoshina/ai-tools.git
cd ai-tools && ./claude-code/install.sh
```

### New PC Setup (複数 PC 運用)

新しい PC では、ai-tools を ghq 配下に clone する。

```bash
mkdir -p ~/ghq/github.com/DaichiHoshina
cd ~/ghq/github.com/DaichiHoshina
git clone https://github.com/DaichiHoshina/ai-tools.git
cd ai-tools && ./claude-code/install.sh
```

`install.sh` を実行すると `~/.claude/references-private/private-name-list.txt` の placeholder が生成される。ただし、private-name block を正しく機能させるには、既存 PC の `~/.claude/references-private/private-name-list.txt` の中身を新 PC に手動で移植する必要がある。この file は git 管理外のため自動同期されない。

移植しない場合、個人名・会社名・project 固有名詞が public repo に書き込まれても block されない (silent pass)。

```bash
# 既存 PC から新 PC へ手動コピー (例: scp)
scp ~/.claude/references-private/private-name-list.txt new-pc:~/.claude/references-private/private-name-list.txt
```

MCP server (Serena 等) も PC ローカル登録のため新 PC で別途 setup する。次節「MCP Servers」参照。

### MCP Servers

**Serena (required)**

clone Serena 本体。

```bash
mkdir -p ~/ghq/github.com/oraios
cd ~/ghq/github.com/oraios
git clone https://github.com/oraios/serena.git
cd serena && uv sync
```

Claude Code に user-scope で MCP 登録 (1 PC 1 回、`~/.claude.json` に書き込まれる)。

```bash
claude mcp add serena -s user -- \
  uv run --project ~/ghq/github.com/oraios/serena \
  serena start-mcp-server --context claude-code --project-from-cwd
```

確認: `claude mcp list` で `serena` が出れば OK。`--project-from-cwd` で session 起動時の cwd を自動 activate するため、project ごとの `.mcp.json` 配置は不要。

> **注意**: `--directory` ではなく `--project` を使う。`--directory` は uv の cwd を変更する flag で、`--project-from-cwd` (serena 側) が拾う cwd が oraios/serena 固定になり、全 repo で誤った project を掴む不具合になる。`--project` は uv の workspace 指定だけで cwd を変えないため、session cwd が正しく serena に渡る。

**Codex (required)**

```bash
npm install -g @openai/codex
```

**CodeRabbit CLI (recommended, for `/review --multi` / `/git-push --auto-review`)**

```bash
brew install coderabbitai/tap/coderabbit
coderabbit auth login
```

Auto-review is skipped if not authenticated.

### Review Enhancement Plugins (recommended)

Used with `/review --multi` `/review --deep` `/git-push --pr --auto-review`.

| Plugin | Role | Required |
|---|---|---|
| `code-review` | 5-parallel Sonnet+Haiku with confidence-80 filter → auto-post PR comments | Required for `--multi`/`--auto-review` |
| `security-guidance` | Security warning hook for eval/exec patterns on Edit/Write | Recommended |
| `pr-review-toolkit` | 6 specialized agents (code-reviewer / silent-failure-hunter etc.) | Required for `--deep` |
| `coderabbit` | 40+ static analyses, auto-post PR comments | Used with `--multi`/`--auto-review` |

```bash
claude plugin install code-review@claude-plugins-official
claude plugin install security-guidance@claude-plugins-official
claude plugin install pr-review-toolkit@claude-plugins-official
claude plugin install coderabbit@claude-plugins-official
```

### Verification

```bash
ls ~/.claude/commands/ ~/.claude/skills/ ~/.claude/hooks/
jq '.hooks' ~/.claude/settings.json

# Hook test
echo '{"prompt": "Go APIのバグを修正してください"}' | ~/.claude/hooks/user-prompt-submit.sh
```

Expected output: `Tech stack detected: go | Skills: go-backend`

### Configuration Options

Extend Bash timeout (`~/.claude/settings.json`):

```json
{"env": {"BASH_DEFAULT_TIMEOUT_MS": "300000"}}
```

Default 2 min → 5 min (max 10 min: 600000)

UX environment variable: `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1` disables fullscreen renderer (CLI 2.1.132+, allows scrollback reference in long sessions).

### Serena Efficiency

Start with `get_symbols_overview()` / default to `include_body=false` / read partial ranges with line range specification.

### Troubleshooting

| Problem | Fix |
|---|---|
| Serena not working | `cd ~/serena && uv sync` |
| Codex not working | `npm install -g @openai/codex` |
| Hard link error | `./claude-code/sync.sh` |
| Project state corrupt / bloated | `claude project purge --dry-run` → `claude project purge -y` (CLI 2.1.126+) |

## Version Management

- `VERSION` is the **CLI tracking version**. Do not bump on every config change
- CLI release intake: [`/claude-update-fix`](commands/claude-update-fix.md)
- Track unadopted features: [references/CLAUDE-CODE-OPPORTUNITIES.md](references/CLAUDE-CODE-OPPORTUNITIES.md)

## Operations Documentation

| Topic | Reference |
|---|---|
| Model selection, effort levels | [references/model-selection.md](references/model-selection.md) |
| Full natural language trigger list | [references/natural-language-triggers.md](references/natural-language-triggers.md) |
| Review command usage guide | [references/review-commands.md](references/review-commands.md) |
| Memory usage (auto-memory / Serena) | [references/memory-usage.md](references/memory-usage.md) |
| Session management (rename / resume) | [references/session-management.md](references/session-management.md) |
| Agent cost measurements | [references/performance-insights.md](references/performance-insights.md) |
| Design phase transitions | [references/design-phase-flow.md](references/design-phase-flow.md) |
| Key command × resource mapping | [references/command-resource-map.md](references/command-resource-map.md) |

Top-level overview: [../README.md](../README.md)
