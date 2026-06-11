---
allowed-tools: Read, Bash
description: Restore context - reload CLAUDE.md + auto-memory after compaction
effort: low
---

# /reload - Context Restore

Use after compaction (conversation compression) or when saying "continue". Restore context from CLAUDE.md + Claude Code auto-memory.

> **Automation**: `/compact` 実行で `post-compact-reload.sh` (PostCompact hook) が自動 trigger するため、手動 `/reload` は compact 以外の context 復元時のみ必要。

> **vs session-start.sh**: session-start runs auto at session start with memory load. `/reload` is **post-compaction re-restore** only.

> **CLAUDE.md 規約準拠**: Serena `.serena/memories/` は read/write 禁止。auto-memory (`~/.claude/projects/.../memory/`) のみ使用。

## Usage

```bash
/reload
```

## Task Execution

以下を **自動実行**:

### 1. Load CLAUDE.md

`Read` で `$HOME/.claude/CLAUDE.md` を読み込み、指示を理解する。

### 2. Restore auto-memory

```text
1. ls ~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/compact-restore-*.md
   → 最新 mtime 1 件を Read (top priority)
2. 当日の work-context-*.md があれば追加 Read
3. project 固有 memory (style_and_conventions.md 等) があれば Read
4. 読込済 compact-restore-* を rm で削除 (蓄積防止)
```

### 3. Load Project CLAUDE.md

cwd に `CLAUDE.md` / `.claude/rules/` あれば Read。

### 4. Restore Summary

復元内容を chat に summary 報告:
- 読込 memory 一覧
- previous task state (from compact-restore)
- 次アクション

## "Continue" Alternative

"continue" の代わりに `/reload` を使う:
- post-compaction context loss 防止
- auto-memory から full restore
- 中断作業の即時再開

ARGUMENTS: $ARGUMENTS
