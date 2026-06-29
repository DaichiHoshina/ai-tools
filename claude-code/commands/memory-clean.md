---
allowed-tools: Bash, Read, Write, Edit
description: Auto-memory housekeeping — move stale work-context to trash, prune MEMORY.md, suggest topic clusters / small-file merge / orphan / graduate (ai-tools 切り出し). Default dry-run; --apply to execute.
argument-hint: "[--apply] [--days=N] [--cluster] [--small=N] [--orphan] [--graduate]"
effort: low
---

# /memory-clean - Memory housekeeping (auto-memory)

Cleans up auto-memory. **Memory dir auto-detect**: `~/ai-tools/memory/` (CLAUDE.md canonical) を優先、無ければ `~/.claude/projects/-Users-daichi-hoshina-ghq-github-com-DaichiHoshina-ai-tools/memory/` を fallback。

> **Policy**: `mtime` を value proxy にしない。auto delete は work-context (date prefix で短命明示) と name/description exact dup のみ。topic cluster / small file は**提案のみ** (user 判断)。
>
> **No rm**: `.trash-YYYYMMDD-HHMM/` に `mv` (3 世代 retain) で rollback path 確保。
>
> **Out of scope**: Serena symbol DB → `/serena-update-fix`。Serena `.serena/memories/` 触禁止。

## Arguments

- `(none)` / `--dry-run`: 候補表示のみ、変更なし (default)
- `--apply`: dry-run 結果実行 (work-context trash + duplicate trash + MEMORY.md prune)
- `--days=N`: work-context expiry 閾値 (default 14)。`--days=7` で aggressive、`--days=30` で conservative
- `--cluster`: `feedback_<topic>_*` / `knowledge_<topic>_*` 等の topic group 表示 (3 個以上集まった cluster のみ、merge は user 判断)
- `--small=N`: N 行未満の file を merge 候補として list 表示 (default off、`--small=20` 推奨)
- `--orphan`: MEMORY.md にも他 memory file にも参照 (`[[name]]`) されない孤立 file 検出。orphan は **trash 候補ではなく、index 追加 or 削除判断の対象**
- `--graduate`: memory 内容を ai-tools 配下 (`rules/` `guidelines/` `references/`) に切り出すべき候補を heuristic で提案。memory は短期 / project / feedback、ai-tools は恒久 rule / guideline / reference という分離原則 (詳細は Graduate heuristic section)

> Default は dry-run (destructive のため)。`--apply` は `mv` で rollback 可。

## Flow

### Stage 1: dry-run (default)

1. **Memory dir 検出** (前述 auto-detect)
2. **Auto-delete 候補列挙**
   - `work-context-YYYYMMDD-*.md` で `YYYYMMDD` が **N+ 日経過** (`--days=N`、default 14) → trash candidate
   - `description` exact match / name prefix 3 tokens 一致 (work-context 除く) → duplicate candidate (新 mtime keep)
   - frontmatter `description` 欠落 → rescue candidate
3. **提案候補列挙** (`--cluster` / `--small=N` 指定時のみ)
   - `--cluster`: `feedback_<topic>_*` `knowledge_<topic>_*` `writing_failure_*` の topic prefix で group、**3 file 以上** の cluster を merge 候補として表示 (auto merge しない、ファイル名のみ列挙)
   - `--small=N`: N 行未満の `*.md` を list 表示 (MEMORY.md / pending-improvements 系除外、merge は user 判断)
4. **chat 出力**
   - auto-delete 候補数 + 抜粋
   - cluster 候補 (指定時)
   - small file 候補 (指定時)
   - prompt: "`--apply` で実行 / `--cluster` `--small=20` で提案追加"
5. exit、変更なし。

### Stage 2: --apply

dry-run 列挙再実行 → 表示 → 実行 (mis-move trace 用)。

1. trash dir `mkdir memory/.trash-YYYYMMDD-HHMM/`
2. expired work-context → `mv`
3. duplicate older → `mv`
4. description rescue: 本体 line 1 から 80 字 → frontmatter 書込 (body 不変)
5. MEMORY.md prune (既存 entry のみ、free format 尊重):
   - trashed file への link 行削除
   - rescue 済 file が無 link なら `- [<name>](<file>.md) — <description>` 末尾追加
   - index-only entry は manual 保持
6. trash rotation: `.trash-*` 3 超なら最古削除

> **cluster / small は --apply 対象外**。提案表示のみで、merge は user が手動 (skill 安全性のため auto merge 禁止)。

## Out of scope (auto-delete しない)

- `MEMORY.md` 本体 (prune-type edit のみ)
- `compact-restore-*.md` (PostCompact hook 生成)
- `.trash-*/` 中身
- `metadata.protect: true` の memory
- **mtime 30 日 stale auto-delete 禁止** (`untouched ≠ valueless`)
- cluster / small file (提案のみ)

## Detection details

### work-context expiry

- regex: `^work-context-(\d{8})-.*\.md$`
- `date -j -f %Y%m%d` で Unix time 化
- `today - N*86400` より古ければ trash 行き (N は `--days=N` arg、default 14)

### Duplicate detection

1. **Name prefix match**: name slug `-` split の最初 3 tokens 一致
   - 例外: `work-context-YYYYMMDD-*` は prefix match 除外 (同日複数で false positive、`[[memory-clean-design-gaps]]`)。description exact match のみ適用
