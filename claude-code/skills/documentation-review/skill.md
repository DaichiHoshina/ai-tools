---
name: documentation-review
description: ドキュメントレビュー - コメント品質、API仕様、README、型定義コメントを評価
requires-guidelines:
  - common
---

# ドキュメントレビュー

## 使用タイミング

- **API実装時**
- **公開ライブラリ作成時**
- **/docs コマンド実行時**

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. 公開API・型に説明なし

```typescript
// ❌ 危険 - 説明なし
export interface User {
  id: string;
  metadata: unknown; // 何のデータ？
}

// ✅ 安全 - 明確な説明
/**
 * ユーザー情報
 */
export interface User {
  /** ユーザーID（UUID v4） */
  id: string;
  /** カスタムメタデータ（最大1KB、JSON形式） */
  metadata: Record<string, unknown>;
}
```

```go
// ❌ 危険
type Config struct {
    MaxRetries int
    Timeout    time.Duration
}

// ✅ 安全
// Config はクライアント設定を表す
type Config struct {
    // MaxRetries はリトライ最大回数（デフォルト: 3）
    MaxRetries int
    // Timeout は1リクエストあたりのタイムアウト
    Timeout time.Duration
}
```

#### 2. 嘘のコメント

```typescript
// ❌ 危険 - 実装と不一致
/**
 * ユーザーを削除する
 */
function archiveUser(id: string) {
  // 実際は削除していない
  return db.update({ id, archivedAt: new Date() });
}

// ✅ 安全 - 実装と一致
/**
 * ユーザーをアーカイブする（論理削除）
 */
function archiveUser(id: string) {
  return db.update({ id, archivedAt: new Date() });
}
```

#### 3. TODOの放置

```typescript
// ❌ 危険 - 古いTODO
// TODO: バリデーション追加（2020-01-01）
function createUser(data: any) { ... }

// ✅ 安全 - Issue化 or 実装
/**
 * ユーザー作成
 * @throws {ValidationError} バリデーションエラー時
 */
function createUser(data: CreateUserInput) {
  validateUserInput(data);
  return db.insert(data);
}
```

### 🟡 Warning（要改善）

#### 1. 自明なコメント

```typescript
// ⚠️ 不要
// ユーザーIDを取得
const userId = user.id;

// カウンターをインクリメント
counter++;

// ✅ コメント不要（コード自体が明確）
const userId = user.id;
counter++;
```

#### 2. 不十分なエラー説明

```typescript
// ⚠️ 改善推奨
/**
 * ユーザー作成
 * @throws Error
 */
function createUser() { ... }

// ✅ 具体的
/**
 * ユーザー作成
 * @throws {ValidationError} 入力データが不正な場合
 * @throws {DuplicateEmailError} メールアドレスが既に存在する場合
 * @throws {DatabaseError} DB接続エラーの場合
 */
function createUser() { ... }
```

#### 3. パラメータ説明不足

```typescript
// ⚠️ 改善推奨
/**
 * データを取得
 * @param options オプション
 */
function fetchData(options: FetchOptions) { ... }

// ✅ 詳細
/**
 * データを取得
 * @param options 取得オプション
 * @param options.limit 取得件数（デフォルト: 100、最大: 1000）
 * @param options.offset オフセット（ページネーション用）
 * @param options.includeDeleted 削除済みデータを含めるか
 */
function fetchData(options: FetchOptions) { ... }
```

#### 4. READMEの更新漏れ

```markdown
<!-- ⚠️ 改善推奨 - 古い情報 -->
## Installation
npm install old-package-name

<!-- ✅ 最新 -->
## Installation
npm install @org/new-package-name
```

## チェックリスト

### コード内ドキュメント
- [ ] 公開API全てに説明があるか
- [ ] パラメータの制約が明記されているか
- [ ] 戻り値の説明があるか
- [ ] エラー条件が明記されているか

### コメント品質
- [ ] コメントと実装が一致しているか
- [ ] 自明なコメントを避けているか
- [ ] Why（なぜ）を説明しているか
- [ ] What（何を）はコード自体で表現しているか

### 型定義
- [ ] 型の説明があるか
- [ ] フィールドの制約が明記されているか
- [ ] デフォルト値が明記されているか

### プロジェクトドキュメント
- [ ] README が最新か
- [ ] セットアップ手順が明確か
- [ ] API仕様が整備されているか
- [ ] 変更履歴（CHANGELOG）があるか

## 出力形式

🔴 **Critical**: `ファイル:行` - 公開API説明なし/嘘のコメント - 修正案
🟡 **Warning**: `ファイル:行` - 改善推奨 - 具体的な改善方法
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

- `common/document-management.md` - プロジェクト共通のドキュメント管理指針
  - READMEテンプレート
  - CHANGELOG管理
  - ADR（Architecture Decision Records）
  - API仕様書フォーマット

## 外部知識ベース

- テクニカルライティングガイド
  - Microsoft Writing Style Guide
  - Google Developer Documentation Style Guide
  - The Chicago Manual of Style
- API documentation standards
  - OpenAPI/Swagger仕様
  - JSDoc/TSDoc規約
  - GoDoc規約
- ドキュメント品質チェックリスト
  - DITA（Darwin Information Typing Architecture）
  - Docs as Code プラクティス

## プロジェクトコンテキスト

- プロジェクトのドキュメント規約
  - コメント記述言語（日本語/英語）
  - JSDoc/TSDoc/@param記法
  - 型定義コメントの必須レベル
- 必須ドキュメント
  - README.md（セットアップ手順、使い方）
  - CONTRIBUTING.md（コントリビューション指針）
  - API.md（API仕様書）
  - CHANGELOG.md（変更履歴）
- ドキュメント生成ツール
  - TypeDoc/JSDoc（TypeScript/JavaScript）
  - GoDoc（Go）
  - Sphinx/MkDocs（Python）
