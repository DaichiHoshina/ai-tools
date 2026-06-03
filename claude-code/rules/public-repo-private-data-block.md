---
description: ai-tools public repo への社内 product 名 / 社内識別子の書き込みを hard block する
paths: ["**/*"]
---

# Public-repo private-data block

`~/ai-tools/` repo は **public**。社内 product 名 / 社内識別子 (social-hit term) を `~/ai-tools/` 配下に書き込むことを禁止する。

## social-hit term canonical list

**social-hit (block)**: snkrdunk / oripa / @batch_name / @feature_tag / recovery-runbook / pm-consultation-draft

## block 条件

以下の**全て**を満たす場合に block する。

1. tool が Write / Edit / MultiEdit のいずれか
2. `file_path` が `~/ai-tools/` 配下 (`$HOME/ai-tools/` 絶対パス前方一致)
3. content (`new_string` / `file_text` / `edits[].new_string`) に social-hit term が含まれる

## 自己除外 (allowlist)

以下 file は rule 説明文として social-hit term を literal で保持するため判定対象外とする。

- `claude-code/rules/public-repo-private-data-block.md` (本 file)
- `claude-code/CLAUDE.md`
- `claude-code/hooks/pre-tool-use.sh`

## hit 時のユーザーアクション

- `file_path` を `~/.claude/references-private/` 以下に切り替える
- または content から social-hit term を削除 / 匿名化 (例: `<product-name>`) して再実行する

## Why

2026-06-03 commit `8de6a2b` で `docs/reports/analysis-doukouiukoto-pair-20260603.html` に `snkrdunk` / `oripa` / 社内 doc 名を含む状態で public push してしまった (`[[public-repo-social-hit-incident]]`)。事後削除は git history に残るため事前 block で再発防止する。

private 保管先: `~/.claude/references-private/` (sync.sh 管理外、gitignore 済)

## ログ

block 発生時: `~/.claude/logs/social-hit-block.log` に記録 (tool / hit_term / file_path / timestamp)
