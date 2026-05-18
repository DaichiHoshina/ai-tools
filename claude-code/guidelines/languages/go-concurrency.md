# Go並行処理（Goroutine/Channel/sync）深堀り ガイドライン

scheduler動作・channel sizing・leak検出・mutex contention対処が必要な時に参照。基礎は `languages/golang.md`。

## Tier区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | goroutine/scheduler基本、context伝播、`-race`、errgroup |
| Tier 2（規模別） | channel sizing、worker pool、mutex vs atomic、leak検出 |
| Tier 3（深掘り） | go tool trace、mutex contention分析、lock-free、false sharing |

---

## 1. GoroutineとOS thread（M:N scheduler）

| 要素 | 役割 |
|------|------|
| **G** (goroutine) | 軽量、初期stack 2KB、growable |
| **M** (machine = OS thread) | カーネルスレッド |
| **P** (processor = logical CPU) | GをMに割当るスケジューラcontext、`GOMAXPROCS` 個 |

**仕組み**: Gの数 ≫ Mの数。Pがready GをMに割り当て実行。M:N多重化でOS thread切替コスト回避。

| パラメータ | 既定 | 推奨 |
|-----------|------|------|
| `GOMAXPROCS` | Go 1.25+: Linux cgroup CPU limitを考慮 / 1.24以前: 論理CPU数 | Go 1.24以前は `go.uber.org/automaxprocs` でcgroup反映 |
| 初期goroutine stack | 2KB | growable、deep recursionで問題なし |

**注意（Go 1.24以前）**: containerでCPU limit 4 coresでもホスト32coreならGOMAXPROCS=32になる → 過剰並列 → CPU throttleで遅延。Go 1.24以前の本番運用では `automaxprocs` 必須。**Go 1.25+** は標準でcgroup CPU quota反映、`automaxprocs` 不要。

---

## 2. goroutine起動判定

無闇な `go func()` 禁止。下記基準で判定:

| 条件 | 起動可否 |
|------|--------|
| I/O boundで並列価値あり | ✅ 起動 |
| CPU boundで核数並列メリット | ✅ worker poolで限定起動 |
| 同期実行で十分 | ❌ 起動しない |
| 終了/leak管理できない | ❌ context+errgroupで再設計 |
| callerがblockしないfire-and-forget | ⚠️ leakリスク、明示的cancel必須 |

---

## 3. context cancellation伝播

すべてのI/O・長処理はcontext受け取る。cancel時 即座に解放。

```go
func fetch(ctx context.Context, url string) error {
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    resp, err := http.DefaultClient.Do(req)
    // ctx cancel → req 自動中止
}
```

**原則**:
- 関数の第一引数は `ctx context.Context`
- ctxをstruct fieldに保存しない（per-request）
- `context.Background()` はmain/init/testのみ
- timeoutは最上位で `context.WithTimeout`、下流に伝播

---

## 4. errgroup（推奨）

WaitGroupよりerrgroup（`golang.org/x/sync/errgroup`）が現代の標準。

```go
g, ctx := errgroup.WithContext(ctx)
for _, url := range urls {
    g.Go(func() error { return fetch(ctx, url) })
}
if err := g.Wait(); err != nil { return err }  // 1つでも error 全 cancel
```

**メリット**: error集約、context自動cancel、`g.SetLimit(N)` で並列度制限。

---

## 5. Channel sizing

| Buffer | 用途 | 注意 |
|--------|------|------|
| **unbuffered**（`make(chan T)`） | 同期化、handoff | sender/receiver双方ready必要 |
| **buffered N=1** | 結果通知（goroutine 1個） | senderがleakしない保証 |
| **buffered N>1** | producer/consumer速度差吸収 | size根拠を明記、小さく保つ |
| **buffered大** | Queue代替 | ❌ アンチパターン、専用キュー使え |

**判定**: 最初はunbufferedで書き、必要時に最小buffer。「念のため」buffered禁止。

**select non-blocking**:
```go
select {
case msg := <-ch: handle(msg)
default: // ch 空、即進む
}
```

---

## 6. 並行プリミティブ選択

