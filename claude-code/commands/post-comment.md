---
description: issue/PR/Jira/Notion/Slack への短文投稿を PREP 3点で draft → self-check → 表示。投稿は確認後。
allowed-tools: Bash, Read, Write
---

# /post-comment - 短文投稿 draft + self-check

`rules/ai-output.md`「issue/ticket/コメント投稿の禁止事項」の PREP 3点ルールに従って draft を生成し、self-check 4問を通してから投稿候補として表示。**投稿は本コマンドでは実行しない**（ユーザが gh / mcp で実行）。

## 引数

```
/post-comment [target] [topic or context]
```

| target | 説明 |
|--------|------|
| `gh-issue` | GitHub issue 本体作成（title + body） |
| `gh-issue-comment` | GitHub issue へのコメント |
| `gh-pr` | GitHub PR 本体作成（title + body） |
| `gh-pr-comment` | GitHub PR へのコメント |
| `gh-pr-review` | GitHub PR review コメント |
| `jira` | Jira ticket 起票（summary + description） |
| `notion` | Notion ページ（短文の議事録/通知） |
| `slack` | Slack 通知 |

target 省略時はユーザに確認。

## フロー

### Step 1: draft 生成（PREP 3点）

```markdown
## 結論
<読み手に何を判断/実行させるか、1行>

## 理由
<現象 / 影響 / (分かれば) 原因>

## 次アクション
<担当 / 期限 / 不明点>
```

`gh-issue` / `gh-pr` / `jira` の場合は title / summary（80字以内）を別途生成。
詳細ログ・スタックトレースは `<details>` 折りたたみ。

### Step 2: self-check 4問（必須通過）

| # | 項目 | 判定 |
|---|------|------|
| 1 | 最初の1行で「読み手に何を判断/実行させるか」が言えているか | ✓/✗ |
| 2 | H3 が3個以上 or スクロール1画面（80行）超え | ✓/✗ |
| 3 | 結論 / 理由 / 次アクション のどれかが欠けていないか | ✓/✗ |
| 4 | 評価語（適切/重要/必須）に根拠 1 文添えたか | ✓/✗ |

**4問全 ✓ で次へ**。1問でも ✗ なら draft 修正してリトライ（最大2回）。

### Step 3: 投稿候補として表示

```
## 📝 投稿候補（target: gh-pr-comment）

### Title / Summary
<生成された title or 「N/A（コメントのみ）」>

### Body（XXX字）
<生成された本文>

### self-check
[1] ✓ 結論先出し
[2] ✓ H3 N個 / 約 XXX字
[3] ✓ 結論/理由/次アクション 揃い
[4] ✓ 評価語の根拠

### 投稿コマンド（コピペ用）
gh issue comment <番号> --body-file /tmp/post-XXXXX.md
# または
mcp__jira__jira_post ...
```

ユーザが投稿コマンドをコピペ実行 or 「投稿して」と指示で AI が実行（投稿実行時は `--dry-run` フラグで確認推奨）。

## オプション

| 引数 | 動作 |
|------|------|
| `--dry-run` | draft + self-check のみ、投稿コマンドは表示しない |
| `--auto-post <id>` | self-check 通過後、指定先に自動投稿（gh issue 番号 / Jira key） |
| `--from-file <path>` | draft の元情報をファイルから読む |

## 失敗時

self-check 2回連続 ✗ → 残違反を表示してユーザに修正方針を確認:

```
⚠️ self-check 違反 2回連続:
- [3] 次アクションが欠けている（純粋情報共有 comment？）
- [2] H3 4個（長すぎる兆候）

選択肢:
a) 「次アクション無し」を許可して投稿（純情報共有）
b) draft をユーザが直接編集
c) 中止
```

## ガード

- 本コマンドでは **投稿コマンドの自動実行はしない**（`--auto-post` 指定時のみ）
- 長文ドキュメント（Design Doc / PRD / Notion ページ級）は `/docs` / `/design-doc` を使う（誤適用防止）
- 投稿先の API 制約は呼ぶ側で判定（GitHub: 65k 字、Slack: 4k 字、Jira description: 32k 字）

## 関連

- ルール本体: `~/.claude/rules/ai-output.md`「issue/ticket/コメント投稿の禁止事項」
- 長文版: `~/.claude/guidelines/common/user-voice.md`
- 既存組み込み: `/git-push --pr`, `/test-local`, `incident-response` skill
