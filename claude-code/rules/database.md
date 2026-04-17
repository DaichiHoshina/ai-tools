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
- 書き込みが必要な場合はユーザーに確認を取ってから実行
- migrationは単独PRでリリース（他の変更と混ぜない）
- 他コンテキスト/サービスのDBテーブルを直接参照しない

## 本番DB参照（Claude Code運用ルール）

本番DBの中身をClaude Codeと確認する場合の安全運用。

| 項目 | ルール |
|------|--------|
| 接続先 | **reader のみ**（例: `reader.db.prod.*.internal`）。writer禁止 |
| 認証 | ユーザー自身がAWS SSOログイン → `make aws-start-session-prod` 等の踏み台コマンド実行 |
| クエリ | SELECTのみ。`LIMIT` 必須（目安100行）。全件スキャン禁止 |
| 書き込み | UPDATE/DELETE/INSERT/DDL 絶対禁止 |
| 秘匿情報 | メアド・電話・住所・決済情報を会話ログに残さない。`id, created_at` 等でマスク取得 |
| ログ | Session Manager全操作記録（監査対象） |

**推奨フロー**:
1. Claudeに目的伝達（「prd readerで〇〇テーブル△△確認したい」）
2. ClaudeがSELECTクエリ提案
3. ユーザー自身が踏み台内で実行
4. 結果要点のみClaudeに共有（生データ全量渡さない）

**非推奨**:
- Claudeに踏み台セッション丸投げで操作させる
- 個人情報含むテーブルをそのまま貼り付ける
- 探索的に `SELECT *` 繰り返す
