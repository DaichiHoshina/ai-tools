---
allowed-tools: Bash, Read, Edit, Grep, Glob, AskUserQuestion
description: memory ナレッジを CLAUDE.md / ai-tools skill / command へ昇格させる半自動 flow
effort: medium
---

# /promote - memory → SoT 昇格

memory file を CLAUDE.md / ai-tools / project rules へ統合し、memory 側を削除する半自動 flow。

詳細振り分け基準・固有名詞辞書: `~/.claude/references-private/memory-promotion-flow.md`

## Input

| Arg | 動作 |
|---|---|
| `<memory_file>` | 単一 file 昇格 |
| `--topic <name>` | 同 topic 複数 file 集約昇格 |
| `--scan` | trigger A/B 該当 candidate のみ scan 提示 (実行しない) |

## Flow (Step 1-6)

### Step 1: 対象 memory + 同 topic candidate scan

```
ls ~/.claude/projects/<project>/memory/
```

- 引数の memory_file Read
- `--topic` 指定時は MEMORY.md から topic prefix で同種 file 列挙
- candidate list を chat 表示

### Step 2: 固有名詞 grep (project / ai-tools 振り分け)

`~/.claude/references-private/memory-promotion-flow.md` §7 辞書を都度 Read (literal heredoc 化禁止、辞書更新で desync 回避)。

```bash
# 辞書 hit check
grep -iE "<dictionary regex from §7>" <memory_file>
```

- 1 単語以上 hit → **project 配置確定** (ai-tools 配置を block)
- 0 hit → 技術 layer 判定で ai-tools / project 振り分け

### Step 3: 昇格先候補提示 + user 承認

AskUserQuestion で振り分け候補 + 統合先 file path 提示:

- 配置先 path
- 既存 SoT との重複箇所 (Read + grep で検出)
- 新規 section / 既存 section 追記 / 完全別 file の判定

承認 / 却下 / 別 path 提案を受ける。

### Step 4: 統合 edit (Read + diff 提示 + Edit)

⚠️ **Critical**: 既存 SoT 上書き risk 回避のため必須。

1. 配置先 file **全文 Read**
2. 統合 diff を user に提示 (どの section に何を追加するか)
3. 承認待ち
4. 承認後 `Edit` で原子的に統合
5. 重複 section は memory 側を優先 / 既存側を優先 / merge を AskUserQuestion で確認

### Step 5: sync.sh 実行 (ai-tools 配置時のみ)

```bash
cd ~/ai-tools/claude-code && ./sync.sh to-local --yes
```

`~/.claude/` 側へ反映 (CLAUDE.md "Editing Rule" 準拠、local 直編集 wipe 対策)。

### Step 6: memory file + MEMORY.md index 削除

- `rm <memory_file>` (user 手動 `! rm ...` 依頼、Bash rm permission 制限あり)
- `MEMORY.md` から該当 1 行 Edit 削除
- 削除完了 chat 報告

## 振り分け block

| 検出 | 動作 |
|---|---|
| 固有名詞 1+ hit で `--scope ai-tools` 指定 | エラー、project 配置に強制 |
| 統合先 file 未存在 | user に新規作成 path 確認 |
| 既存 section と内容重複 100% | skip + memory 削除のみ |

## When to use

- `/scan` で session 開始時の trigger 提示
- 同 topic 3 file 以上検知時 (`~/.claude/references-private/memory-promotion-flow.md` §6 trigger B)
- MEMORY.md 50 行超 (trigger A)
- file 単体 5KB / 150 行超 (trigger D)
- user 明示判断時

## Fallback

| Scenario | Action |
|----------|--------|
| `Bash rm` permission deny | user 手動 `! rm <path>` 依頼 |
| 統合先 file conflict (他 session の編集) | conflict 報告、user 解決待ち |
| sync.sh fail | error 表示、template 側は edit 済のため retry 推奨 |
| 振り分け判断不能 | candidate 提示で AskUserQuestion 委譲 |

## 関連

- `~/.claude/references-private/memory-promotion-flow.md` — 振り分け基準 SoT
- `references/memory-usage.md` — memory 使い分け基礎
- `commands/memory-save.md` — memory 書き込み side
- `~/.claude/CLAUDE.md` "## auto memory" — type 定義
