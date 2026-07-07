---
allowed-tools: Read, Bash
description: Restore context - reload CLAUDE.md + auto-memory after compaction
argument-hint: "[topic]"
effort: low
---

# /reload - Context Restore

Use after compaction (conversation compression) or when saying "continue". Restore context from CLAUDE.md + auto-memory + 直近 work-context 本文。

> **Automation**: `/compact` triggers `post-compact-reload.sh` (PostCompact hook) automatically. Manual `/reload` needed only for non-compact context restore.

> **vs session-start.sh**: session-start runs auto at session start with memory load. `/reload` is **post-compaction re-restore** only.

> **CLAUDE.md compliance**: Serena `.serena/memories/` は read/write 禁止。projects/memory (`~/.claude/projects/.../memory/`) は compact-restore の read + rm のみ許可 (write 禁止)。write は `~/ai-tools/memory/` 固定。

## Usage

```bash
/reload                                          # fallback chain (compact-restore → MEMORY.md → 直近 work-context)
/reload work-context-20260629-foo                # 名指し fast path (~/ai-tools/memory/<name>.md)
/reload foo                                      # prefix match、無ければ MEMORY.md の [clear] foo entry を拾う
```

`/memory-save` (clear / exit 両方) が pbcopy する `/reload <topic>` が paste されると名指し経路で復元する。clear / exit とも個別 file を書くため通常は step 1-3 の Read で復元し、個別 file を持たない旧 clear 保存分のみ MEMORY.md の `[clear] <topic>` entry を直近 state の source として拾う (名指し fast path step 4)。

## Task Execution

Auto-execute the following:

### 1. Load CLAUDE.md

Read `$HOME/.claude/CLAUDE.md` and internalize instructions.

### 2. Restore auto-memory

`$ARGUMENTS` (topic / name) が指定された場合は **`$ARGUMENTS` を最優先で Read** し、未指定時のみ fallback chain に降りる。

```text
If $ARGUMENTS non-empty (名指し fast path):
  # `/memory-save` は clear / exit とも個別 file (`work-context-YYYYMMDD-<topic>.md`) を書く。
  # 個別 file を持たない旧 clear 保存分 (MEMORY.md 1 行 entry のみ) の互換として step 4 の
  # helper fallback を残す。
  1. Read ~/ai-tools/memory/work-context-*-<arg>.md (glob で日付 suffix 吸収、`ls -t | head -1` で最新 1 件)
  2. 上記 hit しなければ ~/ai-tools/memory/<arg>.md (拡張子なし指定でも .md 補完) を Read
  3. まだ不在なら ~/ai-tools/memory/ から prefix match で 1 件 Read。cwd が ai-tools repo 外なら
     `<repo-root>/memory/**/<arg>.md` も prefix match で探索 (memory file は SoT 適用外、Read OK)
  4. **旧 clear (個別 file なし、MEMORY.md 1 行 entry のみ) の互換**:
     clear_line=$(bash ~/.claude/scripts/memory-save-helper.sh find-clear-entry "<arg>")
     [ -n "$clear_line" ] && この 1 行を直近 state の source として採用 (topic / summary / commit)
  5. Step 1-3 で file が取れた場合、または Step 4 で clear_line が取れた場合、
     さらに B/C/E 段 (MEMORY.md 全体 / 直近 work-context 本文 / pending-improvements) も Read で補完
  6. Step 1-4 すべて空振りなら fallback chain に降りる

Else (fallback chain、上から順に評価、ヒットしたら次 step も並行実行):
  A. compact-restore (post-compact hook が書く一時 file)
     PROJECT_SLUG=$(pwd | sed 's|/|-|g')
     latest=$(ls -t ~/.claude/projects/${PROJECT_SLUG}/memory/compact-restore-*.md 2>/dev/null | head -1)
     [ -n "$latest" ] && Read "$latest" && rm "$latest"  # 累積防止
  B. MEMORY.md (index、`/memory-save clear` が 1 行 entry を prepend する SoT)
     Read ~/ai-tools/memory/MEMORY.md (200 行まで)
     先頭 1-3 行で当日 [clear] entry の <topic> / <summary> / <commit> を確認
  C. 直近 work-context 本文 (clear-aware、B 段の日付と source を一致させる)
     # 個別 file を持たない旧 clear entry が MEMORY.md 先頭に並ぶと、work-context file の
     # 最新日付は B 段 (MEMORY.md 先頭 [clear] entry の日付) より古くなる。C 段は B 段と
     # source を一致させ、古い本文を「直近 state」と誤読しないようにする。
     mem_latest=$(head -1 ~/ai-tools/memory/MEMORY.md 2>/dev/null | grep -oE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' | head -1)  # B 段最新 entry の日付
     wc_file=$(ls -t ~/ai-tools/memory/work-context-*.md 2>/dev/null | head -1)
     # wc_date は mem_latest と揃えるため YYYY-MM-DD 形式で保持する (比較を同形式にする)。
     # file 名 glob (work-context-YYYYMMDD-*) で再利用する時だけ ${wc_date//-/} で YYYYMMDD に戻す。
     wc_date=$(basename "$wc_file" 2>/dev/null | grep -oE '20[0-9]{2}[0-9]{2}[0-9]{2}' | sed -E 's/(....)(..)(..)/\1-\2-\3/')
     if [ -n "$wc_file" ] && [ "$wc_date" = "$mem_latest" ]; then
       # work-context 本文が B 段最新 entry と同日 → 本文が直近 state の SoT。同日分を全件 Read
       Read $(ls -t ~/ai-tools/memory/work-context-${wc_date//-/}-*.md)
     else
       # work-context 本文が B 段より古い (それ以降は旧 clear のみで保存された) →
       # 直近 state の主 source は MEMORY.md 先頭の [clear] entry 群 (B 段) とする。
       # 古い work-context 本文は補助 context として 1 件だけ Read し、summary では
       # 「本文は <wc_date> 時点、それ以降の作業は MEMORY.md entry 参照」と日付を明示する。
       [ -n "$wc_file" ] && Read "$wc_file"  # 補助のみ、直近 state の主 source にしない
     fi
  D. cwd が ai-tools repo 外の場合のみ追加 (memory file は SoT 適用外、Read OK)
     repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
     repo_parent=$(dirname "$repo_root")
     repo_base=$(basename "$repo_root")
     today_sub=$(ls -t ${repo_parent}/memory/${repo_base}/work-context-${today}-*.md 2>/dev/null)
     Read 全件、無ければ recent 1 件
  E. pending-improvements (未消化 item を surface)
     Read ~/ai-tools/memory/pending-improvements.md (存在すれば)
```

