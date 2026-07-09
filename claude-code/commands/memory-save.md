---
allowed-tools: Write, Read, Bash
description: Quick auto-memory save — default = clear、<topic> で merge/new auto 判定
argument-hint: "[<topic>]"
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state in 1 command。**default (no arg) = clear** (MEMORY.md 1 行 index prepend + 個別 file に凝縮本文 write の 2 段構成、`/reload <topic>` 復元を担保)。CLAUDE.md 規約 (Serena `.serena/memories/` と `~/.claude/projects/.../memory/` への write 禁止) に従う。clear でも個別 file を必ず書く (MEMORY.md 1 行だけでは次 session 復元時に scope 再質問を誘発するため)。肥大化は `/memory-clean` で別途対処する。

## Save target dir

**常に `${HOME}/ai-tools/memory/` に固定** (cwd 非依存、Claude Code / Codex / Cursor の 3 ツール共有 SoT)。環境変数 `MEMORY_SAVE_DIR` が set されていれば最優先する。canonical: `scripts/memory-save-helper.sh:_resolve_memory_dir`。

> **Helper script 必須**: MEMORY.md 更新 / collision 回避 / 同日 list 取得は `scripts/memory-save-helper.sh` 経由 (AI の Write/Edit ばらつき排除)。本体 body の Write のみ AI 側担当。

## Mode 判定 (arg → mode)

| `$ARGUMENTS` | Mode | 動作 |
|---|---|---|
| (empty) | **clear (default)** | topic は AI 決定、凝縮 body (30 行前後) で save |
| `<topic>` (単語) | **auto merge / new** | 同日 `work-context-*-<topic>.md` あれば最古 file に merge、無ければ new file |

どちらの mode も save 後に **saved path + `/reload <topic>` 案内を出力し、`/reload <topic>` を clipboard へコピー**する (復元経路は常に同一)。

`<topic>` は kebab-case 推奨。空白含む場合は quote (`"reload fix"` → 内部で `-` 変換)。legacy arg `clear` / `exit` は default と同義に吸収、`--preview` は廃止 (body を見たい時は chat で頼む)。

## Flow (auto merge/new mode)

> default (empty arg) は step 1-6 を skip し `clear post-processing` へ。以下は `<topic>` 指定時の flow。

1. **同 topic 同日 file 検出**: `bash ~/.claude/scripts/memory-save-helper.sh list-today` の出力を `work-context-YYYYMMDD-*-<topic>.md` の **exact suffix match** で filter (issue key prefix は無視)。hit 1+ 件 → 最古 file に auto merge (質問なし)、0 件 → new file
2. **Body 生成** (3 必須 + 4 optional、`File format` 節参照)。merge 時は既存 body を Read して差分追記
3. **Name 解決** (new のみ): `bash ... resolve-name work-context-YYYYMMDD-<topic>` (collision 時 `-2/-3` suffix 自動)。名前組み立て前に `bash ... extract-issue-key` を呼び、検出できたら topic 先頭に prefix (`Auto issue key suffix` 節参照)
4. **Write**: `<save-dir>/<name>.md` (merge 時は最古 file を上書き)
5. **MEMORY.md 更新**: `bash ... update-index <name> <description> <hook>` (helper が dedup + prepend)
6. **Report**: `bash ... pbcopy-reload <topic>` を実行し、saved path + merge/new + `/reload <topic>` 案内を 1-2 行 (systemMessage 非汚染)

## File format

```yaml
---
name: <kebab-case-slug>
description: <one-line summary>
metadata:
  type: project
  worktree: <abs-path>   # optional: cwd が linked worktree の時のみ
  branch: <branch-name>  # optional: worktree と対で記録
---

## task               # 必須
## progress           # 必須
## next-action        # 必須
## files              # optional (空なら省略)
## project            # optional
## last 3 messages    # optional
## skill              # optional
```

3 必須のみで完結可、短 session は 10 行台で OK。

**Worktree 判定** (全 mode で body 生成前に実行): `[ -f "$(git rev-parse --show-toplevel 2>/dev/null)/.git" ]` が true なら linked worktree (main repo は `.git` が dir)。true の時のみ frontmatter に `worktree:` / `branch:` を記録する (`/reload` step 2.5 が読んで wt 復帰、canonical: `commands/reload.md`)。

## `clear` post-processing

1. 現 session の `<topic>` (kebab-case) と 1 行 `<summary>` を決定 (最後の commit hash も任意で添える)
2. **凝縮 body 生成**: File format と同じ frontmatter + 3 必須 section、目安 30 行前後。`## task` = session でやったこと (1-3 行) / `## progress` = 直近 state・commit・未消化決定・実データ所在 (3-8 行) / `## next-action` = 再開手順 + user 未回答質問 (2-5 行)
3. **Name 解決 + Write**: auto merge/new flow の step 1 → 3 → 4 を呼ぶ。同日同 topic 既存 file があれば auto merge で肥大化を抑える
4. `bash ~/.claude/scripts/memory-save-helper.sh append-clear-line <topic> <summary> [<commit>]` (MEMORY.md 先頭に `- \`YYYY-MM-DD\` [clear] <topic> — <summary> (commit: <hash>)` を prepend)
5. `bash ~/.claude/scripts/memory-save-helper.sh pbcopy-reload <topic>` (`/reload <topic>` を clipboard へ、pbcopy 不在は silent skip)
6. 「memory 保存済 (index + `<saved-path>`)。`/reload <topic>` を clipboard にコピーした。`/clear` 可」を 1 行 chat

次 session は session-start hook が MEMORY.md を auto-load (200 行まで注入)、明示復元は `/reload <topic>`。fallback chain: `commands/reload.md`。

## Auto issue key suffix

`git branch --show-current` から issue key (`PROJ-123` / `#456` → `456` / `issue-789`) を検出できた時のみ new file の topic 先頭に prefix する (helper `extract-issue-key`)。例: `feature/PROJ-123-add-login` → `work-context-20260701-PROJ-123-<topic>.md`。検出なし (main 直 push 等) は topic のみ。同日 exact match 判定は **prefix を無視して `<topic>` 部分のみで match** (branch 切替後も同 topic に merge 可能)。

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | helper が `mkdir -p` |
| Write 失敗 | body を chat 出力、manual save 案内 |
| Helper script 不在 | inline で `~/ai-tools/memory/` write + MEMORY.md 手 prepend (warn 表示) |
| name collision (new file 時) | helper が `-2/-3` suffix |
| 同日 exact match 複数件 | 最古 1 件に merge、他は無視 |

ARGUMENTS: $ARGUMENTS
