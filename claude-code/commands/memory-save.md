---
allowed-tools: Write, Read, Bash
description: Quick auto-memory save — record current work state to ~/.claude/projects/.../memory/
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state to Claude Code auto-memory (`~/.claude/projects/<project-key>/memory/`) in 1 command.

> **CLAUDE.md compliant**: Write to Serena `.serena/memories/` is forbidden (avoid dual management, 2026-06-10 decision). This command writes to auto-memory only.

## Flow

1. **Auto-generate save content** (7 fields: task / progress / files / next-action / project / last 3 messages / skill)
2. **Auto-determine memory name**: from arg or auto-named `work-context-YYYYMMDD-<topic>`
3. **Save**: Write tool to `~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/<name>.md`
4. **Update MEMORY.md**: append 1-line entry at end (`- [Title](file.md) — one-line hook`)
5. **Confirm**: output saved path + summary to chat

## File format

```yaml
---
name: <kebab-case-slug>
description: <one-line summary>
metadata:
  type: project
---

<body 7 field>
```

> 連続漢字 5 字以上は助詞で開く (例: 「並列実装可能」→「並列で実装できる」)。

## Options

| Arg | Description | Example |
|-----|-------------|---------|
| (none) | auto-name (`work-context-YYYYMMDD-<topic>`) | `/memory-save` |
| `<name>` | specify memory name | `/memory-save auth-refactor-progress` |
| `clear` | save (auto-name) + `/clear` 直前準備: 保存後 `/reload <name>` を clip (`pbcopy`) にコピーし、次セッションへの貼り付け再開を準備する | `/memory-save clear` |
| `exit` | save (auto-name) + タスク終了案内: 保存先 path と「次セッションで `/reload <name>` で復元可」のみ提示。clip コピー不要 (CLI を `exit` で抜けて別タスク開始想定) | `/memory-save exit` |

## `clear` 引数の追加処理

`$ARGUMENTS == "clear"` の時のみ、保存完了後に以下を実行する。

1. 保存した memory name (auto-name の topic 含む slug) を変数に保持
2. Bash で `printf '/reload %s' "<name>" | pbcopy` を実行 (改行なし、貼り付け即実行)
3. chat に「`/reload <name>` を clip にコピー済。`/clear` 後に貼り付けて再開」と報告
4. `/clear` 自体は user が手動実行 (自発的に発火しない)

pbcopy 不在 (Linux 等) の場合は `xclip -selection clipboard` → `wl-copy` の順で fallback、いずれもなければ chat に literal を出力して user に手動コピー案内。

## `exit` 引数の追加処理

`$ARGUMENTS == "exit"` の時のみ、保存完了後に以下を実行する。タスク単位の clean exit (CLI を `exit` で抜ける) 想定なので、clip コピー / 続きセッション準備は行わない。

1. 保存した memory file の絶対 path を chat に提示
2. 「次セッションで復元したい場合は `/reload <name>`」とだけ案内 (実行しない)
3. CLI の `exit` 自体は user が手動実行 (自発的に発火しない)
4. systemMessage / additionalContext を汚さず、簡潔 1-2 行で報告完了

## When to use

- Mid-point save for long tasks
- Manual backup before compact (`/compact`)
- Hand-off to next session

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | `mkdir -p` で作成 |
| Write 権限 fail | content を chat 出力、user に手動 save 案内 |
| name 衝突 | auto-suffix `-2`, `-3` |

ARGUMENTS: $ARGUMENTS
