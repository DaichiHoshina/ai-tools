---
paths:
  - "**/*.md"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.py"
---
# AI 出力ルール (強制)

短い禁止リストのみ。詳細は `guidelines/writing/` を参照。

## PR・コミット禁止事項

- 「Generated with Claude Code」等の AI フッター
- 変数名・ファイル名の羅列 (diff で読める)
- テーブル形式のファイル一覧 (diff と重複)
- 「この PR では以下を変更しました」型の冗長な前置き

詳細: `guidelines/writing/commit-message.md` / `pr-description.md`

## 短文投稿 (issue/ticket/コメント)

PREP 3 点 (結論 / 理由 / 次アクション)、本文 400 字前後 / title 80 字前後。

詳細: `guidelines/writing/external-post.md` / 共通原則: `guidelines/writing/PRINCIPLES.md`

長文 (Notion / DD / PRD / RCA) は `guidelines/writing/long-form-doc.md` 側。

## コード内コメント

AI 生成を示すコメント禁止 (`// AI-generated`、`// TODO: AI が提案` 等)。
