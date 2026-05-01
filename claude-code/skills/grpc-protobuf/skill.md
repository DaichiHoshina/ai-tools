---
name: grpc-protobuf
description: gRPC/Protobuf開発。proto定義・コード生成・バックエンド実装のワークフロー、gRPCサービス実装時に使用
requires-guidelines:
  - golang
  - common
---

# grpc-protobuf - gRPC/Protobuf開発

## 開発フロー

```
1. proto定義変更
   ↓
2. proto-sync実行（生成コード更新）
   ↓
3. バックエンド実装
   ↓
4. テスト作成・実行
```

## Proto変更時のチェックリスト

### 1. Proto定義

- [ ] フィールド番号は既存と重複しない
- [ ] 必須/任意を正しく設定
- [ ] コメントで仕様を明記
- [ ] 命名規則（snake_case for fields）

```protobuf
message ExampleRequest {
  string user_id = 1;     // 必須
  string email = 2;       // 任意
  int64 created_at = 3;   // Unix timestamp
}
```

### 2. 生成コード更新

```bash
# proto-sync使用時
proto-sync sync

# 手動生成
protoc --go_out=. --go-grpc_out=. *.proto
```

### 3. バックエンド実装

```go
// 生成されたインターフェースを実装
func (s *Server) ExampleMethod(ctx context.Context, req *pb.ExampleRequest) (*pb.ExampleResponse, error) {
    // 1. バリデーション
    if req.GetUserId() == "" {
        return nil, status.Error(codes.InvalidArgument, "user_id is required")
    }

    // 2. ビジネスロジック
    // ...

    // 3. レスポンス
    return &pb.ExampleResponse{}, nil
}
```

## 後方互換性

| 変更 | 互換性 |
|------|--------|
| フィールド追加 | OK |
| フィールド削除 | NG（reservedに） |
| 型変更 | NG |
| フィールド番号変更 | NG |

```protobuf
// 削除したフィールドはreserved
message User {
  reserved 2;  // 削除されたemail
  string name = 1;
  string new_email = 3;
}
```

## 失敗時の挙動

| 状況 | 動作 |
|------|------|
| `proto-sync` 未インストール | `protoc` 直接実行に降格、`brew install protobuf` 案内 |
| 生成コードのコンパイル失敗 | proto 定義を1コミット前に rollback、原因を報告して停止 |
| フィールド番号衝突検出 | 修正案（次の空き番号）提示、ユーザー確認後に再試行 |
| reserved 未指定で削除検出 | Critical エラー、reserved 追加修正案を出力 |

## 出力形式

通常ケース:

```
✅ Proto sync 完了
- 生成ファイル: N 件 (例: user.pb.go, user_grpc.pb.go)
- 後方互換性: OK / NG（NG 時は違反内容）
- 次アクション: バックエンド実装 / テスト更新
```

ゼロ件・互換性違反検出時:

```
⚠️ 後方互換性違反検出
🔴 Critical: ファイル:行 - 違反種別 - 修正案
📊 Summary: 互換違反 X件 / フィールド衝突 Y件
```
