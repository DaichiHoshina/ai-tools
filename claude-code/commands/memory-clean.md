---
allowed-tools: Bash, Read, Write, Edit, Agent, AskUserQuestion, TaskCreate, TaskUpdate
description: Auto-memory housekeeping — move stale work-context to trash, prune MEMORY.md (orphan / dead-link 整合含む), suggest topic clusters / small-file merge / graduate (ai-tools 切り出し) / import 他 repo memory. Default dry-run; --apply to execute.
argument-hint: "[--apply] [--days=N] [--cluster] [--small=N] [--orphan] [--xref-audit] [--graduate] [--import=<src-dir>] [--keep-src]"
effort: low
---

# /memory-clean - Memory housekeeping (auto-memory)

Cleans up auto-memory. **Memory dir auto-detect**: `~/ai-tools/memory/` を優先、無ければ `~/.claude/projects/-Users-daichi-hoshina-ghq-github-com-DaichiHoshina-ai-tools/memory/` を fallback。

> **Policy**: `mtime` を value proxy にしない。auto delete は work-context (date prefix で短命明示) と name/description exact dup のみ。topic cluster / small file は**提案のみ** (user 判断)。
>
> **No rm**: `.trash-YYYYMMDD-HHMM/` に `mv` (3 世代 retain) で rollback path 確保。
>
> **Out of scope**: Serena symbol DB → `/serena-update-fix`。Serena `.serena/memories/` 触禁止。

## Arguments

| arg | 動作 |
|---|---|
| (none) / `--dry-run` | 候補表示のみ、変更なし (default) |
| `--apply` | dry-run 結果実行 (work-context trash + duplicate trash + MEMORY.md prune) |
| `--days=N` | work-context expiry 閾値 (default 14)。7=aggressive / 30=conservative |
| `--cluster` | `feedback_<topic>_*` / `knowledge_<topic>_*` 等の topic group 表示 (3 file 以上の cluster のみ、merge は user 判断) |
| `--small=N` | N 行未満の file を merge 候補 list 表示 (default off、`--small=20` 推奨) |
| `--orphan` | index と file の対応ずれを両方向で検出する。(1) orphan = MEMORY.md にも他 memory file にも参照されない孤立 file (index 追加 or 削除判断)、(2) dead link = MEMORY.md が link するが link 先 file が実在しない残骸 (trash 済み / 手動削除の残り、該当行を prune)。どちらも trash 候補ではない |
| `--xref-audit` | feedback / knowledge 間の `[[name]]` cross-ref を検査する。(1) kebab ↔ snake 表記揺れ (実 file が別 case で存在) → `--apply` で自動修正、(2) 参照先 file 不在で ai-tools canonical (`rules/` `guidelines/` `CLAUDE.md`) に該当あり → 差替候補提示、(3) 参照先 file 不在で canonical なし (削除済 memory) → `{{deleted:<name>}}` 記号化候補提示 |
| `--graduate` | memory 内容を ai-tools 配下 (`rules/` `guidelines/` `references/`) に切り出すべき候補を heuristic で提案 |
| `--import=<src-dir>` | 他 repo memory (例: `~/ghq/github.com/<org>/memory/`) から汎用 knowledge を抽出し ai-tools 側 (`rules/` `guidelines/` `SKILL/` `memory/`) に反映する。default は dry-run で Tier A/B/C の候補提示のみ、`--apply` 併用で反映 + 元 file 削除 + cross-ref 差替を実行 |
| `--keep-src` | `--import` + `--apply` 時も元 file を削除しない (反映のみ) |

詳細仕様 (Detection logic / Graduate heuristic / Rollback) → `references/memory-clean-detail.md`

## Flow

### Stage 1: dry-run (default)

1. Memory dir 検出 (auto-detect)
2. **Auto-delete 候補列挙**
   - `work-context-YYYYMMDD-*.md` で N+ 日経過 → trash candidate
   - `description` exact match / name prefix 3 tokens 一致 → duplicate candidate (新 mtime keep)
   - frontmatter `description` 欠落 → rescue candidate
3. **提案候補列挙** (`--cluster` / `--small=N` 指定時のみ)
4. chat 出力 → exit、変更なし

### Stage 2: --apply

dry-run 列挙再実行 → 表示 → 実行。

1. trash dir `mkdir memory/.trash-YYYYMMDD-HHMM/`
2. expired work-context → `mv`
3. duplicate older → `mv`
4. description rescue: body line 1 先頭 80 字 → frontmatter 書込 (body 不変)
5. MEMORY.md prune: trashed file link 行削除 / dead-link 行削除 (link 先 file 不在、`--orphan` 検出分) / rescue 済 file 無 link なら 1 行 append / index-only entry は手動保持
6. `--xref-audit` 併用時: kebab ↔ snake 表記揺れは `sed` で自動修正、canonical 差替 / `{{deleted:}}` 記号化は候補提示のみで user 判断 (`--apply` でも自動適用しない)
7. trash rotation: `.trash-*` 3 超なら最古削除

