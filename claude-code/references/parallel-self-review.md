# /flow Self-Review (3 gate canonical)

`/flow` の Self-Review 3 gate 詳細仕様。`commands/flow.md` `## Self-Review` section が summary 参照元、本 file が canonical。Noise discard policy: `rules/review-noise-discard.md`。

**適用範囲**: Gate A / B は orchestration path (PO → Manager → Dev×N) で必須・skip 不可。`--sequential` 時は `flow.md` step 2 で Manager skip → 直接 `/dev` 委譲のため Gate A・B は適用外 (Manager allocation も parallel diff も存在しない)。Gate C は `--auto` / `--multi-review` 時のみ発火、default `/flow` は従来 reviewer 構成維持。

## Gate A: Parallel-judgment self-review (step 6.5)

Manager の allocation を fan-out 前に parent Opus が 5 観点で再評価。判定 log は chat 出力せず、FAIL のみ 1 行通知。

| 観点 | 検査 |
|---|---|
| **N consistency** | `N_chosen` と `tasks[]` 件数が一致 (planned vs actual N 乖離検知)。bundle case (`independent_task_count > N_chosen`、`manager-agent.md` L130 「9+ tasks → bundle ≤8」) は `tasks[].length == N_chosen ≤ 8` かつ `independent_task_count` が `formula_trace` に記録されてれば PASS |
| **formula PASS** | `formula_trace.formula_result=PASS` かつ `LPT+ovh < sum_T_i × 0.95` |
| **file conflict** | `tasks[].files[]` の積集合が空か (同一 file 多重編集検知) |
| **worktree applicability** | `worktree_required` と `downgrade_reason` の整合 (`references/PARALLEL-PATTERNS.md#worktree-applicability-flow`)。判定: `worktree_required=true` + `downgrade_reason=null` → PASS / `worktree_required=false` + `downgrade_reason≠null` → PASS / `worktree_required=true` + `downgrade_reason≠null` → **FAIL (矛盾)** / `worktree_required=false` + `downgrade_reason=null` → PASS (trivial) |
| **T_i basis** | `T_i_basis` が `historical` / `estimated` 等の許容値、`unknown` 不可 |

FAIL → Manager 再実行 (allocation 破棄、step 4 へ戻る、max 1 回)。2 回目 FAIL → `--sequential` downgrade (Dev×1 sequential のみ。step 2 の早期 `--sequential` path とは異なり PO/Manager は既に走った後なので skip しない) + 1 行通知。

## Gate B: Parallel-implementation self-review (step 8.5)

aggregate 後、N 本の dev 差分を parent Opus が 4 観点で再評価。**diff type で有効観点 subset を変える**。diff type 定義:
- **code (LSP 対応)**: `*.ts` / `*.tsx` / `*.js` / `*.go` / `*.py` / `*.rs` 等 LSP-backed 言語。propagation check に Serena 利用可
- **code (LSP 外)**: `*.sh` / `*.bash` / `*.sql` / `*.yaml` / `*.json` / `*.toml` 等。propagation check は grep ベース fallback (`grep -rnF '<symbol>' .`)
- **doc-only**: 全 task が `*.md` / `*.txt` 等のみ。propagation 観点は適用外

混合 diff (code + doc + LSP 外 混在) は **最上位を採用** = code (LSP 対応) があれば LSP path、無ければ LSP 外、全 doc なら doc-only。

| 観点 | 検査 | 適用 diff type |
|---|---|---|
| **cross-diff conflict** | 同一 file 同一行を複数 dev が編集していないか (`git diff` 行重複) | 全部 (code / LSP 外 / doc) |
| **duplicate import / decl** | aggregate 後 file で import / type / const の重複追加が無いか | code (LSP 対応 / LSP 外) のみ |
| **naming collision** | 別 dev が同名 symbol (code) / 同名 heading (doc) を別意味で導入していないか | 全部 |
| **propagation incompleteness** | dev A の interface 変更を dev B の caller が追従できているか (LSP 対応: Serena `find_referencing_symbols` / LSP 外: `grep -rnF '<symbol>' .` fallback) | code (LSP 対応 / LSP 外) のみ |

FAIL → step 9 P0 loop へ強制投入 (P0 0 件でも実行)。max 1 loop。manager realloc 時に Gate B FAIL の検知内容 (どの観点 / どの file 衝突) を明示 input し、同じ allocation ミスを繰り返さない。

## Gate C: 12-perspective parallel review (step 8 拡張)

`--auto` / `--multi-review` 時、`Task(reviewer-agent, --focus=<lens>)` を 12 lens で fan-out。lens: `architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design / db-concurrency`。

**並列上限**: 8 Dev limit (`manager-agent.md` L130) + 9 concurrent session limit (`references/PARALLEL-PATTERNS.md` L207) のため **stage split 必須**。**境界余裕 1 確保** (parent 他 task 発火 case の safety margin) のため stage 上限 8 agent ではなく **7 agent**:
- stage 1: 6 lens 並列 (`architecture / quality / security / root-cause / silent-failure / type-design` の構造系) + `--codex` × 1 = 7 agent (`--codex` 未設定時は 6 agent)
- stage 2: 6 lens 並列 (`db-concurrency / readability / docs / test-coverage / logging / writing` の品質系 + db-concurrency) = 6 agent

各 stage は **1 message bundle 発火** (flow.md L108 dev fan-out と同じ規則)。stage 間は parent Opus が stage 1 結果待ち後に stage 2 発火。各 reviewer は単一 lens 専念で深掘り、Stage B dedup は parent Opus 集約。

cost 帯: 12 lens stage split (10-12min 級、stage 1 = 7 agent / stage 2 = 6 agent)。default `/flow` は従来通り comprehensive + codex 並列 2 agent 維持。

判定: 各 lens reviewer が Critical / Warning を返却 → parent Opus が `rules/review-noise-discard.md` filter 後に dedup → step 9 P0 loop へ。
