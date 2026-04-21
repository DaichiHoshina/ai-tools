---
name: api-design
description: API設計 - REST/GraphQL設計原則、バージョニング、エラーハンドリング、ドキュメント
requires-guidelines:
  - common
  - clean-architecture
---

# api-design - API設計

## 使用タイミング

- API設計時（新規エンドポイント追加）/ APIレビュー時 / ドキュメント作成時

---

## レビュー観点

### 🔴 Critical（修正必須）

| 観点 | 検出パターン | 対策 |
|------|-------------|------|
| リソース設計違反 | 動詞ベースURL (`/createUser`) | リソース名詞 + HTTPメソッド |
| ステータスコード誤用 | エラーでも200返却 | 適切なステータスコード |
| エラー形式未統一 | バラバラなJSON構造 | RFC 7807 Problem Details |

### 🟡 Warning（要改善）

| 観点 | 検出パターン | 対策 |
|------|-------------|------|
| バージョニング未実装 | `/api/users` 固定 | `/api/v1/users` or ヘッダー |
| ページネーション不足 | 全件取得 | カーソルベースページネーション |
| レート制限なし | 認証APIに制限なし | express-rate-limit等 |

**コード例が必要な場合**: Context7で「REST API design」「GraphQL best practices」を検索

---

## REST API パターン

### リソース設計

| パターン | URL | メソッド | 用途 |
|---------|-----|---------|------|
| コレクション | `/users` | GET/POST | 一覧/作成 |
| 単一リソース | `/users/123` | GET/PUT/PATCH/DELETE | CRUD |
| サブリソース | `/users/123/posts` | GET | 関連取得 |

### API粒度判定フロー（新規追加 vs 既存拡張）

新規エンドポイント追加前に必ず判定:

```text
新しいAPIが必要？
├─ 既存に類似エンドポイントあり？
│  ├─ Yes → 既存にパラメータ追加で対応可？
│  │  ├─ Yes → 既存拡張（クエリパラメータ、ヘッダ）
│  │  └─ No → 既存とレスポンス構造が大きく異なる？
│  │     ├─ Yes → 別エンドポイント新設
│  │     └─ No → 既存に optional フィールド追加
│  └─ No → 新エンドポイント作成
└─ 検討項目:
   - 1リクエストで複数操作が必要？ → BFF or バッチ API化
   - フロント都合の集計値？ → ❌ 生データ返却（rules/api-design.md準拠）
```

**粒度判断基準**:

| 状況 | 推奨 | 理由 |
|------|------|------|
| 同一リソースに対する操作違い | 同URL、メソッド/パラメータで分岐 | RESTful、検索性 |
| 異なるリソース、関連あり | サブリソース `/parent/:id/child` | 関係性明示 |
| 集計・統計（複数リソース横断） | `/stats/...`、`/reports/...` 別namespace | 責務分離 |
| 1リクエストで複数操作 | バッチエンドポイント `/batch` | round-trip削減 |
| クライアント別最適化 | BFF（Backend-For-Frontend）層 | サーバー API は汎用維持 |

**アンチパターン**:
- ❌ `/createUser`, `/updateUser`, `/deleteUser` 動詞ベース → ⭕ `/users` + HTTPメソッド
- ❌ フロント表示用集計値を埋め込み → ⭕ 生データ返却、フロント側集計
- ❌ 1ユースケース1エンドポイント乱立 → ⭕ 既存拡張優先（onClickActionでなくデータ操作粒度）

### ステータスコード選択表（詳細）

| コード | 名称 | 使い分け |
|--------|------|---------|
| **200** | OK | 通常の成功（GET/PUT/PATCH） |
| **201** | Created | リソース作成成功（POST、Locationヘッダ必須） |
| **202** | Accepted | 非同期処理を受付（即完了しない） |
| **204** | No Content | 成功でレスポンスボディ無し（DELETE） |
| **301/302/307** | Redirect | URL変更通知 |
| **400** | Bad Request | リクエスト形式エラー（バリデーション失敗） |
| **401** | Unauthorized | 認証情報不在/無効（認証必要） |
| **403** | Forbidden | 認証はOKだが権限なし |
| **404** | Not Found | リソース不在（権限隠蔽目的でも使用） |
| **405** | Method Not Allowed | メソッド非対応（Allowヘッダ必須） |
| **409** | Conflict | 競合（楽観ロック失敗、重複登録） |
| **410** | Gone | リソース永久削除（404と区別） |
| **422** | Unprocessable Entity | 形式OKだが意味的に処理不能（業務ルール違反） |
| **429** | Too Many Requests | レート制限超過（Retry-Afterヘッダ必須） |
| **500** | Internal Server Error | サーバー内部エラー（詳細は隠蔽） |
| **502/503/504** | Gateway/Unavailable/Timeout | 上流障害、Retry-After推奨 |

**判定フロー**:

```text
リクエスト来た
├─ 形式不正 → 400
├─ 認証なし/無効 → 401
├─ 権限なし → 403（漏洩懸念なら 404）
├─ 対象リソースなし → 404
├─ メソッド非対応 → 405
├─ 業務ルール違反 → 422（バリデーションは 400）
├─ 競合（version mismatch、重複）→ 409
├─ rate limit → 429
└─ 成功 → 200/201/202/204
```

**400 vs 422**: 構文エラー（JSON parse失敗等）は 400、構文OKで意味エラー（業務ルール違反）は 422。

**403 vs 404**: 「リソース存在の漏洩」を防ぎたい場合は 404 で隠蔽。

---

## GraphQL パターン

| 観点 | ベストプラクティス |
|------|-------------------|
| スキーマ | 明確な命名・型定義 |
| ページネーション | Connection pattern |
| N+1問題 | DataLoader使用 |

---

## チェックリスト

**REST**: リソースベースURL / 適切なステータス / エラー統一 / バージョニング / ページネーション / レート制限

**GraphQL**: 明確なスキーマ / Null許容設定 / DataLoader / Connection pattern

**共通**: 認証・認可 / CORS / OpenAPI/GraphQLドキュメント / セキュリティヘッダー

---

## 出力形式

```
🔴 Critical: エンドポイント - 問題 - 修正案
🟡 Warning: エンドポイント - 問題 - 改善案
📊 Summary: Critical X件 / Warning Y件
```

---

## 外部リソース

- **Context7**: OpenAPI 3.x、GraphQL公式、Google/Microsoft API Design Guide、RFC 7807
- **Serena memory**: プロジェクト固有のAPI規約・バージョニング戦略
