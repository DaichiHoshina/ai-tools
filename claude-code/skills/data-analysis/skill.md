---
name: data-analysis
description: データ分析 - SQL不要でBigQuery/PostgreSQL/MySQL/SQLite/CSV分析
requires-guidelines:
  - common
hooks:
  - event: PreSkillUse
    command: "~/.claude/hooks/pre-skill-use.sh"
---

# データ分析スキル

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

```mermaid
graph LR
    A[自然言語質問] --> B[データソース特定]
    B --> C[SQL生成]
    C --> D[実行前確認]
    D --> E[クエリ実行]
    E --> F[結果整形]
    F --> G[可視化提案]
```

### 1. 質問受付
```
ユーザー: 「過去30日間の売上トップ10商品を教えて」

→ 内部処理:
  - データソース: sales_db (PostgreSQL)
  - テーブル推定: orders, products
  - 期間: NOW() - INTERVAL '30 days'
  - 集計: GROUP BY product_id, SUM(amount)
  - 制限: LIMIT 10
```

### 2. SQL自動生成
```sql
-- 生成されたクエリ（実行前にユーザーに確認）
SELECT 
    p.product_name,
    SUM(o.amount) AS total_sales,
    COUNT(o.id) AS order_count
FROM orders o
JOIN products p ON o.product_id = p.id
WHERE o.created_at >= NOW() - INTERVAL '30 days'
GROUP BY p.product_id, p.product_name
ORDER BY total_sales DESC
LIMIT 10;
```

### 3. 実行確認
```
🔍 実行予定のクエリを確認してください:
  - データソース: sales_db (PostgreSQL)
  - 推定実行時間: < 1秒
  - 推定スキャンサイズ: 約500KB
  - 読み取り専用: ✅

実行しますか? [Y/n]
```

### 4. 結果整形
```
| 商品名            | 売上合計   | 注文数 |
|------------------|-----------|--------|
| 高級チョコレート    | ¥1,234,567 | 432    |
| オーガニックコーヒー | ¥987,654   | 321    |
| ...              | ...       | ...    |

📊 可視化提案:
  - 棒グラフ: 商品別売上
  - 円グラフ: トップ10のシェア
  - トレンドライン: 日別推移
```

## セキュリティ

### 🔴 Critical（絶対禁止）

#### 1. 書き込みクエリ
```sql
-- ❌ 絶対禁止: UPDATE/DELETE/DROP
UPDATE users SET password = 'hacked';  -- 実行拒否

-- ✅ 読み取り専用を強制
SET TRANSACTION READ ONLY;
SELECT * FROM users WHERE id = 123;
```

#### 2. 機密データ露出
```sql
-- ❌ 危険: パスワード、クレカ情報を平文表示
SELECT email, password_hash, credit_card FROM users;

-- ✅ マスク処理
SELECT 
    email,
    '***masked***' AS password,
    CONCAT('****-****-****-', RIGHT(credit_card, 4)) AS card_last4
FROM users;
```

#### 3. 環境変数にパスワード
```bash
# ❌ 危険: パスワードを環境変数に直接設定
export DB_PASSWORD='my_secret_password'  # ログに残る

# ✅ 安全: 1Password CLI / Secrets Manager
export PGPASSWORD=$(op read "op://dev/postgres/password")
psql -h localhost -U postgres
```

### 🟡 Warning（要確認）

#### 1. 大量データスキャン
```sql
-- ⚠️ 注意: 全テーブルスキャン
SELECT * FROM orders WHERE EXTRACT(YEAR FROM created_at) = 2024;

-- ✅ インデックス活用
SELECT * FROM orders 
WHERE created_at >= '2024-01-01' 
  AND created_at < '2025-01-01';
```

#### 2. BigQueryコスト
```sql
-- ⚠️ 注意: 10GB スキャン → 高コスト
SELECT * FROM `project.dataset.huge_table`;

-- ✅ パーティション指定
SELECT * FROM `project.dataset.huge_table`
WHERE _PARTITIONTIME >= TIMESTAMP('2024-01-01')
  AND _PARTITIONTIME < TIMESTAMP('2024-02-01');
```

## データソース別ガイド

### BigQuery

