---
allowed-tools: Read, Bash, Glob, Write
description: Project onboarding - collect repo context and save as memory (Serena onboarding tool 相当、write は Write tool 経由)
argument-hint: "[topic]"
effort: low
---

# /onboard - Project onboarding memory

初回 / 久々の project で repo 理解を作り、非自明な知見だけを memory file として保存する。Serena の `onboarding` / `write_memory` / `edit_memory` は使わない (CLAUDE.md の全 project 禁止 rule に従い、保存は本 command の Write tool 実行で行う)。

## Save target dir

project 階層 CLAUDE.md が auto-memory dir を宣言していればそこを使う (例: `~/ghq/<org>/memory/<project>/`)。宣言がなければ `~/ai-tools/memory/` 固定 (Claude Code のみ write、Codex / Cursor は symlink read-only の共有 SoT)。

## 収集フェーズ

1. `README.md` (Glob で候補確認 → Read)
2. repo 配下 CLAUDE.md / CLAUDE.repo.md (project 固有 rule)
2b. git worktree で作業中なら `git rev-parse --git-common-dir` で親 repo を解決し、org 階層 CLAUDE.md (`<org dir>/CLAUDE.md`) も Read する。linked worktree は親 dir 外にあり auto-load されないため、内部 dir だけ見ると org 規範を取りこぼす
3. `git log --oneline -20` で直近の変更傾向を確認する
4. `git ls-files | head -50` 等で dir 構成の全体像をつかむ
5. build / test command (package.json scripts / Makefile / README 記載) を確認する
6. 主要 entry point (main / index / cli 相当) を Glob で特定する

## 保存フェーズ

> **Helper script 必須**: `MEMORY.md` の index 追記と file 名 collision 回避は `scripts/memory-save-helper.sh` 経由で行う (`/memory-save` が確立した既存 pattern に揃える)。本体 body の Write のみ AI 側担当。

1. 保存先 dir の `MEMORY.md` を Read し、既存の project memory を確認する
2. 同趣旨の既存 file があれば新規作成せず、その file を差分更新する
3. なければ `bash ~/.claude/scripts/memory-save-helper.sh resolve-name project-<slug>` で name collision を回避し (`-2/-3` suffix 自動)、解決した name で本文を Write する
4. `bash ~/.claude/scripts/memory-save-helper.sh update-index <name> <description> [<hook>]` で `MEMORY.md` に 1 行 index を追記する (helper が dedup + prepend)
5. 再実行しても内容が変わらなければ file を上書きしない (idempotent、既存と同一内容の重複追記をしない)

## File format

```yaml
---
name: project-<slug>
description: <one-line summary>
metadata:
  type: project
---

<非自明な知見の本文>

**Why:** <なぜこの知見が必要か>
**How to apply:** <次回作業でどう使うか>
```

## Guard

- repo から導出できる情報は保存しない。code 構造 / 過去 fix 内容 / git history / CLAUDE.md 記載事項が該当する
- 保存対象は非自明な知見のみとする。build 手順の罠 / 暗黙の規約 / SoT の所在 / 外部依存の癖が該当する
- Serena `write_memory` / `onboarding` / `edit_memory` での保存は禁止する (全 project 共通 rule)。`.serena/memories/` への write もしない

## Fallback

| Scenario | Action |
|----------|--------|
| 保存先 dir 不在 | `mkdir -p` してから Write する |
| Write 失敗 | 収集結果を chat に出力し、手動保存を案内する |
| MEMORY.md 不在 | 新規作成し、今回の 1 行 index だけを書く |
| 非自明な知見が 0 件 | file 作成をせず「保存対象なし」を報告する |

ARGUMENTS: $ARGUMENTS
