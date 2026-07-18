---
allowed-tools: Bash, Read, Edit
name: grpc-protobuf
description: gRPC/Protobuf: proto design, codegen, backend impl. Use for gRPC services. 「gRPC/proto 設計して」で起動。 — 一般 backend 実装は backend-dev を使う
requires-guidelines:
  - golang
  - common
---

# grpc-protobuf - gRPC/Protobuf Development

## Development Flow

```
1. Modify proto definition
   ↓
2. Run proto-sync (update generated code)
   ↓
3. Implement backend
   ↓
4. Create & run tests
```

## Proto Change Checklist

### 1. Proto Definition

- [ ] Field numbers don't duplicate existing ones
- [ ] Required/optional fields correctly set
- [ ] Spec documented in comments
- [ ] Naming convention (snake_case for fields)

```protobuf
message ExampleRequest {
  string user_id = 1;     // required
  string email = 2;       // optional
  int64 created_at = 3;   // Unix timestamp
}
```

### 2. Update Generated Code

```bash
# Using proto-sync
proto-sync sync

# Manual generation
protoc --go_out=. --go-grpc_out=. *.proto
```

### 3. Backend Implementation

```go
// Implement generated interface
func (s *Server) ExampleMethod(ctx context.Context, req *pb.ExampleRequest) (*pb.ExampleResponse, error) {
    // 1. Validation
    if req.GetUserId() == "" {
        return nil, status.Error(codes.InvalidArgument, "user_id is required")
    }

    // 2. Business logic
    // ...

    // 3. Response
    return &pb.ExampleResponse{}, nil
}
```

## Backward Compatibility

| Change | Compatibility |
|--------|--------|
| Add field | OK |
| Delete field | NG (mark reserved) |
| Change type | NG |
| Change field number | NG |

```protobuf
// Mark deleted fields as reserved
message User {
  reserved 2;  // deleted email
  string name = 1;
  string new_email = 3;
}
```

## Failure Behavior

| Situation | Action |
|------|------|
| `proto-sync` not installed | Fallback to `protoc`, suggest `brew install protobuf` |
| Generated code compile failure | Rollback proto to 1 commit prior, report error & stop |
| Field number collision | Suggest fix (next available number), confirm with user & retry |
| Deletion without reserved | Critical error, output reserved addition fix |

## Output Format

Normal case:

```
✅ Proto sync complete
- Generated files: N (e.g. user.pb.go, user_grpc.pb.go)
- Backward compatibility: OK / NG (show violation if NG)
- Next: Backend implementation / test update
```

Zero findings / Compatibility violation:

```
⚠️ Backward compatibility violation detected
🔴 Critical: file:line - violation type - fix
📊 Summary: compatibility violation X / field collision Y
```
