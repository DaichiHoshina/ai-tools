---
allowed-tools: Write, Read, Bash
description: Quick auto-memory save — default = clear、<topic> で merge/new auto 判定
argument-hint: "[<topic>|exit|--preview]"
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state in 1 command。**default (no arg) = clear** (MEMORY.md に 1 行 prepend、個別 file 作らず memory 肥大化を抑える)。`<topic>` 渡すと同日 exact match で **merge (既存あり) / new (無し) を auto 判定**。CLAUDE.md 規約 (Serena `.serena/memories/` と `~/.claude/projects/.../memory/` への write は禁止)。

## Save target dir (cwd 自動分岐、2026-06-30 改訂)

| cwd の git toplevel | save 先 |
|---|---|
| `${HOME}/ai-tools` (ai-tools repo) | `${HOME}/ai-tools/memory/` |
| 他 repo (`~/ghq/<host>/<org>/<repo>` 等) で `<repo-parent>/memory/` dir が存在 | `<repo-parent>/memory/<repo-basename>/` (例: `~/ghq/github.com/<org>/<repo>` → `~/ghq/github.com/<org>/memory/<repo>`) |
| 上記いずれも該当しない | fallback `${HOME}/ai-tools/memory/` |

override: 環境変数 `MEMORY_SAVE_DIR` が set されていればそれを最優先する。canonical: `scripts/memory-save-helper.sh:_resolve_memory_dir`。

> **Helper script 必須**: MEMORY.md 更新 / collision 回避 / 同日 list 取得は `scripts/memory-save-helper.sh` 経由で実行する (AI の Write/Edit ばらつき排除)。本体 body の Write のみ AI 側担当。

## Mode 判定 (arg → mode)

| `$ARGUMENTS` | Mode | 動作 |
|---|---|---|
| (empty) | **clear (default)** | 個別 file 作らず MEMORY.md に 1 行 prepend |
| `<topic>` (単語) | **auto merge / new** | 同日 `work-context-*-<topic>.md` あれば最古 file に merge、無ければ new file 作成 |
| `<topic> --preview` | **preview** | dry-run、body を chat 出力のみ、write なし |
| `exit` | **auto + exit** | auto merge/new + saved path / restore 手順出力 (topic は AI 決定) |
| `clear` (legacy) | clear | default と同義 (backward compat) |

`<topic>` は kebab-case 推奨 (`reload-fix` / `pr-review` 等)。空白含む場合は quote (`"reload fix"` → 内部で `-` 変換)。

## Flow (auto merge/new mode)

> **default (empty arg) と `clear` は step 1-6 を skip** し、後述 `clear post-processing` に進む。以下は `<topic>` / `exit` / `--preview` の flow。

1. **同 topic 同日 file 検出** (auto): `bash ~/ai-tools/claude-code/scripts/memory-save-helper.sh list-today`
   - 出力から `work-context-YYYYMMDD-*-<topic>.md` を **exact suffix match** で filter (issue key prefix は無視)
   - hit 1+ 件 → 最古 file を **auto merge 対象**として選択 (質問なし)
   - hit 0 件 → new file 作成に進む
2. **Body 生成** (3 必須 + 4 optional): 後述の `File format` 節を参照し、optional は空なら省略する。merge 時は既存 body を Read して差分追記
3. **Name 解決** (new のみ): `bash ... resolve-name work-context-YYYYMMDD-<topic>` で collision 時 `-2/-3` suffix 自動付与
   - name 組み立て前に `bash ... extract-issue-key` を呼び、現 branch から issue key (`PROJ-123` / `#123` → `123` / `issue-123`) を検出できたら **topic 先頭に prefix** する (例: `work-context-20260701-PROJ-123-reload-fix`)。検出できなければ topic のみに fallback
