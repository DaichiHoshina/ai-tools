# Repository Guidelines

> **Note**: このファイルはリポジトリのビルド・テスト・開発ガイドラインです。
> Claude Codeエージェントの定義については [`claude-code/agents/README.md`](claude-code/agents/README.md) を参照してください。

## Project Structure & Module Organization
- `claude-code/`: Main Claude Code assets (hooks, commands, skills, guidelines, lib).
- `claude-code/hooks/`: Shell hooks that run on session/tool events (tests live in `claude-code/tests/`).
- `codex/`: Codex templates and installer (`config.toml.example`, `AGENTS.md.example`, `hooks/*.example`).
- `docs/`: Documentation hub. Notable subdirs: `docs/reports/` (historical reports), `docs/adr/` (ADRs); plus quickref/setup guides at the top level.
- Root docs: `README.md`, `AGENTS.md`, `LICENSE`, `CODEX-SETUP.md`.
- Config templates: `.mcp.json.example`; local-only files live in `.mcp.json` and `.serena/` (gitignored).

## Build, Test, and Development Commands
- `./claude-code/install.sh`: Install Claude Code config into `~/.claude` (creates symlinks, copies templates).
- `./codex/install.sh`: Install Codex config into `~/.codex` (Level 4 full sync).
- `./claude-code/sync.sh`: Sync shared resources when updating Claude Code assets.
- `ls ~/.claude/hooks` or `ls ~/.codex/hooks`: Quick sanity check that hooks were installed.

## Coding Style & Naming Conventions
- Shell scripts are Bash with `set -e`; keep changes minimal and readable.
- Templates use `.example` suffix (e.g., `codex/config.toml.example`); real files are ignored by git.
- Prefer ASCII, concise comments, and existing naming patterns (`pre-*.sh`, `session-*.sh`).

## Testing Guidelines
- Bats suite: `cd claude-code && npm run test:bats` (unit + integration; requires `bats`).
- Jest: `cd claude-code && npm test` (statusline etc. JS tests).
- After hook changes, run the relevant bats files under `claude-code/tests/unit/hooks/` and `claude-code/tests/integration/`.
- Validate installs by running the installer scripts and confirming expected symlinks.

## Commit & Pull Request Guidelines
- Commit history follows Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`.
- Keep commits focused and include a short, descriptive scope in the body if needed.
- PRs should explain the intent, list modified areas (paths), and note any manual verification steps.

## Security & Configuration Tips
- Do not commit secrets or local paths; use environment variables and templates.
- Keep `.mcp.json`, `.serena/`, and `codex/hooks/*.sh` (generated) untracked per `.gitignore`.