```bash
# プロジェクト一覧
bq ls

# データセット内のテーブル確認
bq ls project_id:dataset_name

# クエリ実行（dry-run でコスト確認）
bq query --dry_run "SELECT COUNT(*) FROM \`project.dataset.table\`"

# 実行
bq query --use_legacy_sql=false "
SELECT 
    DATE(timestamp) AS date,
    COUNT(*) AS events
FROM \`project.analytics.events\`
WHERE _PARTITIONTIME >= TIMESTAMP('2024-01-01')
GROUP BY date
ORDER BY date DESC
LIMIT 30
"
```

### PostgreSQL

```bash
# 接続
psql "postgresql://user:pass@localhost:5432/dbname"

# データベース一覧
\l

# テーブル一覧
\dt

# テーブル構造
\d table_name

# クエリ実行
SELECT * FROM users LIMIT 10;
```

### MySQL

```bash
# 接続
mysql -h localhost -u root -p dbname

# データベース一覧
SHOW DATABASES;

# テーブル一覧
SHOW TABLES;

# テーブル構造
DESCRIBE table_name;
```

### SQLite

```bash
# データベースオープン
sqlite3 data.db

# テーブル一覧
.tables

# スキーマ確認
.schema table_name

# CSV エクスポート
.mode csv
.output result.csv
SELECT * FROM users;
.output stdout
```

### CSV/JSON (pandas)

```python
import pandas as pd

# CSV 読み込み
df = pd.read_csv('data.csv')

# JSON 読み込み
df = pd.read_json('data.json')

# 基本統計
df.describe()

# フィルタリング
df[df['age'] > 30]

# グループ集計
df.groupby('category')['sales'].sum()

# 可視化
df.plot(kind='bar', x='category', y='sales')
```

## 使用例

### 例1: BigQuery で月別ユーザー増加数
```
ユーザー: 「過去12ヶ月の新規登録ユーザー数を月別で教えて」

AI:
🔍 データソース確認...
  - プロジェクト: my-project
  - データセット: analytics
  - テーブル: users (パーティション: created_at)

生成SQL:
SELECT 
    FORMAT_TIMESTAMP('%Y-%m', created_at) AS month,
    COUNT(*) AS new_users
FROM `my-project.analytics.users`
WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 MONTH)
GROUP BY month
ORDER BY month DESC

💰 推定コスト: $0.005 (約10MB スキャン)

実行しますか? [Y/n]
```

### 例2: PostgreSQL で売上分析
```
ユーザー: 「今月のカテゴリ別売上を前月と比較して」

AI:
WITH current_month AS (
    SELECT 
        c.name AS category,
        SUM(o.amount) AS sales
    FROM orders o
    JOIN products p ON o.product_id = p.id
    JOIN categories c ON p.category_id = c.id
    WHERE o.created_at >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY c.name
),
last_month AS (
    SELECT 
        c.name AS category,
        SUM(o.amount) AS sales
    FROM orders o
    JOIN products p ON o.product_id = p.id
    JOIN categories c ON p.category_id = c.id
    WHERE o.created_at >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month'
      AND o.created_at < DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY c.name
)
SELECT 
    cm.category,
    cm.sales AS current_sales,
    lm.sales AS last_sales,
    ROUND((cm.sales - lm.sales) / lm.sales * 100, 2) AS growth_rate
FROM current_month cm
LEFT JOIN last_month lm ON cm.category = lm.category
ORDER BY current_sales DESC;
```

### 例3: CSV データ分析
```
ユーザー: 「sales.csv から地域別の平均売上を計算して」

AI:
import pandas as pd

# CSV 読み込み
df = pd.read_csv('sales.csv')

# 地域別平均売上
result = df.groupby('region')['sales'].agg(['mean', 'count', 'sum']).round(2)

print(result)

📊 可視化コード:
import matplotlib.pyplot as plt
result['mean'].plot(kind='bar', title='地域別平均売上')
plt.ylabel('売上 (円)')
plt.show()
```

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

### 結果提示
- [ ] テーブル形式で整形
- [ ] 可視化方法を提案（棒グラフ/円グラフ/トレンド）
- [ ] CSV/JSON エクスポートオプション提示

## 出力形式

```
🔍 データソース: {DB種別} ({接続先})
📊 推定スキャン: {サイズ/行数}
💰 推定コスト: {BigQuery の場合}

生成SQL:
{整形されたSQL}

実行しますか? [Y/n]

---

結果:
{テーブル形式}

📊 可視化提案:
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
