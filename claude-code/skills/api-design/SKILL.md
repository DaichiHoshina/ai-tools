---
name: api-design
description: API設計 - REST/GraphQL設計原則、バージョニング、エラーハンドリング、ドキュメント
requires-guidelines:
  - common
---

# API設計

## 使用タイミング

- **API 設計時（新規エンドポイント追加）**
- **API レビュー時（設計品質確認）**
- **API ドキュメント作成時**

## 設計観点

### 🔴 Critical（修正必須）

#### 1. REST リソース設計違反
```http
# ❌ 危険: 動詞ベースURL
POST /api/createUser
GET /api/getUserById?id=123
POST /api/deleteUser

# ✅ 正しい: リソースベースURL + HTTPメソッド
POST /api/users
GET /api/users/123
DELETE /api/users/123
```

#### 2. ステータスコード誤用
```typescript
// ❌ 危険: 200固定、エラーもボディに含める
app.post('/users', async (req, res) => {
    const result = await createUser(req.body);
    if (result.error) {
        return res.status(200).json({ error: result.error });  // 間違い
    }
    return res.status(200).json(result);
});

// ✅ 正しい: 適切なステータスコード
app.post('/users', async (req, res) => {
    try {
        const user = await createUser(req.body);
        return res.status(201).json(user);  // Created
    } catch (error) {
        if (error instanceof ValidationError) {
            return res.status(400).json({  // Bad Request
                error: { message: error.message }
            });
        }
        return res.status(500).json({  // Internal Server Error
            error: { message: 'Internal server error' }
        });
    }
});
```

#### 3. エラーフォーマット未統一
```json
// ❌ 危険: バラバラなエラー形式
{"error": "Invalid input"}
{"message": "Not found"}
{"errors": [{"field": "email", "msg": "required"}]}

// ✅ 正しい: RFC 7807 Problem Details
{
    "type": "https://example.com/errors/validation",
    "title": "Validation Failed",
    "status": 400,
    "detail": "Email is required",
    "instance": "/users/123",
    "errors": [
        {
            "field": "email",
            "message": "Email is required"
        }
    ]
}
```

### 🟡 Warning（要改善）

#### 1. バージョニング未実装
```http
# ⚠️ 破壊的変更のリスク
GET /api/users

# ✅ URLバージョニング（推奨）
GET /api/v1/users
GET /api/v2/users

# ✅ ヘッダーバージョニング
GET /api/users
Accept: application/vnd.example.v1+json
```

#### 2. ページネーション不足
```typescript
// ⚠️ 全件取得でパフォーマンス問題
app.get('/users', async (req, res) => {
    const users = await getAllUsers();  // 数万件
    res.json(users);
});

// ✅ カーソルベースページネーション（推奨）
app.get('/users', async (req, res) => {
    const { cursor, limit = 20 } = req.query;
    const result = await getUsers({ cursor, limit });
    res.json({
        data: result.users,
        pagination: {
            nextCursor: result.nextCursor,
            hasMore: result.hasMore
        }
    });
});
```

#### 3. レート制限未実装
```typescript
// ⚠️ DoS攻撃のリスク
app.post('/users', createUser);

// ✅ レート制限実装
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,  // 15分
    max: 100,  // 100リクエスト
    standardHeaders: true,
    legacyHeaders: false,
});

app.post('/users', limiter, createUser);
```

## REST API 設計パターン

### リソース設計
| パターン | URL | メソッド | 用途 |
|---------|-----|---------|------|
| コレクション | `/users` | GET | 一覧取得 |
| コレクション | `/users` | POST | 新規作成 |
| 単一リソース | `/users/123` | GET | 詳細取得 |
| 単一リソース | `/users/123` | PUT | 全体更新 |
| 単一リソース | `/users/123` | PATCH | 部分更新 |
| 単一リソース | `/users/123` | DELETE | 削除 |
| サブリソース | `/users/123/posts` | GET | 関連取得 |

