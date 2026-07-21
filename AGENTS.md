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
- 主要 command (install / sync / test / bench) は [`CLAUDE.repo.md`](CLAUDE.repo.md) の Quick Reference が canonical。ここでは重複させない (drift 防止)。
- Codex 側は `./codex/install.sh` で `~/.codex` に反映する。sanity check は `ls ~/.claude/hooks` / `ls ~/.codex/hooks`。

## Coding Style & Naming Conventions
- Shell scripts are Bash with `set -e`; keep changes minimal and readable.
- Templates use `.example` suffix (e.g., `codex/config.toml.example`); real files are ignored by git.
- Prefer ASCII, concise comments, and existing naming patterns (`pre-*.sh`, `session-*.sh`).

## Testing Guidelines
- Test runner (bats / jest) の 実行 command は [`CLAUDE.repo.md`](CLAUDE.repo.md) の Quick Reference を参照する。
- hook 変更後は `claude-code/tests/unit/hooks/` と `claude-code/tests/integration/` の該当 bats を回す。
- Installer 変更後は install script を実行して symlink が期待通りか確認する。

## Commit & Pull Request Guidelines
- Commit history follows Conventional Commits: `feat:`, `fix:`, `refactor:`, `docs:`.
- Keep commits focused and include a short, descriptive scope in the body if needed.
- PRs should explain the intent, list modified areas (paths), and note any manual verification steps.

## Security & Configuration Tips
- Do not commit secrets or local paths; use environment variables and templates.
- Keep `.mcp.json`, `.serena/`, and `codex/hooks/*.sh` (generated) untracked per `.gitignore`.
