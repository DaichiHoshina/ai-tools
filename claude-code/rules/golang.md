---
paths:
  - "**/*.go"
---
# Golang Rules

## Error Handling

- Always handle errors (no `_` ignoring)
- Add context with errors.Wrap/Wrapf
- Compare sentinel errors with errors.Is

## Naming

- Package names: lowercase single words
- Exported: PascalCase
- Unexported: camelCase
- Acronyms: all caps (HTTP, ID, URL)

## Concurrency

- Prevent goroutine leaks (use context)
- Channel creator closes channel
- Manage lifecycle with sync.WaitGroup/errgroup

## Logging

- Log **once at error origin**. If returning err, caller must not re-log
- ErrNotFound needs no log (normal case). Repository returns as-is
- UseCase layer decides if NotFound is exceptional

## Testing

- table-driven tests recommended
- Helpers call t.Helper()
- Flakiness details: `guidelines/languages/go-test-stability.md`

## Detailed Guidelines

Patterns, generics, architecture → `guidelines/languages/golang.md` (auto-load via `/load-guidelines full`)

## 失敗パターンカタログ

Go 頻出の落とし穴を 10 件まとめた。実装前と review 時の self-check に使う。

| 症状 | ありがちな誤り | 正しい一手 |
|---|---|---|
| goroutine leak | 受信者不在の channel へ送信する goroutine を放置する | context cancel か buffered channel + select で送信側に脱出路を作る |
| nil map への書込 panic | `var m map[string]int` のまま `m[k] = v` する | `make(map[string]int)` か composite literal で初期化してから書き込む |
| loop 変数 capture (Go 1.21 以前) | `for _, v := range xs { go f(v) }` で全 goroutine が最終値を掴む | loop 内で `v := v` と再宣言するか、引数として渡す (Go 1.22+ は per-iteration scope) |
| err shadow | `if err := f(); err != nil` の後、外側 err を `:=` で再宣言して握り潰す | 内側 block では `=` で代入するか、変数名を分けて lint (`govet shadow`) で検出する |
| defer の loop 内多用 | loop 内で `defer f.Close()` を積み、関数終了まで resource が解放されない | loop body を関数に切り出して defer を関数 scope に閉じ込める |
| slice の共有 backing array 破壊 | `s2 := s1[:n]` へ append して s1 の要素を上書きする | full slice expression (`s1[:n:n]`) か `slices.Clone` で backing array を分離する |
| context cancel 漏れ | `context.WithTimeout` の cancel を呼ばず内部 timer / goroutine が残る | `ctx, cancel := ...` の直後に `defer cancel()` を必ず置く |
| WaitGroup の Add 位置ミス | goroutine 内部で `wg.Add(1)` して Wait との race になる | goroutine 起動前 (親側) で Add してから `go func()` を起動する |
| interface nil 比較の罠 (typed nil) | `*MyErr` の nil を error で返し `err != nil` が true になる | error を返す関数は具象 pointer 型でなく明示的に `return nil` する |
| time.After の loop 内 leak (Go 1.22 以前) | loop 内 select で `time.After` を毎回生成して timer を溜める | `time.NewTimer` を loop 外で作り `Reset` で再利用する (Go 1.23+ は GC 回収されるが可読性のため同様に) |

channel の二重 close panic も頻出するが、「channel creator closes channel」(§ Concurrency) を守れば構造的に防げる。