2. **Description exact match**: punctuation/whitespace strip 後の同一 string
3. pair の mtime 比較、古い方を trash

> Fuzzy match (Jaccard 0.6 等) 禁止 (false positive 過多)。exact / explicit prefix のみ。

### Topic cluster (--cluster)

`feedback_<topic>_*` / `knowledge_<topic>_*` / `writing_failure_*` の **topic part (1st underscore-separated token)** で group。3 file 以上を merge 候補として列挙。例:

```
[cluster] feedback_no_* (6): feedback_no_derived_literals.md, feedback_no_env_output.md, ...
[cluster] feedback_hook_* (3): feedback_hook_ng_list_pitfalls.md, ...
```

merge は user 手動 (例: `feedback_no_*.md` を 1 file に統合 → 旧 file `mv` で trash)。skill は実行しない。

### Small file (--small=N)

`wc -l < <file>` が N 未満の `*.md` を list 表示 (MEMORY.md / `pending-improvements*` / `compact-restore-*` 除外)。merge は user 判断。

### Orphan (--orphan)

MEMORY.md 内の link にも他 memory file の `[[name]]` 参照にも現れない file を list。**判断軸**:

- 参照 0 + 内容 active rule → MEMORY.md に index 追加すべき
- 参照 0 + 内容 obsolete → 手動 trash
- 単発 reference 系 (user_*) で MEMORY.md 構造上意図的に未 link → keep (false positive)

### Graduate (--graduate) — memory → ai-tools 切り出し

memory が抱えるべきは **(a) 短期 work-context** / **(b) project-specific feedback** / **(c) 個人 user 設定** のみ。以下は ai-tools 配下に切り出し対象:

| memory パターン | 切り出し先 |
|---|---|
| 汎用 rule (secret / writing / git / db / security) | `rules/<topic>.md` に統合 |
| writing guideline / 文体規範 | `guidelines/writing/` に統合 |
| design / architecture knowledge | `guidelines/<area>/` に統合 |
| ツール仕様 / 参照資料 / 履歴 | `references/<topic>.md` に move |
| Serena onboarding artifact (`codebase_structure.md` / `task_completion_checklist.md` / `suggested_commands.md` / `style_and_conventions.md`) | `.serena/memories/` 復元 or archive |

**heuristic 検出**:

- file 名 prefix `knowledge_` → references 候補
- file 名 prefix `writing_failure_` → guidelines/writing 候補
- file 名 prefix `feedback_no_*` で「禁止 rule」性質 → rules/ 候補
- description / body に「rule」「禁止」「常に」「必ず」キーワード含 → rules 候補
- Serena 標準 file 名 (codebase_structure / suggested_commands / style_and_conventions / task_completion_checklist) → Serena memories 候補

**実行**:

- dry-run: 候補 list + 提案先 path
- `--apply`: **自動 move しない** (内容 merge / 構造調整が必要なため)。trash dir に「graduation-candidates.md」manifest 書出のみ → user 手動 merge

> graduate は memory 設計の根本治療。継続して回せば memory は短期 context のみになる。

### Description rescue

frontmatter `description` 欠落 file:

1. body line 1 先頭 80 字 (`#` `-` `*` strip)
2. `--apply` で frontmatter 書込 (body 不変)
3. MEMORY.md 反映

## MEMORY.md edit policy

**Prune only**: 既存 free format (emoji / multi-line / index-only) 尊重、regenerate 禁止。

- trashed file link 行削除
- rescue 済 file 無 link なら 1 行 append
- index-only entry は manual 保持
- emoji / 装飾 保持

## Example

```text
$ /memory-clean --days=7 --cluster --small=20
[memory-dir] ~/ai-tools/memory/
[dry-run] enumerate only, no file changes
[work-context-expired] 5 files (>7d)
[duplicate] 0 / [description-missing] 2
[cluster] feedback_no_* (6) / feedback_hook_* (3) / feedback_pr_* (2)
[small <20] 18 files (merge 候補、user 判断)
Run: /memory-clean --apply で auto-delete 実行 / cluster・small は手動 merge

$ /memory-clean --apply
[memory-dir] ~/ai-tools/memory/
[enumerate] auto-delete のみ → [trash] .trash-20260629-1418/ 作成
[moved] work-context 5 / duplicate 0 / [rescued] 2 / [memory.md] -5 +2
[trash-retain] 2 世代 (limit 3) done
```

## Fallback

| Scenario | Action |
|---|---|
| memory dir 両方 missing | "memory dir not found" 報告して exit |
| trash dir 作成失敗 | abort + chat 報告 |
| frontmatter parse 失敗 | file skip、warnings 追加 |
| mv permission denied | file skip、warnings 追加 |
| 全候補 0 | "nothing to clean" exit |

## Rollback

```bash
MEM=~/ai-tools/memory  # または ~/.claude/projects/.../memory
ls -t $MEM/.trash-*/
mv $MEM/.trash-YYYYMMDD-HHMM/foo.md $MEM/
```

3 世代 retain で直近 3 batch 復元可。

## When to use

- 月次 cleanup
- MEMORY.md 100 行超 + session start 重い時
- `/retrospective` 後
- `--cluster` で feedback topic 重複疑い時
- `--small=20` で merge 候補 audit 時

## Related

- `/memory-save` — memory 追加
- `/reload` — memory reload
- `/retrospective` — retrospective
- `/serena-update-fix` — Serena MCP update (memory 独立)

ARGUMENTS: $ARGUMENTS