> **cluster / small は --apply 対象外**。提案表示のみ、auto merge 禁止。
> **`--xref-audit` の canonical 差替 / `{{deleted:}}` 記号化も --apply 対象外**。表記揺れ (kebab ↔ snake) のみ自動修正、他は候補提示のみ。

### Stage 3: --import=<src-dir> (他 repo memory 取込)

`--import` が指定されたときのみ実行、default では skip する。

1. `<src-dir>` 配下 subdir を列挙 (`_org` / project 別 dir 等)
2. subdir ごとに `explore-agent` を並列 fan-out (parallelism = subdir 数、max 8)。各 agent への prompt:
   - 全 file を read、**汎用性 high の候補**を抽出
   - **除外基準**: 社内 product 名 / 個人名 / 会社名 / 固有 path を含む / 既存 ai-tools rule と重複 / 単発 incident log
   - 既知知識として `~/ai-tools/claude-code/CLAUDE.md` / `rules/*.md` / `guidelines/writing/*.md` / `~/ai-tools/memory/feedback_*.md` を渡す
   - 出力: 候補 file / 提案先 / 汎用化後の要旨 (常体 plain JP) / 汎用性 confidence / 伏字化対象
3. 結果を Tier 分類して chat に一覧表示:
   - **Tier A**: `rules/` `guidelines/` に独立 file / 独立追記
   - **Tier B**: 既存 file への追記型 (差分小)
   - **Tier C**: `memory/` の feedback として保存
4. `AskUserQuestion` で採用 tier 選択 (1 括採用 / 段階採用 / 個別選抜)
5. `--apply` 併用時:
   - 対象 tier の各 file を canonical 反映 (`Write` 新規 or `Edit` 追記)、伏字化を適用する
   - 元 file 削除: `rm <src-dir>/<subdir>/<file>` (`--keep-src` なら skip)
   - 元 repo の MEMORY.md index prune: 削除 file の行を `sed` で除去
   - 生きた feedback からの dead cross-ref 修正: 削除 file への `[[name]]` 参照を ai-tools canonical 参照に差替 (例: ``ai-tools `rules/foo.md` — <説明>``)
   - work-context / .trash 系 log 内の dead ref は履歴保持のため触らない
6. 完了報告: 反映 file 数 / 削除 file 数 / 差替 cross-ref 数

## Out of scope (auto-delete しない)

- `MEMORY.md` 本体 (prune edit のみ)
- `compact-restore-*.md` / `.trash-*/` 中身
- `metadata.protect: true` の memory
- **mtime 30 日 stale auto-delete 禁止** (`untouched ≠ valueless`)
- cluster / small file (提案のみ)

## Example

```text
$ /memory-clean --days=7 --cluster --small=20 --orphan --xref-audit
[memory-dir] ~/ai-tools/memory/
[dry-run] enumerate only, no file changes
[work-context-expired] 10 files (>7d)
[duplicate] 0 / [description-missing] 0
[orphan] 3 files (index 未登録) / [dead-link] 2 (link 先 file 不在)
[xref-audit] fixable(表記揺れ) 5 / canonical 差替候補 3 / {{deleted:}} 記号化候補 11
[cluster] feedback_no_* (6) / feedback_hook_* (3)
[small <20] 18 files
Run: /memory-clean --apply で expired trash + MEMORY.md prune (dead-link 行含む) + 表記揺れ自動修正を実行 / canonical 差替・{{deleted:}} 記号化・cluster・small・orphan index 追加は手動
```

```text
$ /memory-clean --import=~/ghq/github.com/<org>/memory/ --xref-audit
[memory-dir] ~/ai-tools/memory/
[import-scan] fan-out 7 explore-agent (subdir 数)
[dry-run] enumerate only, no file changes
[import-candidates] Tier A: 8 / Tier B: 10 / Tier C: 7
[xref-audit] fixable(表記揺れ) 5 / canonical 差替候補 3 / {{deleted:}} 記号化候補 11
Run: /memory-clean --import=<src-dir> --apply で採用 tier 反映 + 元 file 削除 + cross-ref 差替を実行 (--keep-src で削除 skip)
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
| `--import` 対象 dir が ai-tools は public repo 前提の伏字化不能候補のみ | 該当 tier を skip、chat に警告 |

## When to use

- 月次 cleanup / MEMORY.md 100 行超 + session start 重い時
- `/retrospective` 後
- `--cluster` で feedback topic 重複疑い時 / `--small=20` で merge 候補 audit 時
- `--import=<src-dir>` で他 repo memory から汎用 knowledge を切り出したい時

## Related

- `/memory-save` — memory 追加
- `/reload` — memory reload
- `/retrospective` — retrospective
- `/serena-update-fix` — Serena MCP update (memory 独立)
- `rules/public-repo-private-data-block.md` — `--import` 時の伏字化 canonical

ARGUMENTS: $ARGUMENTS
