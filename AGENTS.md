# Repository Guidelines

## Project Structure & Module Organization
- `claude-code/`: Main Claude Code assets (hooks, commands, skills, guidelines, lib).
- `claude-code/hooks/`: Shell hooks that run on session/tool events (plus `test-*.sh` for hook checks).
- `codex/`: Codex templates and installer (`config.toml.example`, `AGENTS.md.example`, `hooks/*.example`).
- Root docs: `README.md`, `IMPROVEMENT-SUMMARY.md`, `integration-plan.md`, `TEST-RESULTS-P1.md`.
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
- There is no formal test runner; use hook checks and smoke tests instead.
- Run `claude-code/hooks/test-pre-skill-use.sh` and `claude-code/hooks/test-user-prompt-submit.sh` after hook changes.
- Validate installs by running the installer scripts and confirming expected symlinks.

## Commit & Pull Request Guidelines
- Commit history follows Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`.
- Keep commits focused and include a short, descriptive scope in the body if needed.
- PRs should explain the intent, list modified areas (paths), and note any manual verification steps.

## Security & Configuration Tips
- Do not commit secrets or local paths; use environment variables and templates.
- Keep `.mcp.json`, `.serena/`, and `codex/*.sh` (generated) untracked per `.gitignore`.
