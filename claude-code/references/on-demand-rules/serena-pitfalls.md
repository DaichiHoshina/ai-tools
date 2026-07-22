# Serena MCP の罠

`mcp__serena__*` tool を使う前に読む。

## 1. ai-tools repo で claude-code/ 配下は ignore される

ai-tools repo で `mcp__serena__*` symbol / insert / replace 系 tool を `claude-code/` 配下 file に発火すると `ValueError: Explicitly requested symbols in '<path>' while the path is ignored` で失敗する。`.gitignore` か `.serena/project.yml` の ignore 設定に由来する (未追跡 config)。

**Why**: 2026-07-20 の reviewer-agent.md 編集で `insert_after_symbol` が上記 error で fail し、Edit tool に fallback した。CLAUDE.md 「Serena 必須化」は「code 関連 tool の前に initial_instructions を呼ぶ」だが、ignore された path では Serena instruction 通りに動かせず built-in tool 使用が正当。

**How to apply**:
1. `claude-code/` 配下 (`agents/` `hooks/` `commands/` `skills/` `scripts/` 等) を編集するときは Serena symbol tool を試さず、最初から Read + Edit / Write / Bash で操作する
2. `docs/` `memory/` 配下は Serena OK (ignore 対象外)
3. error 出た時は path が claude-code/ 配下かを確認して即 Edit fallback、Serena の再試行を繰り返さない
4. 恒久解: `.serena/project.yml` を見て ignore rule を明示する (未着手)

## 2. replace_content の regex 置換で helper 定義本体を巻き込む

同一 file 内に helper 定義と call site の両方があるとき、`funcName\(([^)]+)\)` のような regex で call site を一括置換すると、`func funcName(param type)` の定義側も match して壊れる。

Go の例。`strPtr(s string) *string` を Go 1.26 `new(string(...))` に swap したい。`strPtr\(([^)]+)\)` → `new(string($!1))` の全置換で `func new(string(s string)) *string` の壊れた定義が生まれる (`s string` が引数リストと解釈される)。build tool は素通りし、tail や grep で目視発見するしかない。

**Why**: call site と定義が同 file にある時、`func name(param list)` の内部 param list も needle pattern に一致する。「call site だけ書き換える」意図は regex に反映されず、Serena は plain regex なので単純 match で全て置換する。build が通ることがあるため気付きにくい。

**How to apply**:

- **推奨: 定義を消してから call site 置換に入る**。定義行が残っていなければ collision の余地は生まれない
- **代替: negative look-behind で `func` を除外する**。`(?<!func\s)funcName\(([^)]+)\)` のようにする (Python re の DOTALL/MULTILINE 前提で動く)
- **併用: 置換後に必ず build + tail -20 で file 末尾を目視する**。`go build ./...` は param list が構造的に正しければ通ってしまう
- **cast 二重回避**: `intPtr(int(x))` → `new(int(x))` のように内側 cast を保つ場合、専用 regex `intPtr\(int\(([^)]+)\)\)` → `new(int($!1))` を先に走らせてから `intPtr\(([^)]+)\)` → `new(int($!1))` の順で置換する。逆順だと `new(int(int(x)))` になる

## 関連

- `~/ai-tools/memory/feedback_serena_replace_regex_dotall.md` — regex DOTALL/MULTILINE 強制
- `references/serena-tool-map.md` — Serena tool 一覧
