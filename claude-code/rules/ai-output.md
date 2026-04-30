---
paths:
  - "**/*.md"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.py"
---
# AI出力ルール

## PR・コミット禁止事項

- 「Generated with Claude Code」等のAIフッター
- 変数名・ファイル名の羅列（diffで読める）
- テーブル形式のファイル一覧（diffと重複）
- 「このPRでは以下を変更しました」型の冗長な前置き

## issue/ticket/コメント投稿（短文向け PREP 3点）

> 長文ドキュメント（Notion/Design Doc/PRD/RCA）は `~/.claude/guidelines/common/user-voice.md` の 4問+5原則。本セクションは短文 comment / ticket / Slack 通知向け。

**対象**: GitHub issue/PR 本体・コメント、Jira（`mcp__jira__jira_post`）、Notion（`mcp__claude_ai_Notion__*`）、Slack、Linear（Design Doc 級長文 PR description は user-voice.md 側）

**構造（PREP 3点）**:
1. 結論: 読み手に何を判断/実行させるか（1行）
2. 理由: 現象 / 影響 / 原因
3. 次アクション: 担当 / 期限 / 不明点

詳細ログ・スタックトレース・調査過程は `<details>` 折りたたみ or 別ファイルリンク。

**文量目安**: 本文 400字前後（30秒で読める） / title 80字前後（GitHub UI で70字付近省略） / 超過時は H3 or 箇条書きで構造化

**禁止**: 調査ログダンプ / 冗長な前置き / 同情報の言い換え反復 / 評価語（適切/重要/必須）の根拠なし列挙 / diff/PR で読める情報の再掲

**投稿前 self-check（4問）**: ①1行目で判断/実行内容が言えてるか ②H3 3個以上 or 1画面超なら長すぎ ③結論/理由/次アクションが揃ってるか ④評価語に根拠1文あるか

## コード内コメント

AI生成を示すコメント禁止（`// AI-generated`、`// TODO: AIが提案` 等）
