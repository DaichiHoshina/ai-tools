---
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion
description: ローカル動作確認→スクショ撮影→PRコメント投稿
---

# /test-local - ローカル動作確認 & PR添付

変更をローカルで確認し、テスト結果とスクショをPRに添付する。

## Step 1: PR確認

```bash
gh pr view --json number,title,url
```

PRがなければ作成を提案してから続行。

## Step 2: lint-test実行（`--with-test` 指定時のみ）

引数に `--with-test` がある場合のみ `/lint-test` を実行し結果を記録。省略時はスキップ。

## Step 2.5: テストデータ確認・作成

スクショ前にページが意味ある状態か確認。AskUserQuestionで:
- 「テストデータは必要ですか？（自動作成 / 手動で用意済み / スキップ）」

自動作成を選んだ場合、プロジェクトのseed/fixture方法を検出して実行:

| 検出条件 | 実行コマンド |
|---------|-------------|
| `db/seeds.rb` or `seeds/` | `rails db:seed` or `bundle exec rails db:seed` |
| `prisma/seed.ts` | `npx prisma db seed` |
| `scripts/seed.*` | そのスクリプトを実行 |
| `Makefile` に `seed` target | `make seed` |
| 上記なし | AskUserQuestion「seedコマンドを教えてください」 |

seed実行後、指定URLにアクセスしてデータが表示されているか確認してからスクショへ進む。

## Step 3: スクショ撮影（Playwright）

AskUserQuestionで確認:
- 「スクショを撮るURLを教えてください（例: http://localhost:3000/items）」

```bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCREENSHOT=/tmp/test-local-${TIMESTAMP}.png
URL="<入力されたURL>"

# Playwright CLIでスクショ撮影
npx playwright screenshot "${URL}" "${SCREENSHOT}" --full-page

# クリップボードにコピー（macOS）
osascript -e "set the clipboard to (read (POSIX file \"${SCREENSHOT}\") as JPEG picture)"
```

Playwrightが未インストールの場合:
```bash
npm install -D @playwright/test && npx playwright install chromium
```

`--fullscreen` 指定時は `--full-page` を付与（デフォルト）。
`--viewport WxH` でビューポート指定（例: `--viewport 375x812` でモバイル）。

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
| (なし) | URL指定→Playwrightスクショ→PRコメント |
| `--with-test` | lint-test も実行してから添付 |
| `--no-screenshot` | スクショスキップ |
| `--viewport 375x812` | モバイルサイズでスクショ |

## 注意

- スクショのGitHub自動アップロードは非対応（CLI制限）
- `gh pr view --web` で開いてペーストが最速
- `ARGUMENTS` にPR番号指定で特定PRに添付: `gh pr comment {番号}`

ARGUMENTS: $ARGUMENTS
