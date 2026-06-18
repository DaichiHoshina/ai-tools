# /flow Self-Review (3 gate canonical)

`/flow` の Self-Review 3 gate 詳細仕様。`commands/flow.md` `## Self-Review` section が summary 参照元、本 file が canonical。Noise discard policy: `rules/review-noise-discard.md`。

**適用範囲**: Gate A / B は orchestration path (PO → Manager → Dev×N) で必須・skip 不可。`--sequential` 時は `flow.md` step 2 で Manager skip → 直接 `/dev` 委譲のため Gate A・B は適用外 (Manager allocation も parallel diff も存在しない)。Gate C は `--auto` / `--multi-review` 時のみ発火、default `/flow` は従来 reviewer 構成維持。

## Gate A: Parallel-judgment self-review (step 6.5)

Manager の allocation を fan-out 前に parent Opus が 5 観点で再評価。判定 log は chat 出力せず、FAIL のみ 1 行通知。

| 観点 | 検査 |
|---|---|
| **N consistency** | `N_chosen` と `tasks[]` 件数が一致するか (planned vs actual N 乖離検知) |
| **formula PASS** | `formula_trace.formula_result=PASS` かつ `LPT+ovh < sum_T_i × 0.95` |
| **file conflict** | `tasks[].files[]` の積集合が空か (同一 file 多重編集検知) |
| **worktree applicability** | `worktree_required` と `downgrade_reason` の整合 (`references/PARALLEL-PATTERNS.md#worktree-applicability-flow`)。判定: `worktree_required=true` + `downgrade_reason=null` → PASS / `worktree_required=false` + `downgrade_reason≠null` → PASS / `worktree_required=true` + `downgrade_reason≠null` → **FAIL (矛盾)** / `worktree_required=false` + `downgrade_reason=null` → PASS (trivial) |
| **T_i basis** | `T_i_basis` が `historical` / `estimated` 等の許容値、`unknown` 不可 |

FAIL → Manager 再実行 (allocation 破棄、step 4 へ戻る、max 1 回)。2 回目 FAIL → `--sequential` downgrade + 1 行通知。

## Gate B: Parallel-implementation self-review (step 8.5)

aggregate 後、N 本の dev 差分を parent Opus が 4 観点で再評価。**diff type で有効観点 subset を変える** — code diff (混合 diff = code + doc 含む) は 4 観点全部、doc-only diff (全 task が `*.md` / `*.txt` 等のみ) は cross-diff conflict + naming collision (heading 重複) のみ。

| 観点 | 検査 | 適用 diff type |
|---|---|---|
| **cross-diff conflict** | 同一 file 同一行を複数 dev が編集していないか (`git diff` 行重複) | code / doc 両方 |
| **duplicate import / decl** | aggregate 後 file で import / type / const の重複追加が無いか | code のみ |
| **naming collision** | 別 dev が同名 symbol (code) / 同名 heading (doc) を別意味で導入していないか | code / doc 両方 |
| **propagation incompleteness** | dev A の interface 変更を dev B の caller が追従できているか (Serena `find_referencing_symbols`) | code のみ |

FAIL → step 9 P0 loop へ強制投入 (P0 0 件でも実行)。max 1 loop。

## Gate C: 12-perspective parallel review (step 8 拡張)

`--auto` / `--multi-review` 時、`Task(reviewer-agent, --focus=<lens>)` × 12 並列 fan-out。lens: `architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design / db-concurrency`。各 reviewer は単一 lens 専念で深掘り、Stage B dedup は parent Opus 集約。`--codex` 並行追加で計 13 agent。

cost 帯: reviewer-agent×12 並列 (10min 級、`--codex` 追加で 13 agent)。default `/flow` は従来通り comprehensive + codex 並列 2 agent 維持。

判定: 各 lens reviewer が Critical / Warning を返却 → parent Opus が `rules/review-noise-discard.md` filter 後に dedup → step 9 P0 loop へ。
