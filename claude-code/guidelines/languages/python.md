# Python Guidelines

Python 3.14.6 (released 2026-06-10). Common guidelines: `~/.claude/guidelines/common/`.

---

## Core Principles

- **PEP 8 compliance**: required
- **Type hints required**: check with `mypy --strict`
- **Explicit over implicit**: Zen of Python
- **Tools**: `ruff`, `black`, `mypy` recommended
- **Virtual environments**: `uv`, `poetry`, `venv` required

---

## Directory Structure

- `src/` — source code
- `tests/` — test code
- `pyproject.toml` — project config
- `requirements.txt` or `uv.lock` — dependencies

---

## Type Definitions

### Basic Type Hints
- `def func(name: str, age: int) -> bool:`
- `list[str]`, `dict[str, int]` (3.9+)
- `str | None` (3.10+) union type

### Advanced Types
- `TypedDict` — typed dict definitions
- `Protocol` — structural subtyping
- `Generic[T]` — generics
- `Self` (3.11+) — self-referential type

---

## Naming Conventions

- **Module/Package**: `snake_case`
- **Class**: `PascalCase`
- **Function/Variable**: `snake_case`
- **Constant**: `UPPER_SNAKE_CASE`
- **Private**: `_prefix`

---

## Quick Reference

### Error Handling

| Pattern | Code | Use |
|---------|------|-----|
| Basic | `try: ... except Exception as e: ...` | catch exceptions |
| Re-raise | `raise RuntimeError("msg") from e` | chain |
| Custom | `class CustomError(Exception): ...` | custom exceptions |
| Context | `with open(f) as fp: ...` | resource management |

### Async Processing

| Pattern | Code | Use |
|---------|------|-----|
| async function | `async def fetch(): ...` | async definition |
| await | `result = await fetch()` | async call |
| Concurrent | `await asyncio.gather(*tasks)` | parallel execution |
| Timeout | `async with asyncio.timeout(5):` (3.11+) | time limit |

### Testing

| Pattern | Code | Use |
|---------|------|-----|
| Basic | `def test_func():` | pytest |
| Fixture | `@pytest.fixture` | test setup |
| Parametrize | `@pytest.mark.parametrize` | multiple cases |
| Mock | `from unittest.mock import Mock` | test doubles |

## Common Mistakes

| Avoid | Use | Reason |
|-------|-----|--------|
| `except:` (bare) | `except Exception:` | prevents BaseException capture |
| `from module import *` | explicit imports | namespace pollution |
| `def f(lst=[]):` | `def f(lst=None):` | mutable default |
| global variables | dependency injection | testability |
| `type: ignore` overuse | proper type definitions | type safety |

---

## Deprecated Pattern Detection (review / implementation)

Check `pyproject.toml` `requires-python` or runtime version before flagging.

### Critical (always flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `typing.Optional[X]` | `X \| None` | 3.10 |
| `typing.Union[X, Y]` | `X \| Y` | 3.10 |
| `typing.List[str]`, `typing.Dict[str, int]` | `list[str]`, `dict[str, int]` | 3.9 |
| `typing.Tuple`, `typing.Set`, `typing.FrozenSet` | `tuple`, `set`, `frozenset` | 3.9 |
| `% formatting` / `.format()` | f-string `f"..."` | 3.6 |
| `setup.py` / `setup.cfg` | `pyproject.toml` | PEP 621 |
| `pip install` + `requirements.txt` only | `uv` / `poetry` with lock file | recommended |

### Warning (proactively flag)

| Deprecated | Modern | Since |
|------------|--------|-------|
| `TypeAlias = Union[...]` variable | `type` statement (`type Alias = X \| Y`) | 3.12 |
| `typing.TypeGuard` | `typing.TypeIs` (more precise type narrowing) | 3.13 |
| `os.path.join()` | `pathlib.Path` | 3.4 |
| `urllib.request` | `httpx` or `requests` | recommended |
| `print()` debugging | `logging` / `structlog` | recommended |
| `@staticmethod` as substitute | module-level function | Pythonic |
| `asyncio.gather()` | `asyncio.TaskGroup()` | 3.11 |
| `asyncio.wait_for(coro, timeout)` | `async with asyncio.timeout(n):` | 3.11 |
| `"ClassName"` string for self-referential type | `Self` type | 3.11 |
| `try/except` grouping exceptions | `ExceptionGroup` + `except*` | 3.11 |
| `dict` for typed dict | `TypedDict` | 3.8 |
| Manual `__init__` without dataclass | `@dataclass` or `pydantic.BaseModel` | 3.7 |

### Info (suggestion level)

| Item | Detail | Since |
|------|--------|-------|
| Free-threaded mode | GIL disable experiment (`--disable-gil`) | 3.13 |
| `copy.replace()` | partial object copy | 3.13 |
| Per-Interpreter GIL | independent GIL per sub-interpreter | 3.12 |

---

## Frameworks

| Framework | Key Points |
|-----------|-----------|
| FastAPI | Pydantic BaseModel + type hints, DI via `Depends` |
| Django | `manage.py check --deploy`, QuerySet lazy evaluation |
