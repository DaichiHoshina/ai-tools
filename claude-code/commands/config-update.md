---
name: config-update
description: Workflow for model/version/default config updates across template + memory + references (worktree-isolated, parallel edit)
allowed-tools: Bash, Edit, Read, Write, TaskCreate
---

# /config-update

model ID bump / VERSION bump / default model 切替 / template config 単点変更を worktree 内 並列 Edit で実施するワークフロー。

## 適用条件

以下いずれかに該当する場合に使う。

- model ID 文字列の変更 (例: `claude-opus-4-5` → `claude-opus-4-8`)
- `VERSION` / `SERENA_VERSION` 文字列の bump
- `settings.json` template の default model / channel 切替
- references / memory 内の config literal 一点変更

複数 file を跨ぐ edit も本 command の対象。inline 逐次 Edit は禁止 (cwd-guard hook でブロックされる場合あり)。

## ステップ 1 — 発火前チェック

```bash
# working tree clean 確認
git status

# 編集対象 file を列挙
grep -rn "claude-opus-4-5" claude-code/  # 例: 旧 model ID で grep
```

対象 file を特定してからワークフローに進む。live `~/.claude/` は直接編集禁止 (sync.sh to-local で上書きされる)。

## ステップ 2 — worktree 起動

```
EnterWorktree name=config-update-<topic>
```

- `<topic>` = 変更内容の短縮形 (例: `opus-4-8-bump`, `stable-channel`)
- worktree 内で以降のすべての Edit を実施する

## ステップ 3 — 並列 Edit

**1 message 内に複数 Edit tool_use を並列発火**する (委譲分割義務は subagent 系の rule、parent inline 並列 Edit は時短最大化)。

対象 file の典型パターン:

| file | 用途 |
|------|------|
| `claude-code/config/settings.json` | template canonical (model / channel) |
| `claude-code/CLAUDE.md` | model 記述・version 記述 |
| `claude-code/references/model-selection.md` | model 選択ガイド |
| `claude-code/VERSION` | CLI version 管理 |
| `~/.claude/projects/*/memory/*.md` | memory 内 model literal |

Edit 時の注意:

- `settings.json` root key は template canonical、live 直接編集は wipe される
- `CLAUDE.md` PROTECTED SECTION は触らない
- `VERSION` / `SERENA_VERSION` は `/claude-update-fix` / `/serena-update-fix` 経由のみ

## ステップ 4 — 検証

```bash
# 想定 file 数と変更行の一致確認
git diff --stat

# 派生値 literal チェック
grep -nE '[0-9]+ ?(語|件|個|個所|箇所)' <changed_files>

# 旧 model ID 残留チェック (例)
grep -rn "claude-opus-4-5" claude-code/
```

## ステップ 5 — commit

commit message テンプレ:

```
chore({scope}): {target} を {old} → {new} へ bump する

- 背景: <変更理由>
- 影響範囲: <file 数>
- 適用箇所: <変更 file list>
```

`{scope}` 例: `model`, `version`, `config`, `channel`

commit 前自己確認 (書く前の自己確認 rule):

```bash
git log --since=midnight --pretty=format:'%h %s'
```

## ステップ 6 — post-commit

- live `~/.claude/settings.json` は次回 `sync.sh to-local` で template から自動上書き、明示 sync 不要
- worktree は auto-merge で完了: `ExitWorktree action=keep`
- push する場合: `gh pr create` または `/git-push --pr`

## 失敗モード

| エラー | 原因 | 対処 |
|--------|------|------|
| cwd-guard hook block | worktree 外 path を Edit に指定 | path を worktree 内に修正して再実行 |
| sync.sh template canonical 違反 | live `~/.claude/` を直接編集 | `claude-code/` 側 template を修正 |
| grep で旧 model ID 残留 | Edit 漏れ | 追加 Edit して commit に含める |

## 参考

- `rules/markdown-anchor-sync.md` — heading rename を含む場合の bats / cross-ref 確認手順
- `hooks/pre-tool-use.sh` `_check_worktree_cwd_guard` — cwd-guard 詳細実装
- `references/model-selection.md` — model 選定基準
