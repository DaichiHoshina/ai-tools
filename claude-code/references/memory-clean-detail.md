# /memory-clean 詳細仕様

`commands/memory-clean.md` の補足仕様。実装参照用。

## Detection details

### work-context expiry

- regex: `^work-context-(\d{8})-.*\.md$`
- `date -j -f %Y%m%d` で Unix time 化
- `today - N*86400` より古ければ trash 行き (N は fixed 14 日)

### Duplicate detection

1. **Name prefix match**: name slug `-` split の最初 3 tokens 一致
   - 例外: `work-context-YYYYMMDD-*` は prefix match 除外 (同日複数で false positive)。description exact match のみ適用
2. **Description exact match**: punctuation/whitespace strip 後の同一 string
3. pair の mtime 比較、古い方を trash

Fuzzy match (Jaccard 0.6 等) 禁止 (false positive 過多)。exact / explicit prefix のみ。

### Topic cluster

`feedback_<topic>_*` / `knowledge_<topic>_*` / `writing_failure_*` の topic part で group。3 file 以上を merge 候補として列挙。

```
[cluster] feedback_no_* (6): feedback_no_derived_literals.md, feedback_no_env_output.md, ...
[cluster] feedback_hook_* (3): feedback_hook_ng_list_pitfalls.md, ...
```

merge は user 手動 (旧 file を `mv` で trash)。skill は merge を実行しない。

### Small file

`wc -l < <file>` が 20 行未満の `*.md` を list 表示。除外: `MEMORY.md` / `pending-improvements*` / `compact-restore-*`。merge は user 判断。

### Orphan / dead link

index (MEMORY.md) と file 実体の対応ずれを両方向で検出する。

**方向 1: orphan** — file は存在するが MEMORY.md 内 link にも他 memory file の `[[name]]` 参照にも現れない。

| 状態 | 対応 |
|---|---|
| 参照 0 + 内容 active rule | MEMORY.md に index 追加 |
| 参照 0 + 内容 obsolete | 手動 trash |
| user_* 系で意図的に未 link | keep (false positive) |

```bash
# orphan 検出 (work-context / MEMORY.md / pending-improvements は除外)
for f in *.md; do case "$f" in MEMORY.md|pending-improvements.md|work-context-*) continue;; esac
  grep -q "$f" MEMORY.md || echo "ORPHAN: $f"; done
```

**方向 2: dead link** — MEMORY.md が `[...](name.md)` で link するが link 先 file が実在しない (trash 済み / 手動削除の残骸)。該当 index 行を prune する (`--apply` 対象、trash 送りではなく MEMORY.md 行削除)。

```bash
# dead link 検出 (link 先 file 不在)
grep -oE '\]\(([a-z][^)]+\.md)\)' MEMORY.md | sed -E 's/\]\(|\)//g' \
  | while read l; do [ -f "$l" ] || echo "DEAD-LINK: $l"; done
```

> work-context を trash 送りにした後は MEMORY.md prune (flow Stage 2 step 4) で link 行が消えるが、過去に手動削除された file の link が残ると dead link 化する。dry-run で両方向を必ずチェックする。

### Graduate — memory → ai-tools 切り出し

| memory パターン | 切り出し先 |
|---|---|
| 汎用 rule (secret / writing / git / db / security) | `rules/<topic>.md` |
| writing guideline / 文体規範 | `guidelines/writing/` |
| design / architecture knowledge | `guidelines/<area>/` |
| ツール仕様 / 参照資料 / 履歴 | `references/<topic>.md` |
| Serena artifact (codebase_structure / suggested_commands 等) | `.serena/memories/` 復元 or archive |

heuristic 検出:
- `knowledge_` prefix → references 候補
- `writing_failure_` prefix → guidelines/writing 候補
- `feedback_no_*` で「禁止 rule」性質 → rules/ 候補
- description / body に「rule」「禁止」「常に」「必ず」→ rules 候補
- Serena 標準 file 名 → Serena memories 候補

`--apply` 時は自動 move しない。`graduation-candidates.md` manifest を trash dir に書出のみ → user 手動 merge。

### Description rescue

frontmatter `description` 欠落 file:
1. body line 1 先頭 80 字 (`#` `-` `*` strip) を description に
2. `--apply` で frontmatter 書込 (body 不変)
3. MEMORY.md 反映

## Rollback

```bash
MEM=~/ai-tools/memory  # または ~/.claude/projects/.../memory
ls -t $MEM/.trash-*/
mv $MEM/.trash-YYYYMMDD-HHMM/foo.md $MEM/
```

3 世代 retain で直近 3 batch 復元可。
