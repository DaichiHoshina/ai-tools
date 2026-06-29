---
description: Hard-block internal product names / identifiers from being written to the ai-tools public repo
paths: ["**/*"]
---

# Public-repo private-data block

`~/ai-tools/` repo は **public**。社内 product 名 / 社内識別子 (social-hit term) を `~/ai-tools/` 配下に書き込むことを禁止する。

## social-hit term canonical list

**social-hit (block)**: snkrdunk / @batch_name / @feature_tag / recovery-runbook / pm-consultation-draft

## 個人名 / 会社名 / project 固有名詞 (block 全般)

ai-tools repo は public のため、**個人名 / 会社名 / project 固有名詞 (codename / 社内 service 名 / 社内 tool 名)** を ai-tools 配下 file と commit message に書き込み禁止する。

### canonical list (動的読込)

- path: `~/.claude/references-private/private-name-list.txt`
- 1 行 1 term、`#` で始まる行は comment
- user が記入、AI は読込のみで edit 不可
- file 不在 / 空の場合は static list (social-hit のみ) を fallback として使用

### AI 側 default rule (list 不在時の fallback)

list に literal match しない場合でも、AI は以下カテゴリの語を ai-tools 配下 file・commit message に出力しない:

- **個人名**: フルネーム / 姓 / 名 / handle / nickname (本人 `daichi` / `DaichiHoshina` / `Daichi Hoshina` は allowlist で例外)
- **会社名**: 現勤務先 / 過去勤務先 / 関連会社 / 取引先名
- **project / product 固有名詞**: codename / 社内 service 名 / 社内 tool 名 / 社内 doc 名

匿名化形式: `<person-name>` / `<company-name>` / `<project-name>` / `<service-name>` を使う。

### allowlist (例外、block しない)

- `daichi` / `DaichiHoshina` / `Daichi Hoshina` (本人)
- `Anthropic` / `Claude` (tool 名 + 提供元)
- OSS / public product 名 (`go` / `python` / `serena` / `claude-code` 等の一般技術固有名詞)

## block 条件

### Write / Edit / MultiEdit (ai-tools 配下 file 書込)

以下の**全て**を満たす場合に block する。

1. tool が Write / Edit / MultiEdit のいずれか
2. `file_path` が `~/ai-tools/` 配下 (`$HOME/ai-tools/` 絶対パス前方一致)
3. content (`new_string` / `file_text` / `edits[].new_string`) に social-hit term または `private-name-list.txt` 内 term が含まれる

### Bash (git commit / gh / glab、commit message + PR / Issue body)

以下を満たす場合に block する。

1. tool が Bash
2. command が `git commit` / `gh pr create` / `gh pr edit` / `gh issue create` / `gh issue comment` / `glab` 系のいずれか
3. command 内 (`-m` 引数 / heredoc / `--body` 引数) に social-hit term または `private-name-list.txt` 内 term が含まれる
4. allowlist (本人名 / Anthropic / OSS 名) は除外

## 自己除外 (allowlist)

以下 file は rule 説明文として social-hit term を literal で保持するため判定対象外とする。

- `claude-code/rules/public-repo-private-data-block.md` (本 file)
- `claude-code/CLAUDE.md`
- `claude-code/hooks/pre-tool-use.sh`

## hit 時のユーザーアクション

- `file_path` を `~/.claude/references-private/` 以下に切り替える
- または content から social-hit term を削除 / 匿名化 (例: `<product-name>`) して再実行する

## Why

過去に社内 product 名・社内 doc 名を含む file を public push した (`[[public-repo-social-hit-incident]]`)。事後削除は git history に残るため事前 block で再発防止する。private 保管先は `~/.claude/references-private/` (sync.sh 管理外、gitignore 済)。block 発生時は `~/.claude/logs/social-hit-block.log` に記録する。

## NG-DICTIONARY.md canonical key 変更禁止

`guidelines/writing/NG-DICTIONARY.md` の既存 key を rename / 削除すると、`hooks/pre-tool-use.sh` の exact match 参照が壊れる。

### 保護対象 key (rename 禁止)

- `AI定型語` (block)
- `カタカナ造語禁止` (block)
- `断定語 (warn-only)` (warn-only)

### canonical format

```
**<name> (block|warn-only)**: <terms>
```

key 名は hook が literal で grep するため、`AI定型語` を `AI 定型語` (空白挿入) や `AI-template` (英訳) に変えると block が機能しなくなる。

### 既存 key 削減 / category 追加が必要な case

- 既存 key 削減: hook 側 (`pre-tool-use.sh`) の grep pattern を同時に削除
- 新 category 追加: hook 側に新 key の grep pattern を追加 + bats test 追記
- いずれも CLAUDE.md `## Compounding Engineering` の「sync-canonical-with-bats」rule に従う
