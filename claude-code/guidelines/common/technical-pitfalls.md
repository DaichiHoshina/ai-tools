# Technical Pitfalls

Collection of implementation patterns to avoid: implementation without design, regression-inducing changes, etc. Reference as a self-check before starting new features or during code review.

## Absolutely Forbidden Patterns

| Pattern | Forbidden | Correct |
|---------|-----------|---------|
| Implementation without design | Designing while implementing / "make it work first" / "fix later" | Complete design → then implement |
| Regression prevention | Changing existing props/function signatures/CSS class names | New features use new components; existing ones extend only |
| Validation | Designing while implementing | Spec first → define rules in `rules/` → verify with tests |

---

## Specific Pitfalls

| Item | Counter-measure |
|------|----------------|
| Coordinate calculations | Clarify with conversion functions (prevent mixed coordinate systems) |
| Action types | Unify values (prevent mixing `text` and `message`) |
| Validation keys | Map rule names to message keys |

---

## Past Mistakes

| Mistake | Cause | Counter-measure |
|---------|-------|----------------|
| lint fix repeated 3 times | Dev environment not set up | Set up dev environment, pre-commit hook |
| Regression occurred twice | Impact scope not understood | Understand impact scope, run tests |
| Validation design changed 5 times | No spec doc | Write spec first |
| Large amount of unnecessary code deleted | Over-implementation | Implement only currently needed features |
