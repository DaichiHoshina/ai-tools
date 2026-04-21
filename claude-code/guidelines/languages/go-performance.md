# Go パフォーマンス ガイドライン

CPU/メモリ最適化、allocation削減、PGO 適用が必要な時に参照。基礎は `languages/golang.md`。

## Tier 区分

| Tier | 内容 |
|------|------|
| Tier 1（必須） | escape analysis、benchmark、pprof CPU/heap |
| Tier 2（規模別） | sync.Pool、ゼロコピー、map preallocation、inline budget |
| Tier 3（深掘り） | PGO、GOGC/GOMEMLIMIT、runtime/metrics、火炎グラフ |

---

## 1. 「Goが遅い」5ステップ診断

| Step | 確認 | コマンド |
|------|------|---------|
| 1 | benchmark 取得 | `go test -bench=. -benchmem -count=10` |
| 2 | CPU profile | `go test -cpuprofile=cpu.out -bench=.` → `go tool pprof cpu.out` |
| 3 | heap profile | `go test -memprofile=mem.out -bench=.` → `pprof -alloc_objects mem.out` |
| 4 | hot path特定 | `pprof` で `top10`、`list <func>` でソース行レベル |
| 5 | 改善後 benchstat | `benchstat old.txt new.txt` で統計的有意差確認 |

**原則**: 計測なし最適化禁止。まず profiling、ボトルネック特定、改善、再測定。

---

## 2. Escape Analysis（heap vs stack）

```bash
go build -gcflags='-m=2' ./... 2>&1 | grep "escapes"
```

**stack 配置（速い）**:
- ローカル変数で関数外に逃げない
- 関数戻り値で値型として返す（small struct）

**heap escape（遅い、GC圧）**:
- interface への代入（型情報を runtime で持つ）
- ポインタを関数外（戻り値、grobal、closure）に渡す
- 動的サイズの slice/map 生成
- `fmt.Println(x)` 等の `interface{}` 引数

**回避例**:

```go
func bad() *User { return &User{} }              // heap escape
func good() User { return User{} }               // stack（値返し、small struct）
var buf [64]byte; _ = string(buf[:])             // stack（fixed size）
```

---

## 3. Allocation 削減

| パターン | 効果 |
|---------|------|
| **map preallocation** | `make(map[K]V, size)` で rehash回避 |
| **slice preallocation** | `make([]T, 0, capHint)` で grow 回避 |
| **string concat** | `+=` 連発 → `strings.Builder`、`fmt.Sprintf` 高頻度 → `strconv` |
| **[]byte ↔ string ゼロコピー** | `unsafe.String`/`unsafe.SliceData`（Go 1.20+）で copy回避（不変保証要） |
| **sync.Pool** | 短命大object 再利用、GC圧削減 |
| **interface 化避ける** | `any` 引数は escape、ジェネリクス検討 |

**sync.Pool 使用例**:

```go
var bufPool = sync.Pool{New: func() any { return new(bytes.Buffer) }}
buf := bufPool.Get().(*bytes.Buffer); defer bufPool.Put(buf)
buf.Reset()  // 使用前 Reset 必須
```

**注意**: sync.Pool は GC で内容flush可能、cache不可。size 統一推奨（巨大object混在で memory hog）。

---

## 4. inline budget

Go コンパイラは関数を **コスト 80以下** で自動 inline。inline されると関数呼出 overhead がゼロ化、escape も改善。

| 確認 | コマンド |
|------|---------|
| inline 判定 | `go build -gcflags='-m=2' ./...` で `can inline` / `cannot inline (cost X)` |
| inline 強制不可 | `//go:noinline` で明示的に inline 抑制（profiling用） |
| budget 増加 | `-gcflags='-l=4'` で aggressive inline（実験用、本番非推奨） |

**ホット関数を inline させるコツ**: 短く保つ（loop / 大 switch なし）、interface 引数避ける。

---

## 5. pprof プロファイル種別

| 種別 | 取得 | 用途 |
|------|------|------|
| **CPU** | `runtime/pprof.StartCPUProfile` | 計算時間ボトルネック |
| **heap** | `-memprofile` / `/debug/pprof/heap` | メモリ allocation 元 |
| **goroutine** | `/debug/pprof/goroutine` | leak、stuck 検出 |
| **mutex** | `/debug/pprof/mutex`（要 `runtime.SetMutexProfileFraction`） | lock contention |
| **block** | `/debug/pprof/block`（要 `runtime.SetBlockProfileRate`） | channel/syscall 待ち |

**pprof インタラクティブ**:
```text
top10                # 上位10
list <funcName>      # ソース行
web                  # SVG 火炎グラフ
peek <funcName>      # 呼出元/呼出先
```

**火炎グラフ読み方**: 横幅 = 累積時間、上に行くほど呼出深く、**幅広いブロック = 最適化候補**。

---

## 6. PGO（Profile-Guided Optimization、Go 1.21+ 安定）

本番ワークロード profile を build に取り込み、hot path を集中最適化（inline拡大、register割当改善）。**2-7% 性能向上事例あり**。

```bash
# 1. 本番 profile 採取
curl -o cpu.pprof http://prod:6060/debug/pprof/profile?seconds=30

# 2. profile を default.pgo として配置
mv cpu.pprof cmd/server/default.pgo

# 3. PGO 有効ビルド（自動検出）
go build -pgo=auto ./cmd/server
```

**運用**: 月次で profile 更新、CI で PGO build を成果物化。

---

## 7. GC Tuning

| 環境変数 | 既定 | 効果 |
|---------|------|------|
| `GOGC` | 100 | heap 倍増で GC、低くする → GC頻度↑ pause短く |
| `GOMEMLIMIT`（Go 1.19+） | math.MaxInt64 | soft heap limit、超えそうなら GC積極化 |
| `GODEBUG=gctrace=1` | - | GC毎にログ出力（pause時間/heap size） |

**典型シナリオ**:
- container memory limit ある → `GOMEMLIMIT=memory_limit*0.9` で OOMKilled 回避
- batch処理で latency重要でない → `GOGC=200` で GC間隔広げてthroughput優先

---

## 8. runtime/metrics（Go 1.16+）

`runtime.ReadMemStats` より**低コストで詳細**。

```go
samples := []metrics.Sample{
    {Name: "/gc/heap/allocs:bytes"},
    {Name: "/sched/latencies:seconds"},
}
metrics.Read(samples)
```

代表 metric:
- `/gc/heap/live:bytes` - 生存heap
- `/gc/heap/allocs:bytes` - 累計allocation
- `/sched/latencies:seconds` - goroutine ready→running 待ち時間（histogram）

---

## 9. アンチパターン

| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| `fmt.Sprintf("%d", n)` 高頻度 | `strconv.Itoa(n)` | format parser 重い |
| `for _, v := range bigSlice` で大 struct copy | `for i := range bigSlice` で `&bigSlice[i]` | copy cost |
| 大 struct を value 渡し | pointer 渡し（escape問題なら sync.Pool） | copy cost |
| 無闇に goroutine 生成 | worker pool（go-concurrency参照） | scheduler負荷 |
| `interface{}` slice | ジェネリクス（1.18+） | escape 防止 |
| 計測なし最適化 | benchmark + benchstat 必須 | 多くは効果なし or 退行 |

---

## 10. 参考

- Go 1.21 PGO 公式: pkg.go.dev/cmd/go#hdr-Profile-guided_optimization
- Dave Cheney「High Performance Go Workshop」
- runtime/metrics 公式
- 関連: `languages/go-concurrency.md`（並行最適化）、`languages/golang.md`（基礎）、`backend/observability-design.md`（profiling運用）
