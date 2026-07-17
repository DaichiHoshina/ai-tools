---
allowed-tools: Write, Read, Bash
description: Quick auto-memory save — default = clear、<topic> で merge/new auto 判定、exit で恒久ナレッジ化
argument-hint: "[<topic> | exit]"
effort: low
---

# /memory-save - Quick auto-memory save

Save current work state in 1 command。**default (no arg) = clear**、MEMORY.md 1 行 index prepend + 個別 file に凝縮本文 write の 2 段構成で `/reload <topic>` 復元を担保する。CLAUDE.md 規約 (Serena `.serena/memories/` と `~/.claude/projects/.../memory/` への write 禁止) に従う。clear でも個別 file を必ず書く (MEMORY.md 1 行だけでは次 session 復元時に scope 再質問を誘発するため)。肥大化は `/memory-clean` で別途対処する。

## Phase 0: dest 確認 (先頭 step、全 mode 共通)

保存前に dest を確定する。順序は **dest 決定 → 既存 file 確認 → merge/new 判定**。

1. **dest 候補**: (a) `~/ai-tools/memory/` (汎用知見、3 ツール共有 SoT) / (b) org 作業 memory `~/ghq/github.com/<org>/memory/<repo>/` (cwd の repo origin が org 配下 + org memory dir 実在時。helper `resolve-dir` が自動判定、2026-07-16 分離) / (c) project 階層 CLAUDE.md が宣言する auto-memory dir (宣言時のみ)
2. **即決 signal (質問しない)**: helper `resolve-dir` の出力をそのまま採用して根拠 1 行を chat に出す (org 配下なら (b)、それ以外 (a))。project CLAUDE.md 宣言あり + cwd がその project 配下 → (c) を優先。`$ARGUMENTS` が非空 (topic/exit 指定あり) → 上記いずれかで即決 (質問 skip)
3. **質問は例外のみ**: `$ARGUMENTS` が空 (default clear) かつ宣言が競合・cwd 判定不能で dest を 1 つに絞れない時だけ、AskUserQuestion を 1 問 (ai-tools / project の 2 択) 発火する
4. dest 確定後、(b) を選んだ場合は `MEMORY_SAVE_DIR` にその path を export してから以降の helper 呼び出しへ進む。既存 file 確認 (`list-today`) は確定後の dest 配下で行う

## Save target dir

dest 決定の詳細は Phase 0 が canonical。ここでは helper 呼び出しの参照先だけ書く。

- work-context / clear の default dest は `bash ~/.claude/scripts/memory-save-helper.sh resolve-dir` の出力 (org 配下 repo / worktree → `~/ghq/github.com/<org>/memory/<repo>/`、それ以外 → `${HOME}/ai-tools/memory/`)
- 環境変数 `MEMORY_SAVE_DIR` が set されていれば helper 出力より優先する
- helper 実装 canonical: `scripts/memory-save-helper.sh:_resolve_memory_dir` (subcommand `resolve-dir` は薄い wrapper)

**例外 — exit の恒久 file (feedback/project) のみ Tier 判定で分岐**: dest が `~/ai-tools/memory/` (public repo 配下) の場合に限り、本文が project 固有名詞 (social-hit term) を含めば `references-private/snkr-knowledge/` へ振る (Tier B、下記 exit post-processing step 2 参照)。dest が org 作業 memory (git 管理外) なら固有名詞を含んでよく、Tier B 退避は不要 (helper が自動 skip)。

> **Helper script 必須**: MEMORY.md 更新 / collision 回避 / 同日 list 取得は `scripts/memory-save-helper.sh` 経由 (AI の Write/Edit ばらつき排除)。本体 body の Write のみ AI 側担当。

## Mode 判定 (arg → mode)

| `$ARGUMENTS` | Mode | 動作 |
|---|---|---|
| (empty) | **clear (default)** | topic は AI 決定、凝縮 body (30 行前後) で save |
| `<topic>` (単語) | **auto merge / new** | 同日 `work-context-*-<topic>.md` あれば最古 file に merge、無ければ new file |
| `exit` | **exit (task 終了)** | clear の全処理 + 恒久ナレッジ抽出 (`exit post-processing` 節) |

どちらの mode も save 後に **saved path + `/reload <topic>` 案内を出力し、`/reload <topic>` を clipboard へコピー**する (復元経路は常に同一)。

`<topic>` は kebab-case で書く (空白は使わない)。legacy arg `clear` は default と同義に吸収、`--preview` は廃止 (body を見たい時は chat で頼む)。

## Flow (auto merge/new mode)

> default (empty arg) は step 1-6 を skip し `clear post-processing` へ。以下は `<topic>` 指定時の flow。

1. **同 topic 同日 file 検出**: `bash ~/.claude/scripts/memory-save-helper.sh find-topic-match <topic>` を呼ぶ (helper が同日 `work-context-YYYYMMDD-*-<topic>.md` を exact suffix match で filter、issue key prefix は無視)。hit 1+ 件 → 最古 file に auto merge (質問なし)、0 件 → new file
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

## `exit` post-processing (恒久ナレッジ化)

task 終了時に呼ぶ。`clear` post-processing (step 1-6) を全て実行した後、session の task 情報を恒久ナレッジへ昇格させる。

1. **恒久ナレッジ候補を抽出**: session を振り返り、次 session 以降も有効な知見だけ選ぶ。基準は `references/memory-usage.md` § Recording Targets (Compounding Engineering) と同じ:
   - misbehavior 再発防止 (同 path error / 想定外の挙動と回避手順)
   - non-obvious success (試行錯誤で当てた非標準 approach)
   - repo / code から導出できない制約・決定とその理由
   - 除外: 進捗 / commit hash / 一時的な作業状態 (work-context 側が持つ)。候補 0 件なら本節 step 2-4 を skip し、その旨を報告に含める
2. **恒久 file write** (候補 1 件 = 1 file): name は `feedback-<slug>` (挙動修正・作法) / `project-<slug>` (project 制約・決定) で日付 prefix なし。同名・同趣旨の既存 memory があれば new file にせず既存へ merge する。frontmatter `type: feedback | project`、body は fact + `**Why:**` + `**How to apply:**` の 3 点で 10 行以内
   - **Tier B routing (必須)**: write 先 dir は `printf '%s' "<body>" | bash ~/.claude/scripts/memory-save-helper.sh resolve-permanent-dir` で解決する。social-hit term (snkrdunk 等、canonical: `rules/public-repo-private-data-block.md`) を本文が含めば `references-private/snkr-knowledge/` (Tier B、auto-load しない private 保管) へ、含まなければ `~/ai-tools/memory/` (Tier A) へ書く。判定根拠: project 固有名詞を含む知見を public repo 共有の index に載せない (2026-07-09 memory 集約の Tier 設計)
3. **MEMORY.md 更新**: Tier A に write した file のみ `bash ... update-index <name> <description> <hook>`。Tier B (private 保管) は index 化しない (auto-load 対象外の raw 保管のため)
4. **`/promote` 案内**: 候補のうち config 化 (CLAUDE.md / skill / rule / hook) がふさわしいもの (再現可能な手順 / 全 session 共通 rule) は `/promote <memory-file>` command を報告に添える。自動実行はしない (SoT 編集は user 承認 flow が必要)
5. **Report**: clear の報告 1 行に「恒久ナレッジ N 件 (`<file名>...`)」を追記する

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
