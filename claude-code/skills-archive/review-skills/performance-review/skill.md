---
name: performance-review
description: パフォーマンスレビュー - N+1問題、メモリリーク、不要なループ、非効率なアルゴリズムを検出
requires-guidelines:
  - common
---

# パフォーマンスレビュー

## 使用タイミング

- **コードレビュー時（パフォーマンス確認）**
- **リファクタリング時（最適化）**
- **本番パフォーマンス問題発生時**

## レビュー観点

### 🔴 Critical（修正必須）

#### 1. N+1 問題

```typescript
// ❌ 危険 - N+1
const users = await getUserList();
for (const user of users) {
  const posts = await getPostsByUserId(user.id); // N回クエリ
}

// ✅ 安全 - 1クエリ
const users = await getUserList();
const userIds = users.map(u => u.id);
const posts = await getPostsByUserIds(userIds);
```

```go
// ❌ 危険 - N+1
users, _ := repo.GetUsers()
for _, user := range users {
    posts, _ := repo.GetPostsByUserID(user.ID) // N回クエリ
}

// ✅ 安全 - JOIN または IN句
posts, _ := repo.GetPostsWithUsers()
```

#### 2. メモリリーク

```typescript
// ❌ 危険 - イベントリスナー解除なし
useEffect(() => {
  window.addEventListener('resize', handler);
  // cleanup なし
}, []);

// ✅ 安全 - cleanup
useEffect(() => {
  window.addEventListener('resize', handler);
  return () => window.removeEventListener('resize', handler);
}, []);
```

```go
// ❌ 危険 - goroutine リーク
func Process() {
    for item := range items {
        go func() {
            // 終了しない goroutine
            for {
                // ...
            }
        }()
    }
}

// ✅ 安全 - context で制御
func Process(ctx context.Context) {
    for item := range items {
        go func() {
            for {
                select {
                case <-ctx.Done():
                    return
                default:
                    // ...
                }
            }
        }()
    }
}
```

#### 3. 不要なループ・計算

```typescript
// ❌ 危険 - ループ内で毎回計算
for (let i = 0; i < items.length; i++) {
  const threshold = calculateThreshold(); // 毎回計算
  if (items[i] > threshold) { ... }
}

// ✅ 安全 - 事前計算
const threshold = calculateThreshold();
for (let i = 0; i < items.length; i++) {
  if (items[i] > threshold) { ... }
}
```

### 🟡 Warning（要改善）

#### 1. 非効率なアルゴリズム

```typescript
// ⚠️ O(n²) - 改善推奨
for (const a of list1) {
  for (const b of list2) {
    if (a.id === b.id) { ... }
  }
}

// ✅ O(n) - Map使用
const map = new Map(list2.map(b => [b.id, b]));
for (const a of list1) {
  const b = map.get(a.id);
  if (b) { ... }
}
```

#### 2. 過剰なデータ取得

```typescript
// ⚠️ 全カラム取得
const users = await db.query('SELECT * FROM users');

// ✅ 必要なカラムのみ
const users = await db.query('SELECT id, name FROM users');
```

#### 3. 同期処理の連続

```typescript
// ⚠️ 直列実行
const user = await fetchUser();
const posts = await fetchPosts();
const comments = await fetchComments();

// ✅ 並列実行
const [user, posts, comments] = await Promise.all([
  fetchUser(),
  fetchPosts(),
  fetchComments(),
]);
```

## チェックリスト

### データベース
- [ ] N+1 問題がないか
- [ ] SELECT * を使用していないか
- [ ] インデックスが適切か
- [ ] 不要な JOIN がないか

### ループ・アルゴリズム
- [ ] ループ内で不要な計算をしていないか
- [ ] O(n²) 以上のアルゴリズムがないか
- [ ] Map/Set で O(1) アクセスできないか

### メモリ
- [ ] イベントリスナーの cleanup があるか
- [ ] goroutine/Promise が適切に終了するか
- [ ] 大量データを一度にメモリに載せていないか

### 並列・非同期
- [ ] 並列実行できる処理が直列になっていないか
- [ ] 適切な並列数制限があるか（goroutine pool等）

## 出力形式

🔴 **Critical**: `ファイル:行` - N+1/メモリリーク - 修正案
🟡 **Warning**: `ファイル:行` - 非効率な処理 - 最適化案
📊 **Summary**: Critical X件 / Warning Y件

## 関連ガイドライン

レビュー実施時は以下のガイドラインを参照してください：

- `common/technical-pitfalls.md` - パフォーマンス関連の技術的落とし穴
- `languages/*.md` - 各言語固有のパフォーマンスベストプラクティス
  - TypeScript: Promise並列化、メモリ管理、React最適化
  - Go: goroutineリーク、channel使用、メモリアロケーション

これらのガイドラインには、実際のプロジェクトで発生したパフォーマンス問題と対処法が記載されています。

## 外部知識ベース

必要に応じて以下の外部知識を参照してください：

- **パフォーマンス最適化ガイド** - 言語別・フレームワーク別の最適化パターン
- **プロファイリングツールドキュメント** - Chrome DevTools、pprof、clinic.js等の使用方法
- **データベース最適化** - インデックス設計、クエリ最適化、N+1解決パターン
- **メモリ管理ベストプラクティス** - GC動作、メモリリーク検出手法

Context7 MCPを使用して最新のドキュメントを取得できます。

## プロジェクトコンテキスト

レビュー時は以下のプロジェクト情報を考慮してください：

- **パフォーマンス要件** - レスポンスタイム目標値、スループット基準
- **ボトルネック箇所** - 既知のパフォーマンス問題、改善優先度リスト
- **インフラ制約** - メモリ上限、CPU制限、データベース接続数制限
- **過去の最適化履歴** - 実施した最適化とその効果測定結果

プロジェクト固有の情報はSerenaのメモリーから取得できます。
