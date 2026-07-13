---
description: Hard-block internal product names / identifiers from being written to the ai-tools public repo
paths: ["**/*"]
---

# Public-repo private-data block

`~/ai-tools/` repo は **public**。社内 product 名 / 社内識別子 / 個人名 / 会社名 / project 固有名詞を `~/ai-tools/` 配下 file と commit message に書き込むことを禁止する。hook (`hooks/pre-tool-use.sh` + `hooks/lib/public-repo-guard.sh`) が Write / Edit / commit / PR / issue 系で hard block する。

## social-hit term canonical list

**social-hit (block)**: snkrdunk / @batch_name / @feature_tag / recovery-runbook / pm-consultation-draft

動的 list: `~/.claude/references-private/private-name-list.txt` (1 行 1 term、user 記入、AI は read のみ)。file 不在 / 空の場合は上記 static list を fallback とする。

## AI 側 default rule

list に literal match しない場合でも、個人名 / 会社名 / 社内 codename・service 名・doc 名を出力しない。匿名化形式は `<person-name>` / `<company-name>` / `<project-name>` / `<service-name>` を使う。allowlist (block しない): 本人 (`daichi` / `DaichiHoshina` / `Daichi Hoshina`) / `Anthropic` / `Claude` / OSS・public product 名。

## commit / PR draft 時の人名 self-check

commit message / PR body / issue comment の draft 前に固有名詞を点検する (`@<handle>` / 「<姓名>さん」/ Slack display name / 社内 alias)。レビュー指摘を引用するときは handle を伏せて「レビュー指摘」と総称する。Co-Authored-By trailer の AI marker は人物ではないため対象外とする。

## hit 時の対応

`~/.claude/references-private/` へ保存先を切替えるか、term を削除 / 匿名化して再実行する。自己除外 file list と詳細判定 logic は `hooks/lib/public-repo-guard.sh` を参照する。block log: `~/.claude/logs/social-hit-block.log`。incident 経緯: `references/on-demand-rules/public-repo-incident-history.md`。
