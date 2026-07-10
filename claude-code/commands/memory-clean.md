---
allowed-tools: Bash, Read, Write, Edit, Agent, AskUserQuestion, TaskCreate, TaskUpdate
description: Auto-memory housekeeping (trash / prune / audit)。`--import=<src>` で他 repo 取込、`--apply` で実行。
argument-hint: "[--apply] [--import=<src-dir>]"
effort: low
---

# /memory-clean - Memory housekeeping (auto-memory)

自 memory の housekeeping と、他 repo memory からの汎用 knowledge 取込を **1 command で完結**させる。**Memory dir auto-detect**: `~/ai-tools/memory/` を優先、無ければ project の projects-memory dir (動的解決、`scripts/memory-save-helper.sh:_resolve_memory_dir` と同方式) を fallback。

> **Housekeeping guard**: mv (trash) / prune / 自動修正の対象は `~/ai-tools/memory/` 配下のみ。projects/memory dir は fallback 検出時も scan (read) のみで、mv / rm / write はしない。

> **Policy**: `mtime` を value proxy にしない。auto delete は work-context (date prefix で短命明示) と name/description exact dup のみ。
>
> **No rm**: `.trash-YYYYMMDD-HHMM/` に `mv` (3 世代 retain) で rollback path 確保。
>
> **Out of scope**: Serena symbol DB → `/serena-update-fix`。Serena `.serena/memories/` 触禁止。

## Arguments (2 種のみ)

| arg | 動作 |
|---|---|
| (none) / `--dry-run` | 候補表示のみ、変更なし (default) |
| `--apply` | dry-run 結果を実行 (trash + MEMORY.md prune + 表記揺れ自動修正) |
| `--import=<src-dir>` | 他 repo memory (例: `~/ghq/github.com/<org>/memory/`) から汎用 knowledge を抽出して ai-tools に反映。`--apply` 併用で元 file 削除 + cross-ref 差替も実行 |

**他の細かい挙動は全て default 有効化** — flag で覚えなくて良い。

- `work-context` 14 日超 → trash 候補 (自動)
- MEMORY.md orphan / dead-link → 検出 (自動)
- feedback 間 cross-ref の kebab ↔ snake 表記揺れ → 検出 + `--apply` で自動修正
- 削除済 memory への `[[..]]` 参照 → canonical 差替候補 / `{{deleted:}}` 記号化候補として提示
- topic cluster / small file (<20 行) / graduate 候補 → 提案表示 (auto merge しない)

## Flow

### Stage 1: dry-run (default、常に実行)

1. Memory dir 検出 (auto-detect)
2. **Auto-delete 候補列挙**:
   - `work-context-YYYYMMDD-*.md` で 14 日超 → trash candidate
   - `description` exact match / name prefix 3 tokens 一致 → duplicate candidate (新 mtime keep)
   - frontmatter `description` 欠落 → rescue candidate
3. **整合 audit**:
   - orphan (MEMORY.md にも他 file にも参照されない孤立 file) / dead-link (MEMORY.md link 先 file 不在) を検出
   - feedback 間 `[[name]]` cross-ref を検査: 表記揺れ (fixable) / canonical 差替候補 / `{{deleted:}}` 記号化候補
4. **提案候補**:
   - topic cluster (`feedback_<topic>_*` が 3 file 以上)
   - small file (<20 行)
   - graduate 候補 (ai-tools 配下 `rules/` `guidelines/` `references/` へ切り出しやすい heuristic)
5. chat 出力 → exit、変更なし

### Stage 2: `--apply` (自 memory 反映)

dry-run 列挙再実行 → 表示 → 実行。

1. trash dir `mkdir memory/.trash-YYYYMMDD-HHMM/`
2. expired work-context / duplicate older → `mv`
3. description rescue: body line 1 先頭 80 字 → frontmatter 書込 (body 不変)
4. MEMORY.md prune: trashed file link 行削除 / dead-link 行削除 / rescue 済 file 無 link なら 1 行 append
5. cross-ref: kebab ↔ snake 表記揺れは `sed` で自動修正、canonical 差替 / `{{deleted:}}` 記号化は候補提示のみ (`--apply` でも auto 適用しない、user 判断)
6. trash rotation: `.trash-*` 3 超なら最古削除

> **cluster / small / graduate は --apply 対象外**、提案表示のみ。

### Stage 3: `--import=<src-dir>` (他 repo memory 取込)

`--import` 指定時のみ実行。

