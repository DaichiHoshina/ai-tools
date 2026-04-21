# Go 並行処理（Goroutine/Channel/sync）深堀り ガイドライン

scheduler動作・channel sizing・leak検出・mutex contention 対処が必要な時に参照。基礎は `languages/golang.md`。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | goroutine/scheduler基本、context伝播、`-race`、errgroup |
| Tier 2（規模別） | channel sizing、worker pool、mutex vs atomic、leak検出 |
| Tier 3（深掘り） | go tool trace、mutex contention分析、lock-free、false sharing |

---

## 1. Goroutine と OS thread（M:N scheduler）

| 要素 | 役割 |
|------|------|
| **G** (goroutine) | 軽量、初期stack 2KB、growable |
| **M** (machine = OS thread) | カーネルスレッド |
| **P** (processor = logical CPU) | G を M に割当るスケジューラ context、`GOMAXPROCS` 個 |

**仕組み**: G の数 ≫ M の数。P が ready G を M に割り当て実行。M:N 多重化で OS thread 切替コスト回避。

| パラメータ | 既定 | 推奨 |
|-----------|------|------|
| `GOMAXPROCS` | Go 1.25+: Linux cgroup CPU limit を考慮 / 1.24以前: 論理CPU数 | Go 1.24以前は `go.uber.org/automaxprocs` で cgroup 反映 |
| 初期 goroutine stack | 2KB | growable、deep recursion で問題なし |

**注意（Go 1.24以前）**: container で CPU limit 4 cores でもホスト32coreなら GOMAXPROCS=32 になる → 過剰並列 → CPU throttle で遅延。Go 1.24 以前の本番運用では `automaxprocs` 必須。**Go 1.25+** は標準で cgroup CPU quota 反映、`automaxprocs` 不要。

---

## 2. goroutine 起動判定

無闇な `go func()` 禁止。下記基準で判定:

| 条件 | 起動可否 |
|------|--------|
| I/O bound で並列価値あり | ✅ 起動 |
| CPU bound で核数並列メリット | ✅ worker pool で限定起動 |
| 同期実行で十分 | ❌ 起動しない |
| 終了/leak 管理できない | ❌ context+errgroup で再設計 |
| caller がblockしない fire-and-forget | ⚠️ leak リスク、明示的 cancel 必須 |

---

## 3. context cancellation 伝播

すべての I/O・長処理は context 受け取る。cancel 時 即座に解放。

```go
func fetch(ctx context.Context, url string) error {
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    resp, err := http.DefaultClient.Do(req)
    // ctx cancel → req 自動中止
}
```

**原則**:
- 関数の第一引数は `ctx context.Context`
- ctx を struct field に保存しない（per-request）
- `context.Background()` は main/init/test のみ
- timeout は最上位で `context.WithTimeout`、下流に伝播

---

## 4. errgroup（推奨）

WaitGroup より errgroup（`golang.org/x/sync/errgroup`）が現代の標準。

```go
g, ctx := errgroup.WithContext(ctx)
for _, url := range urls {
    g.Go(func() error { return fetch(ctx, url) })
}
if err := g.Wait(); err != nil { return err }  // 1つでも error 全 cancel
```

**メリット**: error 集約、context 自動 cancel、`g.SetLimit(N)` で並列度制限。

---

## 5. Channel sizing

| Buffer | 用途 | 注意 |
|--------|------|------|
| **unbuffered**（`make(chan T)`） | 同期化、handoff | sender/receiver 双方 ready 必要 |
| **buffered N=1** | 結果通知（goroutine 1個） | sender が leak しない保証 |
| **buffered N>1** | producer/consumer 速度差吸収 | size 根拠を明記、小さく保つ |
| **buffered 大** | Queue 代替 | ❌ アンチパターン、専用キュー使え |

**判定**: 最初は unbuffered で書き、必要時に最小 buffer。「念のため」buffered 禁止。

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
| event 通知（broadcast） | `chan struct{}` close + `<-ch` |
| handoff / pipeline | channel |
| 大量 goroutine 完了待ち | `sync.WaitGroup` or `errgroup` |
| 短命object 再利用 | `sync.Pool`（go-performance参照） |

**RWMutex 注意**: 読が圧倒的に多い時のみ Mutex より速い。read 比率 < 8割なら通常 Mutex 推奨（cache line / writer starvation問題）。

---

## 7. Worker Pool パターン

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

**ポイント**: worker 数 = GOMAXPROCS（CPU bound）or 接続数 limit（I/O bound）。close されたら range 終了。

---

## 8. Goroutine Leak 検出

**症状**: メモリ漸増、`runtime.NumGoroutine()` 増え続ける、active connection 解放されない。

| 検出方法 | 手順 |
|---------|------|
| **pprof goroutine** | `go tool pprof http://localhost:6060/debug/pprof/goroutine` → `top` で stuck stack確認 |
| **runtime.NumGoroutine** | metric として継続監視、線形増加 = leak |
| **goleak テスト**（`go.uber.org/goleak`） | `defer goleak.VerifyNone(t)` を test main に |

**典型 leak 原因**:
- channel send/recv 一方が消えて他方 block
- context cancel 忘れ
- HTTP body Close 忘れ
- ticker.Stop() 忘れ

---

## 9. Race Detector（必須）

```bash
go test -race ./...                  # CI で常時
go run -race ./cmd/server            # local 動作確認
```

**コスト**: メモリ 5-10倍、CPU 2-20倍 → 本番不可、CI/dev のみ。データレース1つでも検出されたら **必ず修正**（未定義動作）。

---

## 10. Mutex Contention 分析

```go
runtime.SetMutexProfileFraction(5)  // 5回に1回sample
// → /debug/pprof/mutex で取得
```

`pprof` で `top` 表示 → contended な lock 特定。対処:
- lock 範囲を縮小（critical section最小化）
- shard mutex（`sync.Map` 内部実装）
- atomic に置換可能か検討
- read 多 → RWMutex 検討（前述の注意あり）

---

## 11. go tool trace（scheduler可視化）

```bash
go test -trace=trace.out -bench=BenchmarkX -run=^$
go tool trace trace.out  # ブラウザで可視化
```

見えるもの: goroutine のCPU上位状態（Running/Runnable/Waiting）、GC pause、syscall blocking、scheduler latency。

**用途**: scheduler 不具合（`/sched/latencies` 高い等）原因分析。

---

## 12. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `go func() { ... }()` 裸投げ | errgroup or 明示的 cancel | leak温床 |
| `time.Sleep` で同期 | channel or sync.Cond | 不確実 |
| buffered channel をqueueとして大量使用 | 専用キュー（NATS/Redis等） | scheduler負荷 |
| 共有 map に Mutex なしで書込 | sync.Mutex / sync.Map | データレース |
| context.TODO() 本番残置 | context.Background() or 引数受領 | TODO の意図不明 |
| `select { default: }` で busy loop | timeout / channel block | CPU100% |

---

## 13. 参考

- Go scheduler 公式 design doc（Dmitry Vyukov）
- `go tool trace` 公式
- Go memory model 公式
- `go.uber.org/automaxprocs`、`go.uber.org/goleak`
- 関連: `languages/go-performance.md`（メモリ最適化）、`languages/golang.md`（基礎）、`backend/scalability-patterns.md`（worker pool / backpressure）
