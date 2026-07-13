# ai-tools Repo Config (ai-tools 配下作業時のみ適用)

global 規範は `~/.claude/CLAUDE.md` を参照する。本 file は ai-tools repo 作業時に必要な repo 固有 rule のみを持つ。`claudeMdExcludes` が repo 直下 CLAUDE.md を除外するため、owner 階層 `~/ghq/github.com/DaichiHoshina/CLAUDE.md` からの import 経由で読み込まれる。ai-tools 配下以外の作業では本 file の rule を適用しない。

## Quick Reference

```bash
cd ~/ai-tools/claude-code
npm test                    # jest (statusline 等 JS test)
bats --jobs 8 --no-parallelize-within-files -r tests/  # bats 全実行 (file 単位並列。GNU parallel なしなら --jobs 系 flag を外す)
./sync.sh to-local --yes    # repo → ~/.claude 反映 (非対話。--dry-run 事前確認 / --only=hooks,commands 部分同期 / --no-backup)
./sync.sh status            # version / 最終 sync / backup 世代 / 差分の一覧
./sync.sh rollback --yes    # 誤 sync 復旧: 直近 backup (自動 3 世代保持) を ~/.claude に復元
./scripts/hook-bench.sh     # hook latency 計測 (--log 保存 / --diff 前回比較 / install-hook-bench-cron.sh で週次 cron)
```

## Repo layout

dir 構成 (commands / skills / agents / hooks / rules / guidelines / references / templates / scripts / lib / tests) の役割一覧は `README.md` を参照する。

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`**。`~/.claude/` 直接編集は `sync.sh to-local` で wipe される
- **root keys (env / model / statusLine / permissions / sandbox / worktree / enabledPlugins / extraKnownMarketplaces / autoUpdatesChannel ほか allowlist) は template canonical**。例外: `hooks` / `skillOverrides` は merge logic あり
- 🔒 PROTECTED SECTION / YAML frontmatter は改変禁止。詳細: `claude-code/references/editing-rule-detailed.md`

## Definition File Token Saving

commands/ skills/ agents/ の `.md` は毎 session token を消費する。Keep: decision table / workflow 定義 / guard / 禁止事項 / example 1 つ。Remove: sample impl / 重複説明 / 詳細 usage。Target: agent ≤300 / command ≤150 / skill 100-130 行。

**EN-conversion-protected files/sections**: `claude-code/references/on-demand-rules/en-conversion-protected.md` (誤訳が rule / bats / JP trigger を壊す)。

`skills/.system/` 配下は upstream vendored skill (license.txt 同梱) で行数目標の対象外。改変は upstream merge conflict 源になるため、行数超過を理由にした圧縮 / 分離 TODO を立てない。

## Hook 編集 baseline rule

`hooks/*.sh` の block / warn 系編集前に **`claude-code/references/on-demand-rules/measure-before-hook-change.md` を Read + `./scripts/hook-bench.sh --log` で baseline 計測**。skip すると latency regression が 24-48h 後に判明する (`[[2026-06-24 cd70e4e]]`)。

## Golden workflow (ai-tools 頻出)

- skill 追加 → `/skill-add` / guideline 更新 → `/update-guidelines`
- worktree 隔離 + commit + ff-merge + push (canonical: `claude-code/references/on-demand-rules/ai-tools-worktree-flow.md`、**dir 名 slug と branch 名は必ず一致**)。前提: 未編集状態で切る。main 編集済なら branch commit に切替。fallback 手順: `claude-code/references/on-demand-rules/worktree-branch-name-match.md`
- memory write は `~/ai-tools/memory/` 固定 (`.gitignore` 済)。`~/.claude/projects/.../memory/` と Serena `.serena/memories/` への write 禁止
