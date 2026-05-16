---
paths:
  - "**/*.sh"
---
# Shell Script Rules

## Required

- set -euo pipefail
- shellcheck compliant
- Variables quoted as `"${var}"`

## Prohibited

- eval forbidden
- rm -rf / forbidden
- Undefined variable references forbidden

## Recommended

- Refactor into functions for reuse
- Error messages to >&2
- Return appropriate exit codes
