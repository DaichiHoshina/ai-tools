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

> **CLAUDE.md compliance**: Serena `.serena/memories/` は read/write 禁止。auto-memory (`~/ai-tools/memory/` + `~/.claude/projects/.../memory/`) のみ使う。

## Usage

```bash
/reload                                          # fallback chain (compact-restore → MEMORY.md → 直近 work-context)
/reload work-context-20260629-foo                # 名指し fast path (~/ai-tools/memory/<name>.md)
/reload foo                                      # prefix match (work-context-*-foo を 1 件)
```

`/memory-save exit` が pbcopy する `/reload <name>` が paste されると名指し経路で確実復元する (個別 file を作る `exit` 経路のみ。`clear` は個別 file を作らないので名指し対象外)。

## Task Execution

Auto-execute the following:

### 1. Load CLAUDE.md

Read `$HOME/.claude/CLAUDE.md` and internalize instructions.

### 2. Restore auto-memory

`$ARGUMENTS` (topic / name) が指定された場合は **`$ARGUMENTS` を最優先で Read** し、未指定時のみ fallback chain に降りる。

```text
If $ARGUMENTS non-empty (名指し fast path):
  1. Read ~/ai-tools/memory/<arg>.md (拡張子なし指定でも .md 補完)
  2. file 不在なら ~/ai-tools/memory/ から prefix match で 1 件 Read
  3. cwd が ai-tools repo 外なら `<repo-root>/memory/**/<arg>.md` も prefix match で探索 (memory file は SoT 適用外、Read OK)
  4. それでも不在なら fallback chain に降りる

Else (fallback chain、上から順に評価、ヒットしたら次 step も並行実行):
  A. compact-restore (post-compact hook が書く一時 file)
     PROJECT_SLUG=$(pwd | sed 's|/|-|g')
     latest=$(ls -t ~/.claude/projects/${PROJECT_SLUG}/memory/compact-restore-*.md 2>/dev/null | head -1)
     [ -n "$latest" ] && Read "$latest" && rm "$latest"  # 累積防止
  B. MEMORY.md (index、`/memory-save clear` が 1 行 entry を prepend する SoT)
     Read ~/ai-tools/memory/MEMORY.md (200 行まで)
     先頭 1-3 行で当日 [clear] entry の <topic> / <summary> / <commit> を確認
  C. 直近 work-context 本文 (index 1 行だけでは復元の濃度不足、本文を必ず Read)
     today=$(date +%Y%m%d)
     today_files=$(ls -t ~/ai-tools/memory/work-context-${today}-*.md 2>/dev/null)
     if [ -n "$today_files" ]; then
       Read 全件 (今日分は全部 Read)
     else
       # 今日無ければ直近 3 日まで遡って最新 1 件
       recent=$(ls -t ~/ai-tools/memory/work-context-*.md 2>/dev/null | head -1)
       [ -n "$recent" ] && Read "$recent"
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

`$ARGUMENTS` 経路は `/memory-save exit` が pbcopy した `/reload <name>` を確実に拾うための fast path。

### 3. Load Project CLAUDE.md

cwd に `CLAUDE.md` / `.claude/rules/` があれば Read。無ければ skip した旨を 1 行明示する (user 側の判定 cost 削減)。

### 4. Restore Summary

Report summary to chat (4 block 固定):

- **Loaded**: Read した memory file の list (compact-restore / MEMORY.md / work-context / pending-improvements)
- **直近 state**: 最新 work-context の task / progress / next-action を 3 行で要約
- **未消化 item**: pending-improvements.md から「進行中 / 保留」item を抜粋 (該当なければ「なし」)
- **Next action**: user 指示待ち、または直近 work-context の next-action をそのまま提示

## "Continue" Alternative

Use `/reload` instead of "continue":
- Prevents post-compaction context loss
- Full restore from auto-memory + 直近 work-context 本文
- Immediate resume of interrupted work

ARGUMENTS: $ARGUMENTS
