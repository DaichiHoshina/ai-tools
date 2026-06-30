---
allowed-tools: Write, Read, Bash
description: Quick auto-memory save — record current work state to ~/ai-tools/memory/
argument-hint: "[name] [--preview|--merge|clear|exit]"
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state to `~/ai-tools/memory/` in 1 command. CLAUDE.md 固定 dir (Serena `.serena/memories/` と `~/.claude/projects/.../memory/` への write は禁止)。

> **Helper script 必須**: MEMORY.md 更新 / collision 回避 / 同日 list 取得は `scripts/memory-save-helper.sh` 経由で実行する (AI の Write/Edit ばらつき排除)。本体 body の Write のみ AI 側担当。

## Flow

1. **同日 file 確認** (auto): `bash ~/ai-tools/claude-code/scripts/memory-save-helper.sh list-today`
   - 既存ありかつ user が `--merge` or `name` 未指定 → 「同日 N 件あり: <slug list>。merge する? 新規 (n)?」を 1 問 (`--merge` ありなら無条件 merge、`--preview` なら skip)
   - merge 採択 → 既存 file を Read して body 統合、name は最古 file 名を継承
2. **Body 生成** (3 必須 + 4 optional): 後述の `File format` 節を参照し、optional は空なら省略する
3. **Name 解決**: `bash ... resolve-name <base>` で collision 時 `-2/-3` suffix 自動付与 (base = arg or `work-context-YYYYMMDD-<topic>`)
4. **Preview mode** (`--preview`): body を chat に出力して終了、write しない
5. **Write**: `~/ai-tools/memory/<name>.md` に Write
6. **MEMORY.md 更新**: `bash ... update-index <name> <description> <hook>` (helper が dedup + prepend)
7. **Report**: saved path + 1 行 summary

## File format

```yaml
---
name: <kebab-case-slug>
description: <one-line summary>
metadata:
  type: project
---

## task               # 必須
## progress           # 必須
## next-action        # 必須
## files              # optional (空なら省略)
## project            # optional
## last 3 messages    # optional
## skill              # optional
```

3 必須 (task / progress / next-action) のみで完結可。短 session は 10 行台で OK。

## Options

| Arg | Behavior |
|-----|----------|
| (none) | auto-name `work-context-YYYYMMDD-<topic>`、同日 file あれば merge 確認 |
| `<name>` | name 指定 (helper が collision 回避 suffix 付与) |
| `--preview` | dry-run、body を chat 出力のみ。write も MEMORY.md 更新もしない |
| `--merge` | 同日 work-context 最古 file に統合追記 (確認 skip) |
| `clear` | save 後 `/reload <name>` を pbcopy、`/clear` 案内 |
| `exit` | save 後 path + restore 手順を 1-2 行で chat 出力 (clipboard なし) |

`--preview` `--merge` は他 arg と併用可 (`/memory-save foo --preview`)。

## `clear` post-processing

`$ARGUMENTS` に `clear` 含む時のみ save 後実行:

1. `printf '/reload %s' "<name>" | pbcopy` (no newline)
2. 「`/reload <name>` copied. paste after `/clear`」を 1 行 chat
3. User が `/clear` 手動実行

Fallback (Linux): `xclip -selection clipboard` → `wl-copy` → literal chat 出力。

## `exit` post-processing

`$ARGUMENTS` に `exit` 含む時のみ save 後実行:

1. saved file absolute path 出力
2. 「next session: `/reload <name>`」を 1 行
3. 1-2 行 report のみ、systemMessage 非汚染

## When to use

- Long task 途中保存 / `/compact` 前 backup / next session hand-off
- 同日 topic 継続作業 → `--merge` で work-context 乱立防止

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | `mkdir -p` (helper が自動) |
| Write 失敗 | body を chat 出力、manual save 案内 |
| Helper script 不在 | inline で `~/ai-tools/memory/` write + MEMORY.md 手 prepend (warn 表示) |
| name collision | helper が `-2/-3` suffix |

ARGUMENTS: $ARGUMENTS
