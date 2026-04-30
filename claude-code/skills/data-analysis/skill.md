---
name: data-analysis
description: データ分析（BigQuery/PostgreSQL/MySQL/SQLite/CSV）。SQL不要
requires-guidelines:
  - common
hooks:
  - event: PreSkillUse
    command: "~/.claude/hooks/pre-skill-use.sh"
---

# data-analysis - データ分析

**目標**: 「6ヶ月以上SQLを1行も書いていない」を実現

## 使用タイミング

- **データ探索時**: 自然言語で質問 → SQL自動生成
- **レポート作成時**: クエリ結果を可視化提案
- **複数DB統合時**: BigQuery + PostgreSQL の JOIN
- **CSV/JSON解析時**: ファイルベース分析

## 対応データソース

| データソース | CLI/接続方法 | 認証 |
|------------|-------------|------|
| BigQuery | `bq` CLI | gcloud auth |
| PostgreSQL | `psql` | 接続文字列/環境変数 |
| MySQL | `mysql` CLI | 接続文字列/my.cnf |
| SQLite | `sqlite3` | ファイルパス |
| CSV/JSON | `python pandas` | ローカルファイル |

## 基本フロー

```
自然言語質問 → データソース特定 → SQL生成 → 実行前確認 → クエリ実行 → 結果整形 → 可視化提案
```

### ステップ例

1. **質問受付**: 「過去30日間の売上トップ10商品を教えて」
2. **SQL自動生成**: 対象テーブル推定 → SELECT/GROUP BY/ORDER BY/LIMIT 組み立て
3. **実行確認**: データソース・推定実行時間・スキャンサイズ・読み取り専用確認 → `[Y/n]`
4. **結果整形**: テーブル表示 + 可視化提案（棒グラフ/円グラフ/トレンドライン）

## セキュリティ

### Critical（絶対禁止）

| 違反 | 対応 |
|------|------|
| 書き込みクエリ（UPDATE/DELETE/DROP） | 実行拒否、`SET TRANSACTION READ ONLY`を強制 |
| 機密データ平文表示（password/クレカ） | マスク処理（`'***masked***'`、`RIGHT(card, 4)`） |
| パスワードを環境変数に直接設定 | 1Password CLI / Secrets Manager を使用 |

### Warning（要確認）

| 状況 | 対応 |
|------|------|
| 全テーブルスキャン | インデックス活用（`WHERE created_at >= '2024-01-01'`） |
| BigQuery大量スキャン | パーティション指定（`WHERE _PARTITIONTIME >= TIMESTAMP(...)`） |

## データソース別コマンド早見表

| DB | 接続 | テーブル確認 |
|----|------|------------|
| BigQuery | `bq ls` | `bq ls project:dataset` |
| PostgreSQL | `psql "postgresql://user:pass@host/db"` | `\dt` |
| MySQL | `mysql -h host -u user -p db` | `SHOW TABLES;` |
| SQLite | `sqlite3 data.db` | `.tables` |
| pandas | `pd.read_csv('data.csv')` | `df.describe()` |

## チェックリスト

### 実行前確認
- [ ] クエリは読み取り専用（SELECT/SHOW のみ）
- [ ] 機密データ（パスワード、クレカ）をマスク
- [ ] BigQuery: パーティション指定（コスト削減）
- [ ] 推定スキャンサイズ・実行時間を確認
- [ ] 接続情報（パスワード）は環境変数から取得

### セキュリティ
- [ ] UPDATE/DELETE/DROP は絶対禁止
- [ ] 本番DBは読み取り専用ユーザーを使用
- [ ] パスワードをログに残さない
- [ ] 実行前に必ずユーザー確認

## 出力形式

```
データソース: {DB種別} ({接続先})
推定スキャン: {サイズ/行数}
推定コスト: {BigQuery の場合}

生成SQL:
{整形されたSQL}

実行しますか? [Y/n]

---

結果:
{テーブル形式}

可視化提案:
  - {グラフ種別1}: {用途}
  - {グラフ種別2}: {用途}
```

## 外部知識ベース

最新のSQL構文・関数確認には context7 を活用:
- BigQuery 公式ドキュメント
- PostgreSQL 公式ドキュメント
- pandas API リファレンス

## 関連スキル

- **context7**: 最新ドキュメント参照
- **security-error-review**: クエリのセキュリティレビュー
- **docs-test-review**: データ分析スクリプトのドキュメント
