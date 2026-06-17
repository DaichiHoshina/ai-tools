---
allowed-tools: Bash, Read, Write, Edit
description: Auto-memory 整理 — 古い work-context を trash へ退避 / MEMORY.md prune / 重複統合。Default dry-run、--apply で実行
effort: low
---

# /memory-clean - Memory housekeeping (auto-memory)

Claude Code auto-memory (`~/.claude/projects/-Users-daichi-hoshina-ghq-github-com-DaichiHoshina-ai-tools/memory/`) を整理する。

> **方針**: 「迷ったら抽出」原則を尊重し `mtime` を価値の代理指標として使わない。削除は work-context (日付付きで明示的に短命) と user 確認済 duplicate のみ。stale 自動削除は廃止。
>
> **削除しない**: file は `rm` せず `.trash-YYYYMMDD-HHMM/` へ `mv` する (3 世代 retain)。誤判定時の rollback path を確保する。
>
> **scope 外**: Serena symbol DB refresh は `/serena-update-fix` または明示 activation に分離。CLAUDE.md 規約により Serena `.serena/memories/` も触らない。

## 引数

- `(none)` / `--dry-run`: 削除候補と統合候補を chat 表示、file 変更なし (default)
- `--apply`: dry-run の結果を反映 (trash 退避 + MEMORY.md prune を実行)

> 破壊的操作なので default は dry-run。`--apply` でも `rm` せず trash 退避なので rollback 可能。

## Flow

### Stage 1: dry-run (default)

1. **対象列挙**
   - `work-context-YYYYMMDD-*.md` で `YYYYMMDD` が **14 日以上経過** → trash 候補
   - 全 `*.md` で description / name の **完全一致または prefix 3-token 一致** → duplicate 候補 (mtime 新しい方を残す)
   - description 欠落 file → 救済候補 (本文 head 抽出案を提示)
2. **chat 表示**
   - trash 候補 list (file 名 + 経過日数)
   - duplicate 候補 pair (残す / 退避)
   - description 救済候補 (file + 提案 description)
   - 「`/memory-clean --apply` で実行」案内
3. file 変更なしで終了

### Stage 2: --apply (dry-run 結果を反映)

`--apply` 単独実行時も Stage 1 の対象列挙を先に実行し、chat に結果表示してから以下に進む (誤退避時の trace 確保)。

1. **trash 退避準備**: `memory/.trash-YYYYMMDD-HHMM/` を mkdir
2. **work-context 退避**: 期限切れ file を trash へ mv
3. **duplicate 退避**: 古い方を trash へ mv
4. **description 救済**: 提案 description を frontmatter に書き込み (本文 head から抽出した 1 行)
5. **MEMORY.md prune** (※既存 entry の整理のみ、自由 format 尊重):
   - trash 移動した file への link を削除
   - 残った file への link が無ければ末尾に `- [<name>](<file>.md) — <description>` で 1 行追加
   - file 不在の index-only entry (「(file 整理済、要約のみ残存)」等) は手動管理として保持、自動削除しない
6. **trash 世代管理**: `.trash-*` が 3 個超なら mtime 古い順に削除

## 対象外 (処理しない)

- `MEMORY.md` 自体 (本文書き換えは prune 系のみ)
- `compact-restore-*.md` (PostCompact hook が生成)
- `.trash-*/` 以下
- frontmatter `metadata.protect: true` を持つ memory
- **mtime 30 日 stale 削除は廃止** — 触られていない = 価値ない、ではない

## 判定詳細

### work-context 期限

- file 名 regex: `^work-context-(\d{8})-.*\.md$`
- 抽出した `YYYYMMDD` を `date -j -f %Y%m%d` で UNIX time 化
- `today - 14日` より古ければ trash 退避対象 (削除ではなく退避)

### duplicate 判定

1. **name prefix 一致**: name slug の最初の 3 token (`-` split) が同一
   - 例外: `work-context-YYYYMMDD-*` は prefix 判定対象外 (同日複数件が全件誤検知されるため、`[[memory-clean-design-gaps]]` 実測根拠)。description 完全一致のみ適用する
2. **description 完全一致**: 句読点・空白除去後の string が完全一致
3. 候補 pair の mtime 新旧を比較、古い方を trash 退避

> Jaccard 0.6 等の fuzzy 判定は廃止 (false positive の元)。完全一致 / 明示 prefix のみ。

### description 救済

frontmatter `description` 不在 file:

1. 本文 1 行目から見出し記号 (`#` `-` `*`) を除いた先頭 80 字を提案
2. `--apply` で frontmatter に書き込み (本文は触らない)
3. MEMORY.md にも反映

## MEMORY.md 編集方針

**Prune only**: 既存 entry の自由 format (絵文字 / ⚠️ / 複数行 / 「(file 整理済、要約のみ残存)」等) を尊重し、再生成しない。

- trash 退避した file の link 行は削除
- 救済 description を持つ新 file は末尾に 1 行追記
- file 不在の index-only entry は手動管理として保持
- 絵文字 / 装飾は保持

## 実行例

```text
$ /memory-clean
[dry-run] 対象列挙のみ、file 変更なし
[work-context-expired] 2 file (work-context-20260520-foo.md ほか)
[duplicate] 0 / [description-missing] 1 (提案 description 表示)
実行: /memory-clean --apply

$ /memory-clean --apply
[列挙] dry-run と同内容 → [trash] .trash-20260617-1145/ 作成
[退避] work-context 2 / duplicate 0 / [rescue] 1 / [memory.md] -2 +1
[trash-retain] 2 世代 (上限 3) 完了
```

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | chat に「memory dir なし」報告、終了 |
| trash dir 作成 fail | 中断、chat に error 報告 |
| frontmatter parse fail | その file は skip、warning に追加 |
| mv 権限 fail | その file は skip、warning に追加 |
| 期限切れ / duplicate / 救済 すべて 0 件 | 「整理対象なし」と表示して終了 |

## Rollback

```bash
ls -t ~/.claude/projects/-Users-daichi-hoshina-ghq-github-com-DaichiHoshina-ai-tools/memory/.trash-*/
mv ~/.claude/projects/.../memory/.trash-YYYYMMDD-HHMM/foo.md \
   ~/.claude/projects/.../memory/
```

3 世代まで `.trash-*` を retain するため、直近 3 回分の退避は復元可能。

## When to use

- 月 1 回程度の定期整理
- `MEMORY.md` の entry が 20 件超で session start が重くなったとき
- `/retrospective` 後の cleanup

## 関連 command

- `/memory-save` — memory 追加
- `/reload` — memory 読込
- `/retrospective` — 振り返り (memory も参照)
- `/serena-update-fix` — Serena MCP 本体 update (memory とは独立)

ARGUMENTS: $ARGUMENTS
