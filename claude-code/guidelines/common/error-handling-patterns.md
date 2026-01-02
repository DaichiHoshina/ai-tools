# エラーハンドリングパターン

## 基本原則

| 原則 | 説明 |
|------|------|
| 早期検出 | エラーは発生箇所で検出 |
| 握りつぶさない | 必ず呼び出し元に返すかログに記録 |
| 境界層で変換 | API/DB/外部サービスでエラー変換 |
| 種類を明確に | 型やクラスで区別 |

## クイックリファレンス

### TypeScript

| パターン | コード | 用途 |
|---------|--------|------|
| Result型 | `type Result<T, E> = { ok: true; value: T } \| { ok: false; error: E }` | 型安全なエラーハンドリング |
| カスタムエラー | `class ValidationError extends Error {}` | エラー種類の区別 |
| try-catch | 境界層（API/DB）のみ | 外部I/O操作 |

**エラークラス例**:
- `ValidationError` - バリデーションエラー
- `NotFoundError` - リソース未発見
- `NetworkError` - ネットワークエラー

### Go

| パターン | コード | 用途 |
|---------|--------|------|
| 基本 | `errors.New("message")` | シンプルなエラー |
| ラップ | `fmt.Errorf("msg: %w", err)` | 文脈追加 (1.13+) |
| 判定 | `errors.Is(err, ErrNotFound)` | 種類判定 |
| 型変換 | `errors.As(err, &target)` | 型アサーション |

**センチネルエラー**:
```go
var ErrNotFound = errors.New("not found")
```

## よくあるミス

### TypeScript

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `try { logic() } catch {}` | Result型でエラーを返す | 型安全性・明示性 |
| `throw new Error()` をビジネスロジックで多用 | Result型で返す | 例外は境界層のみ |
| エラーメッセージにDB詳細含む | `"Internal server error"` | セキュリティ |

### Go

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `result, _ := db.Query()` | `if err != nil { return err }` | エラー握りつぶし禁止 |
| `return err` | `return fmt.Errorf("context: %w", err)` | 文脈追加 |
| `err.Error() == "not found"` | `errors.Is(err, ErrNotFound)` | 安全な判定 |

## ログレベル

| レベル | 用途 |
|--------|------|
| ERROR | システムエラー、予期しないエラー |
| WARN | 回復可能なエラー |
| INFO | 正常動作の記録 |

## セキュリティ原則

**ユーザーに返すエラーには内部実装詳細を含めない**

| ❌ 避ける | ✅ 使う |
|----------|---------|
| `"Connection to database 'prod_db' failed at 192.168.1.10"` | `"Internal server error"` |

**Why**: 詳細はサーバー側ログのみ記録
