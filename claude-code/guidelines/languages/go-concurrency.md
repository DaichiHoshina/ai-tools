# Go Concurrency (Goroutine/Channel/sync) Guidelines

Reference when scheduler behavior, channel sizing, leak detection, or mutex contention analysis is needed. Basics: `languages/golang.md`.

## Tiers

| Tier | Content |
|------|---------|
| Tier 1 (required) | goroutine/scheduler basics, context propagation, `-race`, errgroup |
| Tier 2 (scale-dependent) | channel sizing, worker pool, mutex vs atomic, leak detection |
| Tier 3 (deep dive) | go tool trace, mutex contention analysis, lock-free, false sharing |

---

## 1. Goroutine and OS Thread (M:N Scheduler)

| Element | Role |
|---------|------|
| **G** (goroutine) | lightweight, initial stack 2KB, growable |
| **M** (machine = OS thread) | kernel thread |
| **P** (processor = logical CPU) | scheduler context that assigns G to M; `GOMAXPROCS` count |

**How it works**: G count >> M count. P assigns ready G to M for execution. M:N multiplexing avoids OS thread switch cost.

| Parameter | Default | Recommended |
|-----------|---------|-------------|
| `GOMAXPROCS` | Go 1.25+: accounts for Linux cgroup CPU limit / pre-1.24: logical CPU count | pre-1.24: use `go.uber.org/automaxprocs` for cgroup-aware value |
| Initial goroutine stack | 2KB | growable; deep recursion is fine |

**Note (pre-Go 1.24)**: in a container with CPU limit 4 but host with 32 cores, GOMAXPROCS=32 → over-parallelism → CPU throttle lag. Use `automaxprocs` in pre-1.24 production. **Go 1.25+** reflects cgroup CPU quota natively; `automaxprocs` is unnecessary.

---

## 2. Goroutine Launch Decision

Avoid indiscriminate `go func()`. Use these criteria:

| Condition | Launch? |
|-----------|---------|
| I/O bound with parallelism benefit | ✅ launch |
| CPU bound with multi-core benefit | ✅ limited via worker pool |
| Synchronous execution is sufficient | ❌ do not launch |
| Cannot manage termination/leak | ❌ redesign with context+errgroup |
| Fire-and-forget (caller does not block) | ⚠️ leak risk; explicit cancel required |

---

## 3. Context Cancellation Propagation

All I/O and long-running operations must accept context. Release immediately on cancel.

```go
func fetch(ctx context.Context, url string) error {
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    resp, err := http.DefaultClient.Do(req)
    // ctx cancel → req 自動中止
}
```

**Rules**:
- First argument is `ctx context.Context`
- Do not store ctx in struct fields (per-request)
- `context.Background()` only in main/init/test
- Set timeout at top-level with `context.WithTimeout`; propagate downstream

---

## 4. errgroup (recommended)

errgroup (`golang.org/x/sync/errgroup`) is the modern standard over WaitGroup.

```go
g, ctx := errgroup.WithContext(ctx)
for _, url := range urls {
    g.Go(func() error { return fetch(ctx, url) })
}
if err := g.Wait(); err != nil { return err }  // 1つでも error 全 cancel
```

**Benefits**: error aggregation, automatic context cancel, `g.SetLimit(N)` for concurrency control.

---

## 5. Channel Sizing

| Buffer | Use | Note |
|--------|-----|------|
| **unbuffered** (`make(chan T)`) | synchronization, handoff | both sender/receiver must be ready |
| **buffered N=1** | result notification (1 goroutine) | guarantees sender does not leak |
| **buffered N>1** | absorb producer/consumer speed mismatch | document size rationale; keep small |
| **buffered large** | queue replacement | ❌ anti-pattern; use a dedicated queue |

**Rule**: start with unbuffered; add minimal buffer only when needed. "Just in case" buffering is forbidden.

**select non-blocking**:
```go
select {
case msg := <-ch: handle(msg)
default: // ch 空、即進む
}
```

---

## 6. Concurrency Primitive Selection

| Situation | Choice |
|-----------|--------|
| Value update + read | `sync.Mutex` (write-heavy) / `sync.RWMutex` (read-heavy, write-light) |
| Single value read/write (int/pointer) | `atomic.Int64` / `atomic.Pointer[T]` (lock-free) |
| One-time initialization | `sync.Once` |
| Event notification (broadcast) | `chan struct{}` close + `<-ch` |
| Handoff / pipeline | channel |
| Wait for many goroutines | `sync.WaitGroup` or `errgroup` |
| Short-lived large object reuse | `sync.Pool` (see go-performance) |

**RWMutex note**: only faster than Mutex when reads are overwhelmingly dominant. If read ratio < 80%, prefer plain Mutex (cache line / writer starvation issues).

---

## 7. Worker Pool Pattern

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

**Key points**: worker count = GOMAXPROCS (CPU bound) or connection limit (I/O bound). Range terminates when channel is closed.

---

## 8. Goroutine Leak Detection

**Symptoms**: gradual memory growth, `runtime.NumGoroutine()` keeps increasing, active connections not released.

| Detection method | Steps |
|------------------|-------|
| **pprof goroutine** | `go tool pprof http://localhost:6060/debug/pprof/goroutine` → `top` to check stuck stacks |
| **runtime.NumGoroutine** | monitor as a metric; linear growth = leak |
| **goleak test** (`go.uber.org/goleak`) | `defer goleak.VerifyNone(t)` in test main |

**Typical leak causes**:
- One side of channel send/recv is gone, blocking the other
- Forgot to cancel context
- Forgot to close HTTP body
- Forgot `ticker.Stop()`

---

## 9. Race Detector (required)

```bash
go test -race ./...                  # CI で常時
go run -race ./cmd/server            # local 動作確認
```

**Cost**: 5-10x memory, 2-20x CPU → not for production, CI/dev only. Any detected data race **must be fixed** (undefined behavior).

---

## 10. Mutex Contention Analysis

```go
runtime.SetMutexProfileFraction(5)  // 5回に1回sample
// → /debug/pprof/mutex で取得
```

Run `pprof` `top` to identify contended locks. Remedies:
- Narrow lock scope (minimize critical section)
- Shard mutex (like `sync.Map` internal implementation)
- Consider replacing with atomic
- Read-heavy → consider RWMutex (see caveats above)

---

## 11. go tool trace (Scheduler Visualization)

```bash
go test -trace=trace.out -bench=BenchmarkX -run=^$
go tool trace trace.out  # ブラウザで可視化
```

Shows: goroutine CPU states (Running/Runnable/Waiting), GC pauses, syscall blocking, scheduler latency.

**Use case**: diagnosing scheduler issues (e.g., high `/sched/latencies`).

---

## 12. Anti-patterns

| Avoid | Use | Reason |
|-------|-----|--------|
| `go func() { ... }()` bare launch | errgroup or explicit cancel | leak-prone |
| `time.Sleep` for synchronization | channel or sync.Cond | unreliable |
| Large buffered channel as queue | dedicated queue (NATS/Redis etc.) | scheduler overhead |
| Write to shared map without Mutex | sync.Mutex / sync.Map | data race |
| `context.TODO()` left in production | `context.Background()` or accept as argument | unclear intent |
| `select { default: }` busy loop | timeout / channel block | 100% CPU |

---

## 13. References

- Go scheduler official design doc (Dmitry Vyukov)
- `go tool trace` official docs
- Go memory model official docs
- `go.uber.org/automaxprocs`, `go.uber.org/goleak`
- Related: `languages/go-performance.md` (memory optimization), `languages/golang.md` (basics), `backend/scalability-patterns.md` (worker pool / backpressure)
