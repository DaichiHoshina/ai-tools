# 操作ガード詳細定義

## モード依存操作ガード

```text
operationGuard : Mode x Action → {Allow, AskUser, Deny}

operationGuard(m, a) =
  | Allow   if a in Safe_m
  | AskUser if a in Boundary_m
  | Deny    if a in Forbidden
```

## 各モードの分類ルール

```text
Safe_strict     = Mor(Safe)
Boundary_strict = Mor(Boundary)

Safe_normal     = Mor(Safe) + {npm_install(safe_lib)}
Boundary_normal = Mor(Boundary) \ {npm_install(safe_lib)}

Safe_fast       = Mor(Safe) + SafeBoundary
Boundary_fast   = Mor(Boundary) \ SafeBoundary
```

## 不変条件

```text
forall m in Mode, Forbidden subset Mor(Forbidden)
strict <= normal <= fast  # 制約の強さの順序
```

## Serena Memoryスキーマ

```yaml
memory_key: "session-mode"
schema:
  mode: "strict" | "normal" | "fast"
  activated_at: ISO8601
  previous_mode: "strict" | "normal" | "fast" | null
```

## モード遷移図

```text
         /mode strict
    +------------------+
    |                  v
+-------+         +--------+
| fast  |<------->| strict |
+-------+         +--------+
    |                  |
    |   /mode normal   |
    |        |         |
    v        v         v
         +--------+
         | normal |
         +--------+
```

## 圏論的解釈

### モード圏の定義

```text
Mode圏:
  対象: {strict, normal, fast}
  遷移: transition : Mode → Mode
  恒等遷移: id_m : m → m
```

### 操作ガードのモード遷移

```text
eta_mode : operationGuard_normal => operationGuard_mode

eta_strict : operationGuard_normal → operationGuard_strict  （制約強化）
eta_fast   : operationGuard_normal → operationGuard_fast    （制約緩和）
```
