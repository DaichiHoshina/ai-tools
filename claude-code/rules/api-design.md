---
paths:
  - "**/*handler*"
  - "**/*controller*"
  - "**/*resolver*"
  - "**/*api*"
  - "**/*endpoint*"
---
# API Design Principles

## Response Design

- Do not embed UI-specific aggregations in API responses. Return raw data; front-end aggregates
- Design for single-point updates: anticipate where spec changes and isolate them

## Error Response

- Structured error response: code + message
- Do not leak internal error details to client
