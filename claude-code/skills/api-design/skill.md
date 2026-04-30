---
name: api-design
description: API設計（REST/GraphQL）。設計原則・バージョニング・エラーハンドリング・ドキュメント方針
requires-guidelines:
  - common
  - clean-architecture
---

# api-design - API設計

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

### API粒度判定（新規 vs 既存拡張）

新規エンドポイント追加前に必ず判定。

| 状況 | 推奨 | 理由 |
|------|------|------|
| 既存に類似あり、パラメータ追加で対応可 | 既存拡張（クエリ/ヘッダ） | URL増殖回避 |
| 既存と類似だがレスポンス構造大差 | 別エンドポイント新設 | 責務分離 |
| 同一リソースに対する操作違い | 同URL、メソッド/パラメータで分岐 | RESTful、検索性 |
| 異なるリソース、関連あり | サブリソース `/parent/:id/child` | 関係性明示 |
| 集計・統計（複数リソース横断） | `/stats/...`、`/reports/...` 別namespace | 責務分離 |
| 1リクエストで複数操作 | バッチエンドポイント `/batch` | round-trip削減 |
| クライアント別最適化 | BFF（Backend-For-Frontend）層 | サーバー API は汎用維持 |

**アンチパターン**:
- ❌ `/createUser`, `/updateUser`, `/deleteUser` 動詞ベース → ⭕ `/users` + HTTPメソッド
- ❌ 1ユースケース1エンドポイント乱立 → ⭕ 既存拡張優先（onClickActionでなくデータ操作粒度）

**詳細ルール**: `~/.claude/rules/api-design.md` 準拠（UI都合の集計値埋込み禁止 等）

### ステータスコード選択表

| コード | 名称 | 使い分け |
|--------|------|---------|
| **200** | OK | 通常の成功（GET/PUT/PATCH） |
| **201** | Created | リソース作成成功（POST、Location 推奨: RFC 9110 SHOULD） |
| **202** | Accepted | 非同期処理を受付（即完了しない） |
| **204** | No Content | 成功でレスポンスボディ無し（DELETE） |
| **301/302/307** | Redirect | URL変更通知 |
| **400** | Bad Request | リクエスト形式エラー（バリデーション失敗） |
| **401** | Unauthorized | 認証情報不在/無効（認証必要） |
| **403** | Forbidden | 認証はOKだが権限なし |
| **404** | Not Found | リソース不在（存在自体を秘匿したい場合の権限隠蔽にも） |
| **405** | Method Not Allowed | メソッド非対応（Allow ヘッダ必須: RFC 9110 MUST） |
| **409** | Conflict | 競合（楽観ロック失敗、重複登録） |
| **410** | Gone | リソース永久削除（404と区別: 再アクセス防止意図） |
| **422** | Unprocessable Entity | 形式OKだが意味的に処理不能（業務ルール違反） |
| **429** | Too Many Requests | レート制限超過（Retry-After 推奨: RFC 6585 MAY） |
| **500** | Internal Server Error | サーバー内部エラー（詳細は隠蔽） |
| **502/503/504** | Gateway/Unavailable/Timeout | 上流障害、Retry-After 推奨 |

**境界判定**:
- **400 vs 422**: 構文エラー（JSON parse失敗等）は 400、構文OKで意味エラー（業務ルール違反）は 422
- **403 vs 404**: 認可失敗を明示してよい場合は 403。リソースの存在自体を秘匿したい場合（他組織リソース、認可階層秘匿等）は 404 で隠蔽
- **404 vs 410**: 「もうない」と明示したい（再アクセス防止）なら 410、不明なら 404

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