### ステータスコード
| コード | 用途 | 例 |
|-------|------|-----|
| 200 | 成功 | GET, PUT成功 |
| 201 | 作成成功 | POST成功 |
| 204 | 成功（ボディなし） | DELETE成功 |
| 400 | リクエスト不正 | バリデーションエラー |
| 401 | 未認証 | トークン未提供 |
| 403 | 権限不足 | アクセス権なし |
| 404 | リソース未存在 | ユーザーが見つからない |
| 409 | 競合 | 重複エラー |
| 422 | 処理不可 | ビジネスロジックエラー |
| 429 | レート制限 | リクエスト過多 |
| 500 | サーバーエラー | 予期しないエラー |

## GraphQL 設計パターン

### スキーマ設計
```graphql
# ✅ 明確な命名・型定義
type User {
    id: ID!
    email: String!
    name: String
    posts(first: Int, after: String): PostConnection!
}

type PostConnection {
    edges: [PostEdge!]!
    pageInfo: PageInfo!
}

type Query {
    user(id: ID!): User
    users(first: Int, after: String): UserConnection!
}

type Mutation {
    createUser(input: CreateUserInput!): CreateUserPayload!
}
```

### N+1 問題対策
```typescript
// ❌ 危険: N+1問題
const resolvers = {
    User: {
        posts: (user) => fetchPostsByUserId(user.id),  // ユーザー数分クエリ
    },
};

// ✅ DataLoader使用
import DataLoader from 'dataloader';

const postLoader = new DataLoader(async (userIds) => {
    const posts = await fetchPostsByUserIds(userIds);
    return userIds.map(id => posts.filter(p => p.userId === id));
});

const resolvers = {
    User: {
        posts: (user, args, { loaders }) => loaders.post.load(user.id),
    },
};
```

## API 設計チェックリスト

### REST
- [ ] URLはリソースベースか（動詞でなく名詞）
- [ ] HTTPメソッドを正しく使用しているか
- [ ] ステータスコードは適切か
- [ ] エラーフォーマットは統一されているか（RFC 7807推奨）
- [ ] バージョニング戦略があるか
- [ ] ページネーションを実装しているか
- [ ] レート制限を実装しているか

### GraphQL
- [ ] スキーマは明確な命名か
- [ ] Null許容を適切に設定しているか
- [ ] N+1問題を回避しているか（DataLoader）
- [ ] ページネーション（Connection pattern）を実装しているか
- [ ] エラー処理は適切か

### 共通
- [ ] 認証・認可を実装しているか
- [ ] CORS設定は適切か
- [ ] OpenAPI/GraphQL スキーマドキュメントを作成しているか
- [ ] セキュリティヘッダーを設定しているか

## 認証・認可パターン

### JWT トークン
```typescript
// ✅ Bearer トークン + リフレッシュトークン
Authorization: Bearer eyJhbGc...

// アクセストークン: 短命（15分）
// リフレッシュトークン: 長命（7日）、HttpOnly Cookie
```

### API キー
```typescript
// ✅ ヘッダー経由（URL不可）
X-API-Key: your-api-key
```

## 出力形式

🔴 **Critical**: エンドポイント - リソース設計違反/ステータスコード誤用 - 修正案
🟡 **Warning**: エンドポイント - バージョニング不足/ページネーション不足 - 改善案
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

設計実施前に以下のガイドラインを参照:
- `~/.claude/guidelines/common/code-quality-design.md`

## 外部知識ベース

最新のAPI設計ベストプラクティス確認には context7 を活用:
- OpenAPI Specification (OAS 3.x)
- GraphQL公式ドキュメント
- REST API設計ガイド（Google/Microsoft API Design Guide）
- RFC 7807（Problem Details for HTTP APIs）

## プロジェクトコンテキスト

プロジェクト固有のAPI設計情報を確認:
- serena memory からAPI規約・命名規則を取得
- プロジェクトの標準的なエラーフォーマットを優先
- 既存のバージョニング戦略に従う
- 使用しているフレームワーク（Express/Fastify/NestJS）の規約に従う
