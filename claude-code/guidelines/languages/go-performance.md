# Go Performance Guidelines

Reference for CPU/memory optimization, allocation reduction, and PGO. Basics: `languages/golang.md`.

## Tiers

| Tier | Content |
|------|---------|
| Tier 1 (required) | escape analysis, benchmarks, pprof CPU/heap |
| Tier 2 (scale-dependent) | sync.Pool, zero-copy, map preallocation, inline budget |
| Tier 3 (deep dive) | PGO, GOGC/GOMEMLIMIT, runtime/metrics, flame graphs |

---

## 1. "Go is slow" 5-Step Diagnosis

| Step | Check | Command |
|------|-------|---------|
| 1 | get benchmark | `go test -bench=. -benchmem -count=10` |
| 2 | CPU profile | `go test -cpuprofile=cpu.out -bench=.` → `go tool pprof cpu.out` |
| 3 | heap profile | `go test -memprofile=mem.out -bench=.` → `pprof -alloc_objects mem.out` |
| 4 | identify hot path | `pprof` `top10`, `list <func>` for source-line detail |
| 5 | post-fix benchstat | `benchstat old.txt new.txt` to confirm statistical significance |

**Rule**: no optimization without measurement. Profile first, identify bottleneck, fix, re-measure.

---

## 2. Escape Analysis (heap vs stack)

```bash
go build -gcflags='-m=2' ./... 2>&1 | grep "escapes"
```

**Stack allocation (fast)**:
- Local variable that does not escape the function
- Return value as a value type (small struct)

**Heap escape (slow, GC pressure)**:
- Assignment to interface (type info held at runtime)
- Pointer passed outside function (return value, global, closure)
- Dynamically sized slice/map creation
- `interface{}` arguments like `fmt.Println(x)`

**Avoidance examples**:

```go
func bad() *User { return &User{} }              // heap escape
func good() User { return User{} }               // stack（値返し、small struct）
var buf [64]byte; _ = string(buf[:])             // stack（fixed size）
```

---

## 3. Allocation Reduction

| Pattern | Effect |
|---------|--------|
| **map preallocation** | `make(map[K]V, size)` avoids rehash |
| **slice preallocation** | `make([]T, 0, capHint)` avoids grow |
| **string concat** | `+=` repeated → `strings.Builder`; `fmt.Sprintf("%d",n)` → `strconv.Itoa(n)` / `FormatInt` |
| **[]byte ↔ string zero-copy** | `unsafe.String`/`unsafe.SliceData` (Go 1.20+). Prefer **safe alternatives** (`strings.Builder`, `[]byte(s)`); `unsafe` only when localized and original slice immutability is guaranteed within the function |
| **sync.Pool** | reuse short-lived large objects, reduce GC pressure |
| **avoid interface boxing** | `any` argument escapes; consider generics |

**sync.Pool example**:

```go
var bufPool = sync.Pool{New: func() any { return new(bytes.Buffer) }}
buf := bufPool.Get().(*bytes.Buffer); defer bufPool.Put(buf)
buf.Reset()  // 使用前 Reset 必須
```

**Note**: sync.Pool contents can be flushed by GC; not a cache. Uniform size recommended (mixing large objects causes memory hogging).

---

## 4. Inline Budget

The Go compiler auto-inlines functions with **cost ≤ 80**. Inlining eliminates call overhead and improves escape behavior.

| Check | Command |
|-------|---------|
| Inline decision | `go build -gcflags='-m=2' ./...` → `can inline` / `cannot inline (cost X)` |
| Disable inline | `//go:noinline` for explicit suppression (profiling use) |
| Inline control | `-gcflags='-l'` **disables** inlining (debug only). Aggressive inlining = **PGO** (see below); internal `-l=4` etc. are undocumented debug levels, not for production |

**Tips for inlining hot functions**: keep them short (no loops / large switch), avoid interface arguments.

---

## 5. pprof Profile Types

| Type | Capture | Use |
|------|---------|-----|
| **CPU** | `runtime/pprof.StartCPUProfile` | compute bottleneck |
| **heap** | `-memprofile` / `/debug/pprof/heap` | allocation source |
| **goroutine** | `/debug/pprof/goroutine` | leak, stuck detection |
| **mutex** | `/debug/pprof/mutex` (requires `runtime.SetMutexProfileFraction`) | lock contention |
| **block** | `/debug/pprof/block` (requires `runtime.SetBlockProfileRate`) | channel/syscall wait |

**pprof interactive**:
```text
top10                # 上位10
list <funcName>      # ソース行
web                  # SVG 火炎グラフ
peek <funcName>      # 呼出元/呼出先
```

**Flame graph reading**: width = cumulative time; higher = deeper call stack; **wide blocks = optimization candidates**.

---

## 6. PGO (Profile-Guided Optimization, stable Go 1.21+)

Feed production workload profiles into the build to intensively optimize hot paths (expanded inlining, improved register allocation). **2-7% performance improvement observed**.

```bash
# 1. 本番 profile 採取
curl -o cpu.pprof http://prod:6060/debug/pprof/profile?seconds=30

# 2. profile を default.pgo として配置
mv cpu.pprof cmd/server/default.pgo

# 3. PGO 有効ビルド（自動検出）
go build -pgo=auto ./cmd/server
```

**Operations**: update profile monthly; include PGO build in CI artifacts.

---

## 7. GC Tuning

| Env var | Default | Effect |
|---------|---------|--------|
| `GOGC` | 100 | trigger GC when heap doubles; lower → more frequent GC, shorter pauses |
| `GOMEMLIMIT` (Go 1.19+) | math.MaxInt64 | soft heap limit; aggressively GC before exceeding |
| `GODEBUG=gctrace=1` | — | log each GC (pause time / heap size) |

**Typical scenarios**:
- Container with memory limit → `GOMEMLIMIT=memory_limit*0.9` to avoid OOMKilled
- Batch job where latency is not critical → `GOGC=200` to widen GC interval for throughput

---

## 8. runtime/metrics (Go 1.16+)

**Lower cost and more detail** than `runtime.ReadMemStats`.

```go
samples := []metrics.Sample{
    {Name: "/gc/heap/allocs:bytes"},
    {Name: "/sched/latencies:seconds"},
}
metrics.Read(samples)
```

Key metrics:
- `/gc/heap/live:bytes` — live heap
- `/gc/heap/allocs:bytes` — cumulative allocation
- `/sched/latencies:seconds` — goroutine ready→running wait time (histogram)

---

## 9. Anti-patterns

| Avoid | Use | Reason |
|-------|-----|--------|
| `fmt.Sprintf("%d", n)` high-frequency | `strconv.Itoa(n)` | format parser overhead |
| `for _, v := range bigSlice` with large struct copy | `for i := range bigSlice` with `&bigSlice[i]` | copy cost |
| Pass large struct by value | pass by pointer (use sync.Pool if escape is an issue) | copy cost |
| Indiscriminate goroutine creation | worker pool (see go-concurrency) | scheduler overhead |
| `interface{}` slice | generics (1.18+) | prevents escape |
| Optimize without measurement | benchmark + benchstat required | most attempts have no effect or regress |

---

## 10. References

- Go 1.21 PGO official: pkg.go.dev/cmd/go#hdr-Profile-guided_optimization
- Dave Cheney "High Performance Go Workshop"
- runtime/metrics official docs
- Related: `languages/go-concurrency.md` (concurrency optimization), `languages/golang.md` (basics), `backend/observability-design.md` (profiling operations)
