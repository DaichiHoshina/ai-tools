# ai-tools Repo Config (repo 内作業時のみ load)

global 規範は `~/.claude/CLAUDE.md` を参照する。本 file は ai-tools repo 作業時に必要な repo 固有 rule のみを持つ。

## Quick Reference

```bash
cd ~/ai-tools/claude-code
npm test                    # jest (statusline 等 JS test)
bats -r tests/              # bash hook / lib / scripts の bats 全実行
./sync.sh to-local --yes    # repo → ~/.claude 反映 (非対話)
./scripts/hook-bench.sh     # hook latency 計測 (--log 保存 / --diff 前回比較 / install-hook-bench-cron.sh で週次 cron)
```

## Repo layout

| dir | 役割 |
|---|---|
| `commands/` | slash command (`/plan` `/flow` `/review` `/workflow` 等) |
| `skills/` | Skill (`comprehensive-review` `jp-writing` `local-docs` 等) |
| `agents/` | subagent 定義 (`developer-agent` `po-agent` `manager-agent` 等) |
| `hooks/` | Claude Code hooks (`pre-tool-use.sh` `session-start.sh` 等) |
| `rules/` | 規約 (`genshijin.md` `public-repo-private-data-block.md` 等) |
| `guidelines/` | 執筆 / language / design 規範 (`writing/` `design/` 等) |
| `references/` | 詳細仕様 / 履歴 / cross-ref 集 (`INDEX.md` 等) |
| `templates/` | `settings.json.template` ほか canonical config |
| `scripts/` | sync 補助 / hook-bench / git-hooks |
| `lib/` | bash 共通 lib / `tests/` | bats + jest |

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`**。`~/.claude/` 直接編集は `sync.sh to-local` で wipe される
- **root keys (env / model / statusLine / permissions / sandbox / worktree / enabledPlugins / extraKnownMarketplaces / autoUpdatesChannel ほか allowlist) は template canonical**。例外: `hooks` / `skillOverrides` は merge logic あり
- 🔒 PROTECTED SECTION / YAML frontmatter は改変禁止。詳細: `claude-code/references/editing-rule-detailed.md`

## Definition File Token Saving

commands/ skills/ agents/ の `.md` は毎 session token を消費する。Keep: decision table / workflow 定義 / guard / 禁止事項 / example 1 つ。Remove: sample impl / 重複説明 / 詳細 usage。Target: agent ≤300 / command ≤150 / skill 100-130 行。

**EN-conversion-protected files/sections**: `claude-code/references/on-demand-rules/en-conversion-protected.md` (誤訳が rule / bats / JP trigger を壊す)。

## Hook 編集 baseline rule

`hooks/*.sh` の block / warn 系編集前に **`claude-code/references/on-demand-rules/measure-before-hook-change.md` を Read + `./scripts/hook-bench.sh --log` で baseline 計測**。skip すると latency regression が 24-48h 後に判明する (`[[2026-06-24 cd70e4e]]`)。

## Golden workflow (ai-tools 頻出)

- skill 追加 → `/skill-add` / guideline 更新 → `/update-guidelines`
- worktree 隔離 + commit + ff-merge + push (`[[ai-tools-worktree-workflow]]` canonical、**dir 名 slug と branch 名は必ず一致**)。前提: 未編集状態で切る。main 編集済なら branch commit に切替 (`[[project_worktree_fresh_baseref_uncommitted_trap]]`)。fallback 手順: `claude-code/references/on-demand-rules/worktree-branch-name-match.md`
- memory write は `~/ai-tools/memory/` 固定 (`.gitignore` 済)。`~/.claude/projects/.../memory/` と Serena `.serena/memories/` への write 禁止
