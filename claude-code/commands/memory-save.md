---
allowed-tools: Write, Read, Bash
description: Quick auto-memory save — record current work state to ~/ai-tools/memory/
argument-hint: "[name] [--preview|--merge|clear|exit]"
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state in 1 command. CLAUDE.md 規約 (Serena `.serena/memories/` と `~/.claude/projects/.../memory/` への write は禁止)。

## Save target dir (cwd 自動分岐、2026-06-30 改訂)

| cwd の git toplevel | save 先 |
|---|---|
| `${HOME}/ai-tools` (ai-tools repo) | `${HOME}/ai-tools/memory/` |
| 他 repo (`~/ghq/<host>/<org>/<repo>` 等) で `<repo-parent>/memory/` dir が存在 | `<repo-parent>/memory/<repo-basename>/` (例: `~/ghq/github.com/<org>/<repo>` → `~/ghq/github.com/<org>/memory/<repo>`) |
| 上記いずれも該当しない | fallback `${HOME}/ai-tools/memory/` |

override: 環境変数 `MEMORY_SAVE_DIR` が set されていればそれを最優先する。canonical: `scripts/memory-save-helper.sh:_resolve_memory_dir`。

> **Helper script 必須**: MEMORY.md 更新 / collision 回避 / 同日 list 取得は `scripts/memory-save-helper.sh` 経由で実行する (AI の Write/Edit ばらつき排除)。本体 body の Write のみ AI 側担当。

## Flow

> **`clear` arg がある場合は step 1-6 を skip** し、後述 `clear post-processing` の専用 path に進む (個別 file を作らず MEMORY.md に 1 行 prepend のみ、memory 肥大化対策)。

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
| `clear` | **個別 file を作らず** MEMORY.md に 1 行 entry を prepend、`/clear` 案内 (memory 肥大化対策、2026-06-30 改訂) |
| `exit` | save 後 path + restore 手順を 1-2 行で chat 出力 (clipboard なし) |

`--preview` `--merge` は他 arg と併用可 (`/memory-save foo --preview`)。

## `clear` post-processing

`$ARGUMENTS` に `clear` 含む時の動作 (2026-06-30 改訂、memory 肥大化対策):

1. **個別 file (`work-context-*.md`) を作らない**。通常 Flow の step 2-5 (Body 生成 / Name 解決 / Preview / Write) を skip する。
2. 現 session の `<topic>` と 1 行 `<summary>` を決定 (AI 側、最後の commit hash も任意で添える)
3. `bash ~/ai-tools/claude-code/scripts/memory-save-helper.sh append-clear-line <topic> <summary> [<commit>]` を実行 (helper が MEMORY.md 先頭に 1 行 prepend)
4. format: `- \`YYYY-MM-DD\` [clear] <topic> — <summary> (commit: <hash>)`
5. 「memory index に 1 行追記済。次 session は MEMORY.md を Read して再開する。`/clear` 可」を 1 行 chat
6. 旧仕様 (`/reload <name>` pbcopy) は **廃止** — 個別 file がないので reload 対象がない

### 復元方法 (次 session)

- 次 session は session-start hook が MEMORY.md を auto-load (`~/ai-tools/memory/MEMORY.md` は 200 行まで context 注入される)
- 詳細復元したい場合: 関連 git commit を `git show <hash>` で確認、または個別 memory file (`feedback-*.md` 等) を Read

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
