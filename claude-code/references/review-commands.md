# レビューコマンド使い分け

| コマンド | 用途 |
|---------|------|
| `/review` | 日常レビュー（comprehensive-review skill、11観点 + 信頼度80フィルタ） |
| `/review --codex` | セカンドオピニオン（comprehensive + codex plugin 並列、共通指摘を Critical） |
| `/review --adversarial` | codex adversarial-review 委譲（設計判断・トレードオフ・障害モード問い詰め） |
| `/review --plugin <PR>` | 公式 plugin 委譲（5並列Sonnet+信頼度80→PR comment 自動投稿） |
| `/review --deep` | pr-review-toolkit 6 専門agent並列（観点深掘り、コスト大） |
| `/review --multi <PR>` | 4手段並列で false negative 最小化（リリース前用、トークン消費最大） |
| `/ultrareview` | クラウド並列マルチエージェント（**ユーザー明示発動のみ**、別課金） |

詳細仕様: [`commands/review.md`](../commands/review.md)

## 判断基準

| 状況 | 推奨 |
|------|------|
| 小〜中規模（1-3ファイル）日常 | `/review` |
| エラー処理・型設計を厳しく | `/review --deep` |
| 設計判断・アーキテクチャの妥当性 | `/review --adversarial` |
| PR 最終確認・ノイズ少なく | `/review --plugin <PR>` |
| マージ直前・リリース前・セキュリティパッチ | `/review --multi <PR>` |
| 大規模ブランチ全体 | `/ultrareview`（ユーザー指示） |

## 自動レビュー（PR作成時、opt-in）

`/git-push --pr --auto-review` で `code-review:code-review` + `coderabbit:code-review` 並列起動。詳細・失敗時挙動: [`commands/git-push.md`](../commands/git-push.md)
