---
name: microservices-monorepo
description: Microservices & monorepo: service split, comms, structure. Use for arch design.
requires-guidelines:
  - common
  - clean-architecture
  - ddd
---

# microservices-monorepo - Microservices & Monorepo Design

## Design Patterns

### Service Split Strategy

| Criterion | Description |
|------|------|
| Business function | Order, inventory, shipping, payment |
| DDD bounded context | Align with domain boundary |
| Team structure | Conway's law (org structure) |
| Data ownership | Each service owns its DB |

**Service size**: 1 team manageable, clear responsibility boundary

### Communication Patterns

| Type | Pattern | Use Case |
|------|---------|------|
| Sync | REST API | Simple CRUD |
| Sync | gRPC | High performance, type-safe |
| Async | Message queue | Kafka, RabbitMQ, SQS |
| Async | Event-driven | Loose coupling, scalable |

### Architecture Patterns

- **API Gateway**: Single entry point, auth, routing
- **Service Mesh**: Istio, Linkerd
- **Circuit Breaker**: Prevent cascade
- **Saga**: Distributed transactions

### Monorepo Structure

```
monorepo/
├── services/           # Each service
├── packages/           # Shared libs, proto, types
├── infrastructure/     # k8s, terraform
└── tools/              # scripts
```

**Tools**: Turborepo, Nx, pnpm workspaces

---

## Antipatterns (Forbidden)

- **Direct other service DB access**: Violates boundary, breaks on schema change → always API.
- **Sync call chain**: A→B→C→D cascade. Causes failure cascade → consider async event-driven.
- **Shared DB**: Violates Database per Service. Give each its own.

> Implementation examples: see `guidelines/design/microservices-kubernetes.md`.

---

## Checklist

### Service Split
- [ ] Service boundary = business function
- [ ] Each service independently deployable
- [ ] Each service owns its DB

### Communication Design
- [ ] Sync/async appropriately separated
- [ ] Circuit Breaker for fallback
- [ ] Timeout/retry configured

### Data Management
- [ ] Database per Service
- [ ] Distributed transactions = Saga pattern

### Observability
- [ ] Structured logging
- [ ] Distributed tracing
- [ ] Correlation ID for request tracking

---

## Output Format

Normal case:

```
📋 **Service List**
- [name]: [responsibility] - [DB] - [comm]

🔄 **Service-to-Service Comms**
[flow]

🔴 **Critical**: service - violation - fix
🟡 **Warning**: service - improvement - refactor
```

Zero findings / Monolith (no microservices):

```
📋 **Service List**
> [WARN] Single service (monolith) detected. Split proposal only.

🔴 **Critical**: 0
🟡 **Warning**: 0 (not applicable yet)

### Split Proposal
- Option1: [feature A] → independent service (reason: independent scale)
- Option2: [feature B] → independent service (reason: team ownership)
```

---

## Related Guidelines / Context7

- `guidelines/design/microservices-kubernetes.md`, `design/clean-architecture.md`
- Context7: `/vercel/turborepo`, `/nrwl/nx`, "saga pattern", "circuit breaker"
