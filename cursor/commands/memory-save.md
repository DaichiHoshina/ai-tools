# /memory-save (Cursor)

現在の session の作業状態を共有 memory へ保存する。保存先の解決 / 命名 / MEMORY.md index 更新は helper script が担い、AI は topic 決定と本文 Write のみ行う。canonical: `~/ai-tools/claude-code/commands/memory-save.md` (本 command はその Cursor 移植版で、exit 恒久ナレッジ化は Claude Code 側のみ)。

引数: command の後に続く語。無し = clear mode (topic は AI が決める)。単語 1 つ = topic mode (kebab-case、同日同 topic file があれば merge)。

## Flow (3 step)

1. **prepare**: session の `<topic>` (kebab-case) と 1 行 `<summary>` を決め、`bash ~/ai-tools/claude-code/scripts/memory-save-helper.sh prepare <topic>` を 1 回実行する。出力の意味:
   - `dir` = 保存先 (org 配下 repo は org 作業 memory、それ以外は `~/ai-tools/memory/` を自動判定)。出力をそのまま採用する
   - `merge_target` 非空 = 同日同 topic の既存 file。空なら `new_name` を新規 file 名に使う
   - `worktree` / `branch` 非空なら frontmatter に転記する
2. **body write**: 下の File format で `<dir>/<new_name>.md` へ新規作成する。`merge_target` があればその file を読み、差分追記で上書きする。本文は凝縮 30 行前後に収める
3. **finalize**: clear mode は `bash ~/ai-tools/claude-code/scripts/memory-save-helper.sh finalize clear <topic> <summary> [commit]`、topic mode は `bash ... finalize topic <name> <topic> <description>` を実行する。実行後「memory 保存: `<保存 path>`。復元は Claude Code の `/reload <topic>`」と 1-2 行で報告する

## File format

```yaml
---
name: <kebab-case-slug>
description: <one-line summary>
metadata:
  type: project
  worktree: <abs-path>   # optional: prepare の worktree= 非空時のみ
  branch: <branch-name>  # optional: worktree と対
---

## task               # 必須: session でやったこと (1-3 行)
## progress           # 必須: 直近 state・commit・残決定 (3-8 行)
## next-action        # 必須: 再開手順と未回答の質問 (2-5 行)
## files              # optional
```

## 制約

- MEMORY.md を直接編集しない (index 更新は helper 経由のみ)
- `.serena/memories/` / `~/.claude/projects/` 配下へは書かない
- helper が使えない場合は本文を chat に出力し、Claude Code 側での保存を案内して終える
