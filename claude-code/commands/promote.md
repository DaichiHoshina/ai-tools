---
allowed-tools: Bash, Read, Edit, Grep, Glob, AskUserQuestion
argument-hint: "<memory-file> | --topic <name>"
description: Semi-automated flow to promote memory knowledge to CLAUDE.md / ai-tools skill / command
effort: medium
---

# /promote - memory → SoT promotion

Semi-automated flow to integrate memory files into CLAUDE.md / ai-tools / project rules and delete the memory side.

Detailed routing criteria & proper-noun dictionary: `~/.claude/references-private/memory-promotion-flow.md`

> **Fallback**: `references-private` は sync 管理外の machine-local file なので、当該 file が不在の machine では本 command の Step 内記述のみで判定する。

## Input

| Arg | Action |
|---|---|
| `<memory_file>` | promote single file (`/memory-save exit` 産の `feedback-<slug>.md` / `project-<slug>.md` もここに渡す) |
| `--topic <name>` | aggregate-promote multiple files with same topic |

## Flow (Step 1-6)

### Step 1: Target memory + same-topic candidate scan

```
ls ~/ai-tools/memory/
```

- Read the argument memory_file
- With `--topic`: list same-kind files from MEMORY.md by topic prefix
- Show candidate list in chat

### Step 2: Proper-noun grep (project / ai-tools routing)

Read `~/.claude/references-private/memory-promotion-flow.md` §7 dictionary each time (no literal heredoc; avoids desync on dictionary update).

```bash
# dictionary hit check
grep -iE "<dictionary regex from §7>" <memory_file>
```

- 1+ word hit → **project placement confirmed** (ai-tools placement blocked)
- 0 hit → route to ai-tools / project by technology-layer judgment

### Step 3: Show placement candidates + user approval

新規 skill / command / hook を作る placement は lifecycle gate (摩擦 evidence + cap 判定、`references/on-demand-rules/toolchain-lifecycle.md`) を先に通す。

AskUserQuestion with routing candidates + destination file path:

- destination path
- duplicate sections with existing SoT (detect via Read + grep)
- judgment: new section / append to existing section / separate new file

Accept approval / rejection / alternate path proposal.

### Step 4: Integration edit (Read + diff + Edit)

⚠️ **Critical**: Required to avoid overwrite risk on existing SoT.

1. **Full Read** of destination file
2. Show integration diff to user (which section to add what)
3. Wait for approval
4. After approval, atomically integrate with `Edit`
5. For duplicate sections, confirm priority via AskUserQuestion: memory side / existing side / merge

#### Step 4a (optional): CLAUDE.md 系のみ claude-md-improver plugin で監査を挟む

Destination file が CLAUDE.md 系のときのみ `Edit` 適用前に `claude-md-improver` skill を呼ぶ。対象は `~/.claude/CLAUDE.md` / `claude-code/CLAUDE.global.md` / repo 配下 `CLAUDE.md` / `CLAUDE.repo.md` の 4 種類。

- 呼び方: `Skill(claude-md-management:claude-md-improver)` (plugin `claude-md-management@claude-plugins-official` が enabled のとき有効)
- 出力を読み、統合後に消すべき既存 section があれば Step 4 の diff に反映する
- plugin 未 enable / skill 呼び出し失敗時は現行の手動監査 flow に戻し、chat に「plugin `fallback`: 手動監査で継続」と 1 行報告する
- **plugin 委譲しない項目**: Step 2 (proper-noun 辞書判定) / Step 3 (routing 承認) / Step 5 (sync.sh) / Step 6 (memory 削除) は ai-tools 側 SoT で完結する

### Step 5: Run sync.sh (ai-tools placement only)

```bash
cd "$HOME/ghq/github.com/DaichiHoshina/ai-tools/claude-code" && ./sync.sh to-local --yes
```

Apply to `~/.claude/` side (CLAUDE.md "Editing Rule" compliant, local-edit wipe protection).

### Step 6: Delete memory file + MEMORY.md index entry

- `rm <memory_file>` (request user manual `! rm ...`; Bash rm permission restricted)
- `Edit`-delete the relevant 1 line from `MEMORY.md`
- Report deletion complete in chat

## Routing blocks

| Detected | Action |
|---|---|
| 1+ proper-noun hit with `--scope ai-tools` | Error; force project placement |
| Destination file not found | Confirm new-file creation path with user |
| 100% duplicate content with existing section | Skip + delete memory only |

## When to use

- On detecting 3+ files with same topic (`~/.claude/references-private/memory-promotion-flow.md` §6 trigger B)
- MEMORY.md exceeds 50 lines (trigger A)
- Single file exceeds 5KB / 150 lines (trigger D)
- `/memory-save exit` が report に添えた `feedback-<slug>.md` / `project-<slug>.md` (恒久ナレッジ候補) を config 化する時。再現可能な手順 / 全 session 共通 rule ならこの trigger で `<memory_file>` に該当 file を渡す
- User explicit judgment

## Fallback

| Scenario | Action |
|----------|--------|
| `Bash rm` permission deny | Request user manual `! rm <path>` |
| Destination file conflict (edit by another session) | Report conflict, wait for user resolution |
| sync.sh fail | Show error; template side is already edited, retry recommended |
| Routing judgment impossible | Delegate to AskUserQuestion with candidates |

## Related

- `~/.claude/references-private/memory-promotion-flow.md` — routing criteria SoT
- `references/memory-usage.md` — memory usage basics
- `commands/memory-save.md` — memory write side
- `~/.claude/CLAUDE.md` "## auto memory" — type definitions
