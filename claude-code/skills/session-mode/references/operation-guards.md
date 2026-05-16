# Operation Guard Specification

## Mode-dependent operation guard

```text
operationGuard : Mode × Action → {Allow, AskUser, Deny}

operationGuard(m, a) =
  | Allow   if a in Safe_m
  | AskUser if a in Boundary_m
  | Deny    if a in Forbidden
```

## Classification rules per mode

```text
Safe_strict     = Mor(Safe)
Boundary_strict = Mor(Boundary)

Safe_normal     = Mor(Safe) + {npm_install(safe_lib)}
Boundary_normal = Mor(Boundary) \ {npm_install(safe_lib)}

Safe_fast       = Mor(Safe) + SafeBoundary
Boundary_fast   = Mor(Boundary) \ SafeBoundary
```

## Invariants

```text
forall m in Mode, Forbidden ⊆ Mor(Forbidden)
strict ≤ normal ≤ fast  # constraint strength order
```

## Serena Memory schema

```yaml
memory_key: "session-mode"
schema:
  mode: "strict" | "normal" | "fast"
  activated_at: ISO8601
  previous_mode: "strict" | "normal" | "fast" | null
```

## Mode transition diagram

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

## Category-theoretic interpretation

### Mode category

```text
Mode category:
  Objects: {strict, normal, fast}
  Morphisms: transition : Mode → Mode
  Identity: id_m : m → m
```

### Operation guard mode transitions

```text
eta_mode : operationGuard_normal ⇒ operationGuard_mode

eta_strict : operationGuard_normal → operationGuard_strict  (strengthen)
eta_fast   : operationGuard_normal → operationGuard_fast    (relax)
```
