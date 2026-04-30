---
paths:
  - "**/*.sql"
  - "**/*migration*"
  - "**/*repository*"
  - "**/*repo*"
---
# データベース操作ルール

## 安全原則

- **全環境（dev/test/prd）読み取り専用**がデフォルト。許可なしの書き込み禁止
- 書き込み必要なら事前にユーザー確認
- migration は単独 PR でリリース（他変更と混ぜない）
- 他コンテキスト/サービスのDBテーブル直接参照しない

## 本番DB参照（Claude Code運用）

| 項目 | ルール |
|------|--------|
| 接続先 | reader のみ（`reader.db.prod.*.internal` 等）、writer禁止 |
| 認証 | ユーザー自身の AWS SSO + 踏み台コマンド（例: `make aws-start-session-prod`） |
| クエリ | SELECT のみ、`LIMIT` 必須（目安100行）、全件スキャン禁止 |
| 書き込み | UPDATE/DELETE/INSERT/DDL 絶対禁止 |
| 秘匿情報 | メアド・電話・住所・決済情報を会話に残さない、`id, created_at` でマスク取得 |
| ログ | Session Manager 全記録（監査対象） |

**フロー**: ユーザー目的伝達 → Claude が SELECT 提案 → ユーザーが踏み台で実行 → 結果要点のみ Claude 共有（生データ全量渡さない）

**非推奨**: Claude に踏み台セッション丸投げ / 個人情報含むテーブルそのまま貼付 / 探索的 `SELECT *` 繰返し
