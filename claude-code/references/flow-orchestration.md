# /flow Orchestration Details

詳細仕様。概要 / decision table / gate 一覧は `commands/flow.md` 参照。

## Formula trace echo (mandatory)

Parent は Manager が返す `formula_trace` を chat に echo する (decision basis をユーザに可視化)。echo format:

```text
formula: N=<N_chosen> / sum_T_i=<sum>s / LPT+ovh=<expected_parallel>s / <PASS|FAIL> (basis=<T_i_basis>)
fan-out: N=<n>, targets=<file count>
```

`formula_trace` field 欠損 / `formula_result=FAIL` かつ `N>=2` → parent が fan-out を停止し Manager を再実行 (allocation 破棄)。`N_chosen=1` → sequential downgrade (step 5 経由)。

Schema 詳細: `agents/manager-agent.md` Allocation plan format `formula_trace` field definition。

## --auto fully autonomous mode

`--auto` 付与時の決定動作一覧。

| Decision | Action |
|------|------|
| AskUserQuestion | 呼ばない、推奨案を自動採用 |
| Agent launch | `mode: "bypassPermissions"` |
| Push target | 常に PR (main 直 push 禁止) |
| Design decision | 推奨案採用、シンプル優先 |
| lint-test fail | Auto-fix 1×、2 回目失敗で停止 + 報告 |
| Multi-review | `--multi-review` auto-ON (Gate C 12-lens 並列) |

review-fix loop: 実装後 `/review` → auto-fix を繰り返し **Critical 0 + Warning 0 まで** (max 3×、超過 → 報告して続行)。

## Execution logic (detail)

step 番号は `commands/flow.md` ## Execution logic の step 番号と対応。

### Step 1-4 (git check / downgrade / PO / Manager)

1. **git status check**: changes あり → WIP confirm 後 step 2 継続 (`/dev` にリダイレクトしない)
2. **Pre-Manager downgrade check** (static): `--sequential` 明示時のみ即 downgrade → 単一 `/dev` を delegate、PO/Manager をスキップ。`--sequential` 明示でない場合 → step 3
3. **PO Agent (required)**: design 判断 / scope split。スキップ不可 (legacy `--no-po` 廃止)
4. **Manager Agent (required)**: task split / file dedup / N calc + `formula_trace` 計算

### Step 5 (post-Manager downgrade)

Manager allocation `parallelism: 1` *かつ* `worktree_required: false` *または* physical file conflict (同一 file 同時編集) → Dev×1 sequential (worktree isolation スキップ = Auto-apply features 内 downgrade)。Manager が 1 dev 向け integrate をスキップ、Team review は継続。

### Step 6 (orchestration pre-delegation)

**内部処理 + judgment trace echo**: target / verify / DoD を subagent prompt に埋め込む。ユーザには **2 行のみ** 表示:

- line 1 (formula trace): `formula: N=<N_chosen> / sum_T_i=<sum>s / LPT+ovh=<expected_parallel>s / PASS|FAIL (basis=<T_i_basis>)`
- line 2 (fan-out declaration): `fan-out: N=<n>, targets=<file count>`

Manager の `formula_trace` 12 sub-field のいずれかが欠損 → fan-out 停止、Manager を再要求 (allocation 破棄)。worktree apply/skip 判断 (downgrade_reason 有無) を echo line 1 に含める。`mkdir -p <impl_notes.dir>` を実行。

### Step 6.3 (PO Gate)

必須、1 回のみ (/flow 1 回につき)。Parent が Manager allocation + initial `manager_instruction` (contract §1.1) を添えて PO を再起動。PO が `verdict: pass | fail | modify` を返す。`pass` → step 6.5。`modify` → `fix_request` を付けて Manager 再 allocation (最大 1 loop、2 loop 目以降は user escalation)。`fail` → /flow 停止 + user escalation。スキップ不可。Canonical: `agents/po-agent.md` § Manager allocation oversight

### Step 6.5 (Gate A)