`$ARGUMENTS` 経路は `/memory-save` (clear / exit) が pbcopy した `/reload <topic>` を拾うための fast path。個別 file があれば直接 Read、無ければ MEMORY.md の `[clear] <topic>` entry を source とする。

### 2.5 Worktree 復帰 (work-context に worktree field がある時のみ)

Step 2 で Read した work-context の frontmatter に `metadata.worktree` があれば実行する (無ければ skip):

1. **dir 存在 + cwd 不一致** → Bash で `cd <worktree>` する (cwd は Bash call 間で永続)。`git branch --show-current` が frontmatter の `branch:` と一致するか確認し、不一致なら切替せず warn を 1 行出す (wt 内 branch 切替禁止 rule と整合)
2. **dir 不在** → 「worktree `<path>` は削除済み (merge / cleanup 済の可能性)」と 1 行報告して cwd を維持する。main 側で `git log --oneline -3` を見て merge 済かを補足する
3. 切替した場合の注意: session の permission scope / Serena active project は起動 dir 基準のまま変わらない。wt 作業を長く続けるなら「wt dir で session を再起動すると permission / Serena も揃う」と 1 行添える

### 3. Load Project CLAUDE.md

cwd に `CLAUDE.md` / `.claude/rules/` があれば Read。無ければ skip した旨を 1 行明示する (user 側の判定 cost 削減)。

### 4. Restore Summary

Report summary to chat (4 block 固定):

- **Loaded**: Read した memory file の list (compact-restore / MEMORY.md / work-context / pending-improvements)
- **直近 state**: MEMORY.md 先頭 [clear] entry (B 段) を主 source に task / progress / next-action を 3 行で要約する。work-context 本文 (C 段) が B 段最新 entry より古い場合は「本文は `<wc_date>` 時点、以降は MEMORY.md entry `<日付>` を参照」と日付乖離を明示し、古い本文を最新扱いしない
- **未消化 item**: pending-improvements.md から「進行中 / 保留」item を抜粋 (該当なければ「なし」)
- **Next action**: user 指示待ち、または直近 state (B 段が新しければ B 段、同日なら work-context) の next-action をそのまま提示
- (step 2.5 で worktree 切替 / 不在検出があった場合のみ) **Worktree**: 切替先 path + branch、または削除済みの旨を 1 行追加

## "Continue" Alternative

Use `/reload` instead of "continue":
- Prevents post-compaction context loss
- Full restore from auto-memory + 直近 work-context 本文
- Immediate resume of interrupted work

ARGUMENTS: $ARGUMENTS
