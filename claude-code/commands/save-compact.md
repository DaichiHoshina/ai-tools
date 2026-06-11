---
allowed-tools: Write, Read
description: Save Serena memory → /compact → auto reload (3 steps in 1 command)
effort: low
---

# /save-compact - Save + Compact + Reload (1 command)

`/memory-save` → `/compact` → `/reload` 相当を 1 打鍵で済ませる wrapper。

> Alias: `/sc`。3 step 連打が面倒な場合の short-cut。

## Flow

### 1. Memory save (mandatory)

Claude Code auto-memory (`~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/compact-restore-<timestamp>.md`) に Write tool で保存する。pre-compact.sh の hook が出す systemMessage と同じ 7 field を埋める。

> **Serena `mcp__serena__write_memory` は使わない**: `compact-restore-*` は Serena の `ignored_memory_patterns` に hit して write 拒否される (実測 2026-06-11)。post-compact-reload.sh も auto-memory 側を読むため Write 直書きで整合する。

```text
Write(
  file_path: "~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/compact-restore-<timestamp>.md",
  content: <frontmatter + 7 field>
)
```

frontmatter format (auto-memory 規約):

```yaml
---
name: compact-restore-<timestamp>
description: <one-line summary>
metadata:
  type: project
---
```

7 field:

1. 現在のタスク (元の指示文を literal で引用)
2. 完了済みステップ / 残ステップ
3. 編集中の file path + 変更要約 (diff レベル)
4. 次に実行すべきアクション (command レベル)
5. プロジェクトパス + ブランチ名
6. 直前の user 発言 3 件要約
7. 使用中の skill / command 名

**保存失敗時**: Write が error を返したら `/compact` は **発火しない**。user に「memory save 失敗、compact 中止」と報告 (復元不可能になるため、`commands/reload.md` 規定の compact-restore-* fallback が成立しなくなる)。

### 2. Compact

memory save 成功確認後、`/compact` を発火する。built-in command のため AI 側で実行する。

### 3. Reload (auto)

`post-compact-reload.sh` (SessionStart compact hook) が自動 trigger するため AI 側操作不要。

## When to use

| シナリオ | use? |
|---------|------|
| 長 session で context が膨らんできた | ✅ |
| task 境界 (clean state で次タスク) | ❌ `/clear` の方が安い |
| 同一問題 2 回連続失敗 | ❌ `/clear` + prompt 書き直し |
| memory 保存だけしたい (compact 不要) | ❌ `/memory-save` 単体 |

## Fallback

| Scenario | Action |
|----------|--------|
| auto-memory dir 不在 | dir を mkdir -p で作成、保存続行 |
| Write 権限 fail | `~/.claude/memory-fallback/<name>.md` 保存 + warn、compact 中止 |
| memory name 衝突 | auto-suffix `-2`, `-3` |
| /compact 発火失敗 | 保存済 memory は残る、user に手動 `/compact` 指示 |

ARGUMENTS: $ARGUMENTS
