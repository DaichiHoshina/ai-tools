# writing/ — チーム外向け文章ガイドライン

PR・Issue コメント・Slack・Notion・DesignDoc 等、**他者が読む文章** を書くときの汎用原則。

プロジェクト固有のテンプレ・宛先・添字規約は各プロジェクトの `CLAUDE.md` に残し、本ディレクトリは横断的な書き方原則のみ扱う。

## ファイル

| ファイル | 用途 | 適用タイミング |
|---|---|---|
| [commit-message.md](commit-message.md) | コミットメッセージ | `git commit` 前 |
| [pr-description.md](pr-description.md) | PR 本文 + レビュー応答 | PR 作成・修正対応時 |
| [external-post.md](external-post.md) | PR コメント / Slack / Issue / Notion 共通 | 外部向け投稿前 |
| [design-doc-protocol.md](design-doc-protocol.md) | DesignDoc 4 Step + 10 パターン | DD 着手・レビュー対応時 |
| [auto-knowledge-update.md](auto-knowledge-update.md) | 指摘・指示の自動追記ワークフロー | セッション中の気づき検出時 |

## 共通原則

- **箇条書きファースト**: 散文を避け、scan できる構造に
- **構造（場所）で束ねる**: ファイル / モジュール / レイヤー単位。抽象観点 (what/why/how) で section を割らない
- **section 重複を排除**: 同じ事実は 1 ヶ所のみ
- **長さは内容に従う**: 自明は数行、設計判断含む変更は原因や代替案も
- **AI 臭の禁止**: 「Generated with X」「AI が生成」等の内部用語、過剰絵文字、定型フッターを残さない

## 関連

- `common/notion-writing.md` — Notion 形式仕様（フォーマット詳細）
- `common/documentation-strategy.md` — ドキュメント戦略
- `common/team-development-workflow.md` — チーム開発フロー
