---
paths:
  - "**/*.{ts,tsx}"
---
# TypeScript Rules

## Type Safety

- any forbidden
- Minimize as casts
- Prefer unknown + type guards
- Assume strictNullChecks

## Naming

- Variables: camelCase
- Constants: UPPER_SNAKE_CASE
- Classes/types: PascalCase

## Imports

- Relative: same directory only
- Otherwise: use alias (@/)

## Error Handling

- Result type preferred (neverthrow etc)
- try-catch at system boundaries only

## ESLint

Details: `guidelines/languages/eslint.md`

## Detailed Guidelines

Type systems, functional patterns, async → `guidelines/languages/typescript.md` (auto-load via `/load-guidelines full`)

## 失敗パターンカタログ

TS 実装で頻出する落とし穴を 10 件まとめる。実装前と review 時の self-check に使う。

| 症状 | ありがちな誤り | 正しい一手 |
|---|---|---|
| 型 error が消えない | `any` に逃げて型検査を無効化する | `unknown` + type guard で絞り込む |
| union 型の分岐漏れ | 一部 variant だけ処理して残りを素通しする | 判別 union + narrowing で全 variant を分岐する |
| async 処理が完了前に先へ進む | `await` 忘れで floating promise を放置する | `await` を付ける、`no-floating-promises` lint を有効化する |
| 並列処理の一部失敗で全体が reject する | `Promise.all` で部分失敗を考慮しない | `Promise.allSettled` で個別結果を判定する |
| `undefined` 参照で実行時 crash する | optional chaining の直後に `!` (非 null assertion) を重ねる | `?.` の結果を early return や default 値で処理する |
| enum と literal の型が噛み合わない | enum と union literal を混在させて比較・変換する | union literal (`as const`) に統一する |
| copy 後の変更が元 object に波及する | nested object を spread で shallow copy する | `structuredClone` で deep copy する |
| 新 variant 追加時に switch が沈黙する | exhaustiveness check なしで `default` に流す | `default` で `never` 代入 (exhaustive check) を入れる |
| 型は通るのに実行時に値が壊れる | `as` assertion で不正な型を強制する | type guard 関数 or zod 等の runtime validation で検証する |
| `Object.keys` の戻りで key 型が消える | `string[]` のまま index access して型 error / `as` 濫用する | key を union に絞る helper (`keys<T>()`) or `Map` を使う |