必須、N≥2 のみ (step 5 downgrade 後 N=1 の sequential path は除外)。Parent Opus が Manager の `N_chosen` / `formula_trace` / file conflict 検出を 6 基準で再評価。FAIL → Manager 再実行 (allocation 破棄、step 4 戻り)。PASS → step 7。スキップ不可。Canonical: `references/parallel-self-review.md`

### Step 7 (parallel fan-out)

fan-out 宣言前の progress 説明をスキップし、並列 Task 起動を優先する。`Task(developer-agent)×N` を **1 message で fire** (worktree isolated; N=1 は step 5 で確定した sequential path)。**Bundle 必須**: N Task を即 1 message にまとめる。1-per-message 分割 = sequential chain (parentUuid serial) = 禁止。N 宣言 : tool_use 起動 message = 1:1 厳守。

### Step 8 (parallel integrate + review)

**1 message で両方 fire**: `Task(manager-agent)` integrate **と** reviewer fan-out を同時実行。
- default: `Task(reviewer-agent, --codex)` × 1 (`comprehensive-review` 12 基準 + codex 並列)
- `--auto` / `--multi-review`: Gate C (12-lens stage split)。詳細: `references/parallel-self-review.md` §Gate C

Reviewer は `diff_target` を直接読む (MERGED.md スキップ) → `integration_cost` (~42s) を critical path から除去。1 message に bundle。

### Step 8.5 (Gate B)

必須、N≥2 のみ。Parent Opus が N diff を 4 基準 (cross-diff conflict / duplicate import / naming collision / propagation incompleteness) で再評価。FAIL → step 9 P0 loop を強制 (P0 finding 0 でも)。PASS → step 9 通常フロー。スキップ不可。Canonical: `references/parallel-self-review.md`

### Step 8.7 (Dev failure gate)

必須、step 8 Manager aggregate 直後 (Reviewer 消化前) に実行。Dev report に `status ∈ {failure, partial, dep_unresolved}` があれば parent が Manager を `reallocation_trigger: dev_failure` + `failed_devs[]` (contract §3.1) で再呼び出し → step 7 から再 fix Dev を fan-out (最大 1 loop)。2 回目失敗 → 停止、user escalation (`--auto`: `stop: dev failure 2x` 通知 + push スキップ)。step 8 の Reviewer 出力は再 fix path で破棄 (再 fix 成功後に再実行)。

### Step 9 (P0 re-fix loop)

step 8 両 agent 完了後:
- P0: manager realloc → developer×M fix → reviewer 再検証 (**最大 1 loop**)
- P0 残存 / P1: 報告して継続 (`--auto` 時は停止)
- codex 未設定: `comprehensive-review` single fallback

**`--until-gate-green "<check-cmd>"` 拡張 (`/goal` 統合)**: flag 指定時、停止条件を reviewer-agent subjective 判定 (Stage A 7 観点) ではなく bash `<check-cmd>` の exit code に切替。

- 例: `/flow --until-gate-green "npm test && npm run lint" <task>` / `/flow --until-gate-green "bats tests/" <task>`
- iteration upper: `--max-iter <n>` (default 3、`/goal` default 5 より厳しめ。`/flow` は PO/Manager overhead 大なので token 節約)
- hard stops: token budget 100k / wall-clock 30m (内 default、`/goal` と同)
- maker/checker 分離: 既存 `developer-agent` (maker) + bash check (objective checker) の組み合わせで Ralph Wiggum guard を default 充足。reviewer-agent は flag 無し時の subjective gate のまま、flag 有り時は bash check に置換
- 互換性: flag 無し時は現行挙動 (reviewer-agent P0=0 で停止、max 1 loop) 維持
- 詳細: `references/loop-engineering.md` § Failure modes / Minimum viable loop

## --auto skip conditions (detail)

`references/PARALLEL-PATTERNS.md` `### /flow --parallel --auto skip-confirmation 4 conditions` 参照。

Summary: Parallel formula PASS + clean worktree + branch/worktree 衝突なし + 作成失敗 → sequential downgrade + 通知。

## worktree cleanup (detail)

`references/PARALLEL-PATTERNS.md` `### Cleanup policy (common)` 参照。

Summary: Changes present → branch return + merge + delete / no changes → auto-delete / Collision → sequential downgrade + leave in place。
