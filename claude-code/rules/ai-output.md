---
paths:
  - "**/*.md"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.py"
---
# AI出力ルール

## PR・コミットでの禁止事項
- 「Generated with Claude Code」等のAIツールフッター禁止
- 変数名・ファイル名の羅列禁止（レビュワーはdiffで見る）
- テーブル形式のファイル一覧禁止（diffと重複）
- 「このPRでは以下を変更しました」的な冗長な前置き禁止

## issue/ticket/コメント投稿の禁止事項

> 長文ドキュメント（Notion/Design Doc/PRD/RCA レポート）は `~/.claude/guidelines/common/user-voice.md` の 4問+5原則に従う。本セクションは短文 comment / ticket / Slack 通知向け。

PR/issue/Slack の本文は読み手が **数十秒で判断/実行に進める** 必要があり、長文ドキュメントの 4問+5原則は重く誤適用されやすい。そのため短文専用の PREP 3点ルールを別建てる。

### 対象
GitHub の issue/PR の本体作成・コメント全般（`gh issue create`/`gh issue comment`/`gh pr create` description（短文の場合）/`gh pr comment`/`gh pr review`）、Jira ticket（`mcp__jira__jira_post`）、Notion ページ（`mcp__claude_ai_Notion__notion-*`）、Slack 通知、Linear 等。
- 例外: Design Doc 級の長文 PR description は user-voice.md 側の 4問+5原則を使う。
- スコープ外（初版）: Datadog notebook、Backstage、社内 Wiki — 必要なら次版で追加。

### 構造（PREP 3点）
1. **結論**: 読み手に何を判断/実行させるか（1行）
2. **理由**: 現象 / 影響 / (分かれば) 原因
3. **次アクション**: 担当 / 期限 / 不明点

詳細ログ・スタックトレース・調査過程は `<details>` 折りたたみ、または別ファイルリンクへ。

### 文量目安（媒体差あり、絶対値ではない）
- 本文: 400 字前後（30 秒で読める量、音読 600 字/分換算）。Slack スレッドはより短く、Notion 議事録は適宜長く可
- title / summary: 80 字前後（GitHub UI 一覧で 70 字付近から省略されるため）
- 超過時は H3 見出し or 箇条書きで構造化（読み手が見出しスキャンで判断できるため）

### 禁止
- 調査ログ・思考過程のダンプ（「まず○○を調べて、次に△△を確認し…」型）
- 冗長な前置き（「このissueでは以下のように〜」「結論から言うと〜」）
- 同じ情報の言い換え反復
- 評価語（適切/重要/必須）を根拠 1 文なしで列挙
- リポジトリの diff/PR で読める情報の再掲（変数名一覧・変更ファイル列挙など）

### 投稿前 self-check（4問、目視可能）
1. 最初の 1 行で「読み手に何を判断/実行させるか」が言えているか（PREP の結論先出し）
2. H3 見出しが 3 個以上 or スクロール 1 画面超え なら長すぎる兆候
3. 結論 / 理由 / 次アクション のどれかが欠けていないか
4. 評価語に根拠 1 文を添えたか

## コード内コメント
- AIが生成したことを示すコメント禁止（`// AI-generated`等）
- 「TODO: AIが提案」系のコメント禁止
