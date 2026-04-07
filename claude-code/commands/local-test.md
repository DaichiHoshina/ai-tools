---
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
description: ローカル動作確認→スクショ撮影→PRコメント投稿
---

# /local-test - ローカル動作確認 & PR添付

変更をローカルで確認し、テスト結果とスクショをPRに添付する。

## Step 1: PR確認

```bash
gh pr view --json number,title,url
```

PRがなければ作成を提案してから続行。

## Step 2: lint-test実行

`/lint-test` を実行し、結果を変数に保持。

## Step 3: スクショ撮影

AskUserQuestionで確認（省略可）:
- 「スクショを撮りますか？（画面全体 / 選択範囲 / スキップ）」

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCREENSHOT=/tmp/local-test-${TIMESTAMP}.png

# 選択範囲（デフォルト）
screencapture -i "${SCREENSHOT}"
# 全画面の場合
# screencapture "${SCREENSHOT}"

# クリップボードにもコピー
osascript -e "set the clipboard to (read (POSIX file \"${SCREENSHOT}\") as JPEG picture)"
```

## Step 4: PRコメント投稿

テスト結果をテキストでPRコメントに投稿:

```bash
gh pr comment --body "$(cat <<'BODY'
## ローカル動作確認 ✅

### テスト結果
\`\`\`
{lint-test の出力}
\`\`\`

### スクショ
<!-- クリップボードからペースト、またはファイルをドラッグ＆ドロップ -->
BODY
)"
```

## Step 5: スクショ添付案内

スクショを撮った場合、以下を案内:

```
📸 スクショ保存先: /tmp/local-test-{timestamp}.png
📋 クリップボードにもコピー済み

→ gh pr view --web でPRを開き、コメントにペーストしてください
```

自動でブラウザを開く:
```bash
gh pr view --web
```

## オプション

| 引数 | 動作 |
|------|------|
| (なし) | lint-test → 選択スクショ → PRコメント |
| `--no-screenshot` | スクショスキップ、テキスト結果のみ |
| `--fullscreen` | 全画面スクショ |
| `--skip-test` | テストスキップ、スクショのみ |

## 注意

- スクショのGitHub自動アップロードは非対応（CLI制限）
- `gh pr view --web` で開いてペーストが最速
- `ARGUMENTS` にPR番号指定で特定PRに添付: `gh pr comment {番号}`

ARGUMENTS: $ARGUMENTS
