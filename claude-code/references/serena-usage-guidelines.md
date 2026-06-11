# Serena MCP 利用 guideline

Serena tool 利用時の事故予防 rule。dotall greedy 事故 (2026-05-18) の補完。

## search_for_pattern: 1 行スコープ search では `multiline=False` 明示

v1.5.0 で `multiline=False` opt-out が追加された (default は `multiline=True` で `re.DOTALL|MULTILINE` 有効)。

- **rule**: 検索対象が **1 行内で完結** することが明確な場合、`multiline=False` を明示指定する。`.*` が改行を跨いで greedy 過食するリスクを構造的に排除する。
- **適用例**: variable 名 / function 名 / 1 行 config 値 / import 文 1 行 / annotation 1 行
- **非適用例 (multiline=True 維持)**: function body / class body / multi-line config block の検索

**Why**: 2026-05-18 dotall greedy 事故と同パターンを `search_for_pattern` 側でも再発させない。`replace_content` の dotall hardcode (Tool API 制約) を回避できない以上、search 側で先に scope を絞る。

## replace_content: ambiguity error 発火時の即時対処

v1.5.0 で `ContentReplacer.replace()` がマッチ内に同パターン再出現する場合 `ValueError("Match is ambiguous: ...")` を返すよう改善された。

- **error 文言検出時の対処手順**:
  1. **literal mode 切替**: regex meta char を全て escape し、対象文字列を literal 一致で指定する。
  2. **終端 anchor 明示**: `.*?` (non-greedy) + 明示的 end anchor (改行リテラル `\n` / 隣接の不変文字列) を組み合わせる。
  3. **scope 縮小**: 1 file 内の複数箇所がマッチするなら `find_symbol` で symbol 単位 edit へ切替える (`replace_symbol_body` / `insert_after_symbol` 等)。

**Why**: 2026-05-18 dotall greedy 事故 (greedy `.*\n` が 5 file 横断で発火) の自動検出を Serena 側が肩代わりするようになったため、error 発生時に手探りで regex 改修する代わりに上記 3 手順を即時切替できる体制を作る。