1. `<src-dir>` 配下 subdir を列挙 (`_org` / project 別 dir 等)
2. subdir ごとに `explore-agent` を並列 fan-out (parallelism = subdir 数、max 8)。各 agent への prompt:
   - 全 file を read、**汎用性 high の候補**を抽出
   - **除外基準**: 社内 product 名 / 個人名 / 会社名 / 固有 path を含む / 既存 ai-tools rule と重複 / 単発 incident log
   - 既知知識として `~/ai-tools/claude-code/CLAUDE.md` / `rules/*.md` / `guidelines/writing/*.md` / `~/ai-tools/memory/feedback_*.md` を渡す
   - 出力: 候補 file / 提案先 / 汎用化後の要旨 (常体 plain JP) / 汎用性 confidence / 伏字化対象
3. Tier 分類して chat に一覧表示:
   - **Tier A**: `rules/` `guidelines/` に独立 file / 独立追記
   - **Tier B**: 既存 file への追記型 (差分小)
   - **Tier C**: `memory/` の feedback として保存
4. `AskUserQuestion` で採用 tier 選択 (1 括採用 / 段階採用 / 個別選抜)
5. `--apply` 併用時:
   - 対象 tier の各 file を canonical 反映 (`Write` 新規 or `Edit` 追記)、伏字化を適用
   - 元 file 削除: `rm <src-dir>/<subdir>/<file>` (**注**: `<src-dir>` は別 repo 領域のため ai-tools の `.trash-*/` mv 対象外、`rm` を意図的に使う。削除前に Step 4 の `AskUserQuestion` 承認で必ず user 確認を経ている、承認済 file のみ削除する)
   - 元 repo の MEMORY.md index prune: 削除 file の行を `sed` で除去
   - 生きた feedback からの dead cross-ref 修正: 削除 file への `[[name]]` 参照を ai-tools canonical 参照に差替
   - work-context / .trash 系 log 内の dead ref は履歴保持のため触らない
6. 完了後、反映 file 数 / 削除 file 数 / cross-ref 差替数を chat に出力

## Out of scope (auto-delete しない)

- `MEMORY.md` 本体 (prune edit のみ)
- `compact-restore-*.md` / `.trash-*/` 中身
- `metadata.protect: true` の memory
- **mtime 30 日 stale auto-delete 禁止** (`untouched ≠ valueless`)
- cluster / small file / graduate 候補 (提案のみ)
- `--import` の canonical 差替 / `{{deleted:}}` 記号化 (提案のみ)

## Example

```text
$ /memory-clean
[memory-dir] ~/ai-tools/memory/
[dry-run] enumerate only, no file changes
[work-context-expired] 10 files (>14d)
[duplicate] 0 / [description-missing] 0
[orphan] 3 files (index 未登録) / [dead-link] 2 (link 先 file 不在)
[xref-audit] fixable(表記揺れ) 5 / canonical 差替候補 3 / {{deleted:}} 記号化候補 11
[cluster] feedback_no_* (6) / feedback_hook_* (3)
[small <20] 18 files / [graduate] 2 candidates
Run: /memory-clean --apply で trash + MEMORY.md prune + 表記揺れ自動修正を実行
```

```text
$ /memory-clean --import=~/ghq/github.com/<org>/memory/
[import-scan] fan-out 7 explore-agent (subdir 数)
[import-candidates] Tier A: 8 / Tier B: 10 / Tier C: 7
(自 memory audit の結果もあわせて表示)
Run: /memory-clean --import=<src-dir> --apply で採用 tier 反映 + 元 file 削除 + cross-ref 差替 + 自 memory 反映を実行
```

## Fallback

| Scenario | Action |
|---|---|
| memory dir 両方 missing | "memory dir not found" 報告して exit |
| trash dir 作成失敗 | abort + chat 報告 |
| frontmatter parse 失敗 | file skip、warnings 追加 |
| mv permission denied | file skip、warnings 追加 |
| 全候補 0 | "nothing to clean" exit |
| `--import=<src-dir>` の dir 不在 | "import src not found" 報告して exit (自 memory 側の他処理は継続) |

## When to use

- 月次 cleanup / MEMORY.md 100 行超 + session start 重い時
- `/retrospective` 後
- 他 repo memory から汎用 knowledge を切り出したい時 (`--import=<src-dir>`)

## Related

- `/memory-save` — memory 追加
- `/reload` — memory reload
- `/retrospective` — retrospective
- `/cursor-review` — Cursor config audit (see `cursor/MAINTENANCE.md`)
- `/serena-update-fix` — Serena MCP update (memory 独立)
- `rules/public-repo-private-data-block.md` — `--import` 時の伏字化 canonical

詳細仕様 (Detection logic / Graduate heuristic / Rollback) → `references/memory-clean-detail.md`

ARGUMENTS: $ARGUMENTS