| 状況 | 選択 |
|------|------|
| 値の更新 + 読込 | `sync.Mutex`（書込多）/ `sync.RWMutex`（読多書少） |
| 単一値の読み書き（int/pointer） | `atomic.Int64` / `atomic.Pointer[T]`（lock-free） |
| 1回限りの初期化 | `sync.Once` |
| event通知（broadcast） | `chan struct{}` close + `<-ch` |
| handoff / pipeline | channel |
| 大量goroutine完了待ち | `sync.WaitGroup` or `errgroup` |
| 短命object再利用 | `sync.Pool`（go-performance参照） |

**RWMutex注意**: 読が圧倒的に多い時のみMutexより速い。read比率 < 8割なら通常Mutex推奨（cache line / writer starvation問題）。

---

## 7. Worker Poolパターン

```go
jobs := make(chan Job, 100)
g, ctx := errgroup.WithContext(ctx)
for i := 0; i < runtime.GOMAXPROCS(0); i++ {
    g.Go(func() error {
        for job := range jobs { /* process */ }
        return nil
    })
}
// producer: jobs <- ... ; close(jobs); g.Wait()
```

**ポイント**: worker数 = GOMAXPROCS（CPU bound）or接続数limit（I/O bound）。closeされたらrange終了。

---

## 8. Goroutine Leak検出

**症状**: メモリ漸増、`runtime.NumGoroutine()` 増え続ける、active connection解放されない。

| 検出方法 | 手順 |
|---------|------|
| **pprof goroutine** | `go tool pprof http://localhost:6060/debug/pprof/goroutine` → `top` でstuck stack確認 |
| **runtime.NumGoroutine** | metricとして継続監視、線形増加 = leak |
| **goleakテスト**（`go.uber.org/goleak`） | `defer goleak.VerifyNone(t)` をtest mainに |

**典型leak原因**:
- channel send/recv一方が消えて他方block
- context cancel忘れ
- HTTP body Close忘れ
- ticker.Stop() 忘れ

---

## 9. Race Detector（必須）

```bash
go test -race ./...                  # CI で常時
go run -race ./cmd/server            # local 動作確認
```

**コスト**: メモリ5-10倍、CPU 2-20倍 → 本番不可、CI/devのみ。データレース1つでも検出されたら **必ず修正**（未定義動作）。

---

## 10. Mutex Contention分析

```go
runtime.SetMutexProfileFraction(5)  // 5回に1回sample
// → /debug/pprof/mutex で取得
```

`pprof` で `top` 表示 → contendedなlock特定。対処:
- lock範囲を縮小（critical section最小化）
- shard mutex（`sync.Map` 内部実装）
- atomicに置換可能か検討
- read多 → RWMutex検討（前述の注意あり）

---

## 11. go tool trace（scheduler可視化）

```bash
go test -trace=trace.out -bench=BenchmarkX -run=^$
go tool trace trace.out  # ブラウザで可視化
```

見えるもの: goroutineのCPU上位状態（Running/Runnable/Waiting）、GC pause、syscall blocking、scheduler latency。

**用途**: scheduler不具合（`/sched/latencies` 高い等）原因分析。

---

## 12. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `go func() { ... }()` 裸投げ | errgroup or明示的cancel | leak温床 |
| `time.Sleep` で同期 | channel or sync.Cond | 不確実 |
| buffered channelをqueueとして大量使用 | 専用キュー（NATS/Redis等） | scheduler負荷 |
| 共有mapにMutexなしで書込 | sync.Mutex / sync.Map | データレース |
| context.TODO() 本番残置 | context.Background() or引数受領 | TODOの意図不明 |
| `select { default: }` でbusy loop | timeout / channel block | CPU100% |

---

## 13. 参考

- Go scheduler公式design doc（Dmitry Vyukov）
- `go tool trace` 公式
- Go memory model公式
- `go.uber.org/automaxprocs`、`go.uber.org/goleak`
- 関連: `languages/go-performance.md`（メモリ最適化）、`languages/golang.md`（基礎）、`backend/scalability-patterns.md`（worker pool / backpressure）