4. **Preview mode** (`--preview`): body を chat に出力して終了、write しない
5. **Write**: `<save-dir>/<name>.md` に Write (merge 時は最古 file を上書き)
6. **MEMORY.md 更新**: `bash ... update-index <name> <description> <hook>` (helper が dedup + prepend)
7. **Report**: saved path + merge/new どちらかを 1 行

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
| (none) | **default = clear**、個別 file 作らず MEMORY.md に 1 行 prepend |
| `<topic>` | 同日 exact match あれば **auto merge**、無ければ **new file** 作成 (質問なし) |
| `exit` | auto merge/new + saved path / restore 手順出力 (topic は AI 決定) |
| `--preview` | dry-run、body を chat 出力のみ。write も MEMORY.md 更新もしない。`<topic>` と併用可 (`/memory-save foo --preview`) |
| `clear` | default と同義 (backward compat) |

## `clear` post-processing

default (empty arg) と `$ARGUMENTS` に `clear` 含む時の動作 (2026-06-30 改訂、memory 肥大化対策):

1. **個別 file (`work-context-*.md`) を作らない**。auto merge/new flow の step 2-5 (Body 生成 / Name 解決 / Preview / Write) を skip する。
2. 現 session の `<topic>` と 1 行 `<summary>` を決定 (AI 側、最後の commit hash も任意で添える)
3. `bash ~/ai-tools/claude-code/scripts/memory-save-helper.sh append-clear-line <topic> <summary> [<commit>]` を実行 (helper が MEMORY.md 先頭に 1 行 prepend)
4. format: `- \`YYYY-MM-DD\` [clear] <topic> — <summary> (commit: <hash>)`
5. 「memory index に 1 行追記済。次 session は MEMORY.md を Read して再開する。`/clear` 可」を 1 行 chat
6. 旧仕様 (`/reload <name>` pbcopy) は **廃止** — 個別 file がないので reload 対象がない

### 復元方法 (次 session)

- 次 session は session-start hook が MEMORY.md を auto-load (`~/ai-tools/memory/MEMORY.md` は 200 行まで context 注入される)
- compaction 後の明示復元は `/reload` を使う。`/reload` の fallback chain は MEMORY.md 先頭の [clear] entry → 直近 work-context 本文 → pending-improvements の順で Read する (canonical: `commands/reload.md`)
- 詳細復元したい場合: 関連 git commit を `git show <hash>` で確認、または個別 memory file (`feedback-*.md` 等) を Read

## `exit` post-processing

`$ARGUMENTS` に `exit` 含む時のみ save 後実行:

1. saved file absolute path 出力
2. 「next session: `/reload <name>`」を 1 行
3. 1-2 行 report のみ、systemMessage 非汚染

## Auto issue key suffix

`git branch --show-current` から issue key を検出できた時、new file の topic 先頭に prefix する (helper `extract-issue-key`)。

| Branch 名 | 検出 key | file 名例 |
|---|---|---|
| `feature/PROJ-123-add-login` | `PROJ-123` | `work-context-20260701-PROJ-123-<topic>.md` |
| `fix/#456-null-guard` | `456` | `work-context-20260701-456-<topic>.md` |
| `issue-789-refactor` | `issue-789` | `work-context-20260701-issue-789-<topic>.md` |
| `feature/add-login` (key なし) | (空) | `work-context-20260701-<topic>.md` |
| ai-tools repo (main 直 push) | (空) | 同上 |

opt-in 設計。branch 命名 convention のある repo だけ恩恵。同日 exact match 判定は **issue key prefix を無視して `<topic>` 部分のみで match** する (branch 切替後も同 topic を merge 可能)。

## When to use

- default (empty): session 終了 / `/compact` 前 / `/clear` 前の 1 行残し
- `<topic>`: 同 topic 継続作業を 1 file に集約 (auto merge)、初回は new file
- `exit`: next session に restore path を明示的に残したい時

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | `mkdir -p` (helper が自動) |
| Write 失敗 | body を chat 出力、manual save 案内 |
| Helper script 不在 | inline で `~/ai-tools/memory/` write + MEMORY.md 手 prepend (warn 表示) |
| name collision (new file 時) | helper が `-2/-3` suffix |
| 同日 exact match 複数件 | 最古 1 件に merge、他は無視 |

ARGUMENTS: $ARGUMENTS
