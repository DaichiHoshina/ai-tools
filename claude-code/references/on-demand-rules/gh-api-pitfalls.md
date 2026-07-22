# gh api / PR コメント収集の罠

`gh api` `gh pr` の bulk 出力を jq / awk で集計する時、および PR review コメントを report 化する時に読む。

## 1. PR review コメント集約 report は default で bot 全除外

PR に付くレビューコメントを集約する report を作る時、coderabbitai / Copilot / Copilot pull-request-reviewer 系 bot のコメントは実質的な指摘ではなく walkthrough / tips / commit summary の自動テンプレで、1 コメント 数千字 x 数十件のスケール。datadog / github-actions bot は自動 status 通知。人間 reviewer からのコメントに絞ると信号比が桁違いに上がる。

**Why**: 2026-07-21 snkr.com の自分 PR 76 件集約で、bot 込み 389 件のうち coderabbitai 125 / Copilot 30 / datadog 46 / github-actions 24 = 計 225 件 (58%) が bot 定型。user 選択で「人間のみ」に絞ると doc 容量 5 分の 1、信号密度が急上昇した。

**How to apply**:
- PR コメント収集 script は default `select(.author | test("bot|Copilot") | not)` で bot 除外
- 依頼「PR レビューコメント全部」は「人間 reviewer からの実質コメント」と解釈が妥当。全 bot 含めるかは 1 問だけ確認する
- bot コメントを保持する場合も HTML コメントと `<details>` 塊は削除して body 短縮する

## 2. gh api paginate の出力を jq に shell substitution で渡すと control char parse error

`gh api ... --paginate | jq -c '...'` や `$(gh api ... | jq -c '...')` の command substitution 経路は、body に literal 改行 / CR が入ると jq が「Invalid string: control characters」で parse error を出す。shell が改行を空白畳みで受け渡すため。

**Why**: 2026-07-21 snkr.com PR コメント収集で、76 件中 1 件 (#35387) が同 pattern で fail。iss.json を file に redirect した状態でも `iss=$(jq -c '...' /tmp/iss.json)` で同 error になった。command substitution が output の control char を保持できない。

**How to apply**:
- 大量 API 出力を jq に食わせる時は必ず file redirect + file 入力: `gh api ... > /tmp/x.json && jq -c '...' /tmp/x.json > /tmp/x-clean.json`
- 次段 jq に渡す時は `--argjson` (shell 経由) ではなく `--slurpfile var /tmp/x-clean.json` を使う。`--slurpfile` は array-wrap するので `$var[0]` で取り出す
- `gh api --paginate` の複数ページ出力は bare JSON array 連結 (`[...][...]`) になり単一 jq に食わせると parse error。`--slurp` or `jq -s` で受ける

## 関連

- `guidelines/writing/gh-issue.md` — issue 書き方
- `references/on-demand-rules/bash-tool-environment.md` — Bash tool 環境の制約
