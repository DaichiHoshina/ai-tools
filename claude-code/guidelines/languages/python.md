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

| 避ける | 使う | 理由 |
|-------|------|------|
| `except:` (裸) | `except Exception:` | BaseException捕捉防止 |
| `from module import *` | 明示的インポート | 名前空間汚染 |
| `def f(lst=[]):` | `def f(lst=None):` | ミュータブルデフォルト |
| グローバル変数 | 依存性注入 | テスタビリティ |
| `type: ignore` 乱用 | 適切な型定義 | 型安全性 |

---

## バージョン別新機能

**3.13 (2024/10)**:
- 新しいインタラクティブインタプリタ (REPL改善)
- `typing.TypeIs` - 型ガード改善
- GIL無効化実験 (free-threaded mode)
- `copy.replace()` - オブジェクト部分コピー

**3.12 (2023/10)**:
- f-string改善 (ネスト対応)
- `type` 文 (型エイリアス簡略化)
- Per-Interpreter GIL

**3.11 (2022/10)**:
- 例外グループ
- `Self` 型
- `asyncio.TaskGroup`

---

## フレームワーク別

### FastAPI
```python
from fastapi import FastAPI, Depends
from pydantic import BaseModel

app = FastAPI()

class Item(BaseModel):
    name: str
    price: float

@app.post("/items/")
async def create_item(item: Item) -> Item:
    return item
```

### Django
- `settings.py` でDEBUG=False本番
- `manage.py check --deploy` でセキュリティ確認
- QuerySet は遅延評価
