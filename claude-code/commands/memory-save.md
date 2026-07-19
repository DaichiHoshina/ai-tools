---
allowed-tools: Write, Read, Bash
description: Quick auto-memory save — default = clear、<topic> で merge/new auto 判定、exit で恒久ナレッジ化
argument-hint: "[<topic> | exit]"
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state in 1 command。**default (no arg) = clear**、MEMORY.md 1 行 index prepend + 個別 file に凝縮本文 write の 2 段構成で `/reload <topic>` 復元を担保する。CLAUDE.md 規約 (Serena `.serena/memories/` と `~/.claude/projects/.../memory/` への write 禁止) に従う。clear でも個別 file を必ず書く (MEMORY.md 1 行だけでは次 session 復元時に scope 再質問を誘発するため)。肥大化は `/memory-clean` で別途対処する。

> **Helper script 必須**: dest 解決 / name 解決 / MEMORY.md 更新は `scripts/memory-save-helper.sh` 経由 (AI の Write/Edit ばらつき排除)。本体 body の Write のみ AI 側担当。bash heredoc での write は jp-quality / public-repo-guard の Write 検査を素通りするため禁止。

## Mode 判定 (arg → mode)

| `$ARGUMENTS` | Mode | 動作 |
|---|---|---|
| (empty) | **clear (default)** | topic は AI 決定、凝縮 body (30 行前後) で save |
| `<topic>` (単語) | **auto merge / new** | 同日同 topic file あれば最古に auto merge (質問なし)、無ければ new file |
| `exit` | **exit (task 終了)** | clear の全処理 + 恒久ナレッジ抽出 (`exit post-processing` 節) |

`<topic>` は kebab-case (空白不可)。legacy arg `clear` は default と同義。

## Flow (全 mode 共通 3 call: prepare → Write → finalize)

1. **prepare**: session の `<topic>` (kebab-case) と 1 行 `<summary>` を決める。決めたら `bash ~/.claude/scripts/memory-save-helper.sh prepare <topic>` を 1 回呼ぶ。出力 (`key=value` 行) が保存に要る全 metadata:
   - `dir` = save 先。org 配下 repo は org 作業 memory、それ以外は `~/ai-tools/memory/` を helper が自動判定する。出力をそのまま採用し根拠 1 行を chat に出す (質問しない)。project 階層 CLAUDE.md が auto-memory dir を宣言する場合のみ override する。その場合 `MEMORY_SAVE_DIR=<宣言 path>` を prepare / finalize 両方の呼び出しに前置する。例外: `$ARGUMENTS` が空 + 宣言が競合して dest を絞れない時だけ AskUserQuestion 1 問 (ai-tools / project の 2 択)
   - `merge_target` 非空 = 同日同 topic の最古 file (issue key prefix 無視で match、複数 hit は最古 1 件)。空なら `new_name` を使う (branch 由来の issue key prefix と collision `-2/-3` suffix は解決済)
   - `worktree` / `branch` 非空 = cwd が linked worktree。frontmatter に転記する
2. **body 生成 + Write**: File format 節の形式で生成する。`merge_target` があれば Read して差分追記で上書きし、無ければ `<dir>/<new_name>.md` へ新規 Write する。clear / exit の凝縮 body は 30 行前後で書く
   - `## task` = session でやったこと (1-3 行)。`## progress` = 直近 state・commit・残決定 (3-8 行)。`## next-action` = 再開手順と user への未回答の質問 (2-5 行)
3. **finalize**: clear / exit は `bash ... finalize clear <topic> <summary> [commit]` (MEMORY.md 先頭に `[clear]` 行 prepend)。`<topic>` mode は `bash ... finalize topic <name> <topic> <description> [hook]` (index prepend + dedup)。どちらも helper が `/reload <topic>` の pbcopy まで実行する
4. **Report**: 「memory 保存済 (index + `<saved-path>`)。`/reload <topic>` を clipboard にコピーした。`/clear` 可」を 1-2 行 chat (systemMessage 非汚染)

次 session は session-start hook が MEMORY.md を auto-load (200 行まで注入)、明示復元は `/reload <topic>` (fallback chain: `commands/reload.md`)。

## File format

```yaml
---
name: <kebab-case-slug>
description: <one-line summary>
metadata:
  type: project
  worktree: <abs-path>   # optional: prepare の worktree= 非空時のみ転記
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

## `exit` post-processing (恒久ナレッジ化)

task 終了時に呼ぶ。Flow (clear として) を全て実行した後、session の task 情報を恒久ナレッジへ昇格させる。

1. **恒久ナレッジ候補を抽出**: 次 session 以降も有効な知見だけ選ぶ。基準は `references/memory-usage.md` § Recording Targets と同じ: misbehavior 再発防止 / non-obvious success / repo から導出できない制約・決定。進捗・commit hash・一時状態は除外 (work-context 側が持つ)。候補 0 件なら step 2-4 を skip し報告に含める
2. **恒久 file write** (候補 1 件 = 1 file): name は `feedback-<slug>` (挙動修正・作法) / `project-<slug>` (project 制約・決定)、日付 prefix なし。同趣旨の既存 memory があれば merge。body は fact + `**Why:**` + `**How to apply:**` で 10 行以内
   - **Tier B routing (必須)**: write 先は本文を stdin で渡して `bash ~/.claude/scripts/memory-save-helper.sh resolve-permanent-dir` で解決する。social-hit term (canonical: `rules/public-repo-private-data-block.md`) を含めば `references-private/snkr-knowledge/` (Tier B)、含まなければ Tier A。org 作業 memory (git 管理外) が dest なら helper が退避を自動 skip する
3. **MEMORY.md 更新**: Tier A に write した file のみ `bash ... finalize topic <name> <topic> <description> [hook]`。Tier B は index 化しない (auto-load 対象外の raw 保管)
4. **`/promote` 案内**: config 化 (CLAUDE.md / skill / rule / hook) がふさわしい候補は `/promote <memory-file>` を報告に添える。自動実行はしない
5. **Report**: clear の報告に「恒久ナレッジ N 件 (`<file名>...`)」を追記する

## Fallback

| Scenario | Action |
|----------|--------|
| memory dir 不在 | helper が `mkdir -p` |
| Write 失敗 | body を chat 出力、manual save 案内 |
| Helper script 不在 | inline で `~/ai-tools/memory/` write + MEMORY.md 手 prepend (warn 表示) |
| name collision (new file 時) | helper `prepare` が `-2/-3` suffix で解決済 |
| 同日 exact match 複数件 | `merge_target` = 最古 1 件、他は無視 |

ARGUMENTS: $ARGUMENTS
