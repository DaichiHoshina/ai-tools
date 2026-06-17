---
allowed-tools: Bash, Read, Write, Edit, mcp__serena__activate_project, mcp__serena__get_symbols_overview
description: Auto-memory 整理 + Serena symbol DB refresh — 古い work-context 削除 / stale 削除 / 重複統合 / MEMORY.md 再生成 / symbol cache 更新を完全自動実行
effort: low
---

# /memory-clean - Memory housekeeping (auto-memory + Serena symbol DB)

Claude Code auto-memory (`~/.claude/projects/-Users-daichi-hoshina-ghq-github-com-DaichiHoshina-ai-tools/memory/`) を整理し、続けて cwd の Serena symbol DB を refresh する。完全自動 (確認なし)、削除前に backup を取る。

> **方針**: `/memory-save` 蓄積による noise と `MEMORY.md` の context cost を減らす + Serena symbol cache を最新化する。
>
> **scope 外**: Serena `.serena/memories/` は CLAUDE.md で read/write 禁止 (auto-memory に一本化済) のため触らない。symbol DB cache のみ refresh する。

## Flow (完全自動、順次実行)

1. **backup**: 全 `*.md` を `memory/.backup-YYYYMMDD-HHMM/` へ copy (1 世代のみ、毎回上書き)
2. **古い work-context 削除**: `work-context-YYYYMMDD-*.md` の `YYYYMMDD` から **14 日以上経過**を削除
3. **stale 削除**: 上記以外で **mtime 30 日以上経過**を削除 (work-context 以外も対象)
4. **重複・類似統合**: name prefix 一致 or description Jaccard 類似度 ≥ 0.6 を重複候補とし、mtime 新しい方を残し古い方を削除 (内容不一致時も新しい方を正とする)
5. **MEMORY.md 再生成**: 残った `*.md` の frontmatter `name` / `description` から index を再構築
6. **Serena symbol DB refresh**: cwd に `.serena/` があれば `activate_project(project=".")` → 主要 file (`git ls-files | head -20` で抽出した上位 file) に `get_symbols_overview` を実行し cache を更新。`.serena/` 不在なら skip

## 対象外 (処理しない)

- `MEMORY.md` 自体
- `compact-restore-*.md` (PostCompact hook が生成、`/reload` で消費)
- `.backup-*/` 以下
- frontmatter `metadata.protect: true` を持つ memory (将来拡張、現状未使用)

## 判定詳細

### work-context 期限

- file 名 regex: `^work-context-(\d{8})-.*\.md$`
- 抽出した `YYYYMMDD` を `date -j -f %Y%m%d` で UNIX time 化
- `today - 14日` より古ければ削除対象

### stale 判定

- work-context 以外の全 `*.md` で `find -mtime +30`
- type 区別なし (完全自動とのバランス、user 指示で 30 日 fix)

### 重複候補抽出

1. **prefix 一致**: name slug の最初の 3 token (`-` split) が同一 → 候補
2. **description Jaccard**: 半角・全角空白で token 化、`|A∩B| / |A∪B| ≥ 0.6` → 候補
3. 候補ペアの mtime 新旧を比較、古い方を削除

## MEMORY.md format (再生成後)

```markdown
# Memory Index

- [<name>](<file>.md) — <description>
- [<name>](<file>.md) — <description>
...
```

frontmatter 不正 (`name` / `description` 不在) の memory は index 末尾に `- [<filename>](file.md) — (no description)` で記載、warning に追加。

## 実行例

```text
$ /memory-clean
[backup] memory/.backup-20260617-1130/ に 14 file 退避
[work-context-expired] 0 file 削除 (14 日超過なし)
[stale] 0 file 削除 (30 日超過なし)
[duplicate] 0 ペア統合
[memory.md] 13 entry で再生成
[serena] activate_project OK、20 file の symbol cache 更新
完了。詳細: ~/.claude/logs/memory-clean.log
```

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | 何もせず終了、chat に「memory dir なし」報告 |
| backup dir 作成 fail | 中断、chat に error 報告 |
| frontmatter parse fail | その file は skip、warning に追加 |
| 削除権限 fail | その file は skip、warning に追加 |
| `.serena/` 不在 | step 6 skip、chat に「Serena DB なし」報告 |
| `activate_project` fail | step 6 skip、warning に追加 (memory 整理結果は確定) |

## When to use

- 月 1 回程度の定期整理
- `MEMORY.md` の entry が 20 件超で session start が重くなったとき
- `/retrospective` 後の cleanup
- 大きな refactor 後 / file 大量追加削除後 (Serena symbol DB refresh 目的)

## 関連 command

- `/memory-save` — memory 追加
- `/reload` — memory 読込
- `/retrospective` — 振り返り (memory も参照)
- `/serena-update-fix` — Serena MCP 本体 update (別物。symbol DB refresh ではなく version up)

ARGUMENTS: $ARGUMENTS
