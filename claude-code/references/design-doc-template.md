# Design Doc Template

12-section fixed template referenced by `/design-doc` command. For team-shared technical design docs.

## 12-section structure

```markdown
# Design Doc: [Title]

## 1. Overview
- What is being realized (1–2 lines)
- PRD link / reference

## 2. Goals / Non-Goals
### Goals
- What to achieve
### Non-Goals
- What is out of scope (explicit scope boundary)

## 3. Background
- Current problem
- Why change is needed (Why, connection to PRD)

## 4. High-Level Design
- Overall structure (Mermaid arch diagram)
- Data flow (Mermaid sequence diagram)
- Responsibility boundary (roles between services/modules)

## 5. Detailed Design
### 5.1 Data model
- Table design / ER diagram (Mermaid)
- Indexes / constraints
### 5.2 API / Interface
- Endpoints / function signatures
- I/O (type definitions)
### 5.3 Processing flow
- Sequence / pseudo-code (within 5 lines)

## 6. Alternatives
- Other options considered (Option A/B/...)
- Why not adopted (specific reasons)

## 7. Trade-offs
- What is gained / lost
- Numeric comparison (performance / cost / complexity)

## 8. Failure Handling
- Error case enumeration
- Retry policy
- Idempotency guarantee

## 9. Migration Plan
- Expand: add new elements (maintain existing compatibility)
- Migrate: data migration / dual-write
- Contract: remove old elements
(If no DB change: state "N/A")

## 10. Rollback Strategy
- Is rollback possible on failure
- Up to which stage can zero-downtime rollback occur

## 11. Observability
- Logs / metrics / alerts

## 12. Open Questions
- Unconfirmed items (who is waiting for decision)
- Constraints / assumptions (MySQL 8.0, TX isolation etc.)
```

## Type-based application

| Type | Required sections | Optional sections |
|------|------------------|------------------|
| feature (default) | All 1–12 | None |
| refactor | 1,3,5,6,7,9,10 | 2,4,8,11 |
| arch | 1–4,6,7,11 | 5.1/5.3,9 |
| adr | 1,3,6,7,10 | 2,4,5,8,9,11 |
| db-migration | 1,3,5.1,8,9,10,11 | 4,6 (alternatives can be simple) |
| requirements | 1,2,3,12 | 4-11 (skip — phase 後段に委譲) |
| basic | 1,3,4,6,7,11 | 5,8,9,10 (skip — detailed phase へ) |
| detailed | 1,5,8,9 | 2,3,4,6,7,10,11 (basic / adr で別途決定済) |

## Quality guards (type-based)

| Check | feature | refactor | arch | adr | db-migration | requirements | basic | detailed |
|-------|---------|----------|------|-----|--------------|--------------|-------|----------|
| Why (connection to PRD) | required | required | required | required | required | required | required | required |
| Alternatives 2+ options | required | recommended | required | required | recommended | recommended | required | optional |
| Trade-offs numeric comparison | required | recommended | required | required | required | recommended | required | required |
| Failure Handling 3+ cases | required | recommended | recommended | optional | required | optional | recommended | required |
| Migration Expand/Migrate/Contract | required on DB change | required on DB change | optional | optional | **required** | optional | optional | required on DB change |
| Mermaid diagram 1+ | required | recommended | required | recommended | ER diagram required | recommended | required | required (sequence or class) |
| Constraints / assumptions explicit | required | recommended | required | required | required | required | required | required |

## Design philosophy

> A good Design Doc is not "clever design" but **"design where decisions are communicated"**.

| Principle | Bad example | Good example |
|-----------|-------------|-------------|
| Write Why | Create new table | Create new table for O(1) lottery |
| Comparison and tradeoffs | Implement with option A | Compare A/B, B rejected due to high load |
| Change tolerance | Works now | Can handle quantity limit changes / new carrier additions |
| Responsibility boundary | Ambiguous | order-service: orders / shipping-service: delivery |
| Failure cases | Success path only | Out of stock / API failure / double execution / idempotency |
| Migration strategy | Replace table | Expand→Migrate→Contract 3 stages |

**High-quality writing**: speak with numbers (O(n)→O(1), 100req/s→1000req/s), explain with diagrams (sequence/ER/arch), write constraints (MySQL 8.0, READ COMMITTED).

## Phase split (vertical cut)

Type `requirements` / `basic` / `detailed` は同じ 12-section を **phase 別に subset 切り出し**したもの。1 つの機能を 3 doc に分けて出力するときに使う。

### Chain pattern

requirements (Why / Goal / Non-Goal / Open) → basic (arch / module 構成 / trade-off) → detailed (data model / API / 処理 flow / 失敗 / Migration)

各 phase doc は前 phase doc を `## 1. Overview` の "PRD link / reference" 行から参照する。後 phase が前 phase の決定を覆す場合、前 phase doc 側を `--update --scope` で同期する。

### 【要確認】タグ運用 (全 type 共通)

未確定項目を仮置きで埋めない。決定保留点は **【要確認: <何を / 誰が決める / いつまでに>】** 形式で明示する。Step 6 Quality gate は 【要確認】タグの個数と内容を `## 12. Open Questions` に転記する。

NG 例: 「DB は MySQL を使う」(根拠なき仮置き)
OK 例: 「【要確認: DB 選定 / backend lead / Sprint 計画時】MySQL 8.0 想定で進める」
