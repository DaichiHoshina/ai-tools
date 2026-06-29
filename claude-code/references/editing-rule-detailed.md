# Editing Rule 詳細 (data-loss guard)

CLAUDE.md `## Editing Rule (data-loss guard)` の詳細委譲先。

## sync.sh to-local の wipe 対象

`~/.claude/` 配下の以下 dir / file は `sync.sh to-local` 実行時に `~/ai-tools/claude-code/` から上書きされる。直接編集は wipe される。

- CLAUDE.md / commands / skills / hooks / agents / rules / guidelines / references / config

## root keys (template canonical)

`templates/settings.json.template` で canonical 管理する root keys:

- `env` / `model` / `statusLine` / `permissions` / `sandbox` / `worktree` / `enabledPlugins` / `extraKnownMarketplaces` / `autoUpdatesChannel`
- ほか allowlist 済 root keys

`to-local` 時に entirely 上書き。live 追加は wipe される。設定追加は **template edit → `to-local`** の順で行う。

### 例外 (dedicated merge logic)

- `hooks`: 既存 live hook と template を merge
- `skillOverrides`: 既存 override を保持して template と merge

## VERSION / SERENA_VERSION

`VERSION` / `SERENA_VERSION` の bump 条件:

- `VERSION`: Claude Code CLI release intake 時 (`/claude-update-fix` 実行時のみ)
- `SERENA_VERSION`: Serena MCP release intake 時 (`/serena-update-fix` 実行時のみ)

手動 bump 禁止。

## Claude Code channel

- **現在**: stable channel (2026-06-23 切替、latest からの戻し)
- `/claude-update-fix` TARGET: `dist-tags.stable`
- 詳細: `commands/claude-update-fix.md`
