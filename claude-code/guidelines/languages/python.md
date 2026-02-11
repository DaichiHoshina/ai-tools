# Python ガイドライン

Python 3.13対応（2024年10月リリース）。共通ガイドラインは `~/.claude/guidelines/common/` 参照。

---

## 基本原則

- **PEP 8準拠**: スタイルガイド必須
- **型ヒント必須**: `mypy --strict` でチェック
- **明示は暗黙より良い**: Zen of Python
- **ツール**: `ruff`, `black`, `mypy` 推奨
- **仮想環境**: `uv`, `poetry`, `venv` 必須

---

## ディレクトリ構成

- `src/` - ソースコード
- `tests/` - テストコード
- `pyproject.toml` - プロジェクト設定
- `requirements.txt` または `uv.lock` - 依存関係

---

## 型定義

### 基本型ヒント
- `def func(name: str, age: int) -> bool:`
- `list[str]`, `dict[str, int]` (3.9+)
- `str | None` (3.10+) Union型

### 高度な型
- `TypedDict` - 辞書の型定義
- `Protocol` - 構造的サブタイピング
- `Generic[T]` - ジェネリクス
- `Self` (3.11+) - 自己参照型

---

## 命名規則

- **モジュール/パッケージ**: `snake_case`
- **クラス**: `PascalCase`
- **関数/変数**: `snake_case`
- **定数**: `UPPER_SNAKE_CASE`
- **プライベート**: `_prefix`

---

## クイックリファレンス

### エラー処理

| パターン | コード | 用途 |
|---------|--------|------|
| 基本 | `try: ... except Exception as e: ...` | 例外捕捉 |
| 再発行 | `raise RuntimeError("msg") from e` | チェーン |
| カスタム | `class CustomError(Exception): ...` | 独自例外 |
| コンテキスト | `with open(f) as fp: ...` | リソース管理 |

### 非同期処理

| パターン | コード | 用途 |
|---------|--------|------|
| async関数 | `async def fetch(): ...` | 非同期定義 |
| await | `result = await fetch()` | 非同期呼び出し |
| 並行実行 | `await asyncio.gather(*tasks)` | 同時実行 |
| タイムアウト | `async with asyncio.timeout(5):` (3.11+) | 制限時間 |

### テスト

| パターン | コード | 用途 |
|---------|--------|------|
| 基本 | `def test_func():` | pytest |
| フィクスチャ | `@pytest.fixture` | テスト前処理 |
| パラメータ化 | `@pytest.mark.parametrize` | 複数ケース |
| モック | `from unittest.mock import Mock` | テストダブル |

## よくあるミス

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `except:` (裸) | `except Exception:` | BaseException捕捉防止 |
| `from module import *` | 明示的インポート | 名前空間汚染 |
| `def f(lst=[]):` | `def f(lst=None):` | ミュータブルデフォルト |
| グローバル変数 | 依存性注入 | テスタビリティ |
| `type: ignore` 乱用 | 適切な型定義 | 型安全性 |

---

## 古いパターン検出（レビュー/実装時チェック）

`pyproject.toml` の `requires-python` または実行バージョンを確認してから指摘する。

### 🔴 Critical（必ず指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `typing.Optional[X]` | `X \| None` | 3.10 |
| `typing.Union[X, Y]` | `X \| Y` | 3.10 |
| `typing.List[str]`, `typing.Dict[str, int]` | `list[str]`, `dict[str, int]` | 3.9 |
| `typing.Tuple`, `typing.Set`, `typing.FrozenSet` | `tuple`, `set`, `frozenset` | 3.9 |
| `% formatting` / `.format()` | f-string `f"..."` | 3.6 |
| `setup.py` / `setup.cfg` | `pyproject.toml` | PEP 621 |
| `pip install` + `requirements.txt` のみ | `uv` / `poetry` でロックファイル管理 | 推奨 |

### 🟡 Warning（積極的に指摘）

| ❌ 古い | ✅ モダン | Since |
|---------|----------|-------|
| `TypeAlias = Union[...]` 変数 | `type` 文 (`type Alias = X \| Y`) | 3.12 |
| `typing.TypeGuard` | `typing.TypeIs`（より正確な型ナローイング） | 3.13 |
| `os.path.join()` | `pathlib.Path` | 3.4 |
| `urllib.request` | `httpx` or `requests` | 推奨 |
| `print()` デバッグ | `logging` / `structlog` | 推奨 |
| `@staticmethod` で代用 | モジュールレベル関数 | Pythonic |
| `asyncio.gather()` | `asyncio.TaskGroup()` | 3.11 |
| `asyncio.wait_for(coro, timeout)` | `async with asyncio.timeout(n):` | 3.11 |
| 自己参照型に `"ClassName"` 文字列 | `Self` 型 | 3.11 |
| `try/except` で例外まとめ処理 | `ExceptionGroup` + `except*` | 3.11 |
| `dict` で型付き辞書 | `TypedDict` | 3.8 |
| `dataclass` なしの手動 `__init__` | `@dataclass` or `pydantic.BaseModel` | 3.7 |

### ℹ️ Info（提案レベル）

| 項目 | 内容 | Since |
|------|------|-------|
| Free-threaded mode | GIL無効化実験（`--disable-gil`） | 3.13 |
| `copy.replace()` | オブジェクト部分コピー | 3.13 |
| Per-Interpreter GIL | サブインタープリタ毎の独立GIL | 3.12 |

---

## フレームワーク

| フレームワーク | ポイント |
|--------------|---------|
| FastAPI | Pydantic BaseModel + 型ヒント、`Depends` でDI |
| Django | `manage.py check --deploy`、QuerySet 遅延評価 |
