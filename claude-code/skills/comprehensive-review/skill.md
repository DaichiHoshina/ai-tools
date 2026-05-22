---
name: comprehensive-review
description: "12観点の包括コードレビュー(設計/品質/可読性/security/test/DB等)。/review から呼出、--focus で絞込。コードレビュー時に使用。"
context: fork
agent: reviewer-agent
requires-guidelines:
  - common
  - clean-architecture
  - domain-driven-design
parameters:
  focus:
    type: enum
    values: [all, architecture, quality, readability, security, docs, test-coverage, root-cause, logging, writing, silent-failure, type-design, db-concurrency]
    default: all
    description: Review focus perspective
---

# comprehensive-review - Comprehensive Code Review

## 12 Perspectives

詳細: `references/review-criteria.md` (architecture/quality/readability/security/docs/test-coverage/root-cause/logging) / `writing-docs.md` / `silent-failure.md` / `type-design.md` / `db-concurrency.md`。

| Perspective | Description |
|---|---|
| **architecture** | DDD境界、Clean Arch dependency方向、modular monolith境界、layer violation |
| **quality** | 言語/FW best practice、local idiom、code smell、performance、type safety |
| **readability** | Naming、cognitive complexity、consistency |
| **security** | Authn/authz、injection、secrets、tenant/data isolation、unsafe logging、dependency/config exposure |
| **docs / test-coverage** | Doc 品質、テスト網羅性・品質 |
| **root-cause** | Permanent fix vs workaround、再発パターン |
| **logging** | Log level 適正、structured log |
| **writing** | Human-facing doc 品質 |
| **silent-failure** | Error swallowing、empty catch |
| **type-design** | Type-encoded invariant、enum 濫用回避 |
| **db-concurrency** | InnoDB暗黙deadlock / gap lock / FOR UPDATE+INSERT / ODKU昇格 / TX内外部I/O / retry不在 |

## Effort-Linked Mode (`${CLAUDE_EFFORT}`)

Confidence thresholds & coverage vary by effort level.

| Effort | Critical Threshold | History | Perspectives |
|--------|---------------|---------|---------|
| `low` | 90+ (minimize false positives) | Skip | Skip writing/type-design/docs |
| `medium` (default) | 80+ | Past 90 days | All 12 |
| `high` | 70+ (evidence-backed safety/design issues only) | Full history | + design tradeoff, dependencies |

## Execution Flow

### Step -1: Noise Suppression

- Read diff/code/docs only. Guess→prefix "hypothesis:". No style/preference/theory nitpicks.
- Findings must be anchored to observed violation/regression/concrete risk in scope.
- 「could be better」「might be useful」「best to check」は note/question 止まり、Critical/Warning 不可。
- Issue/task 作成は明示要求時のみ。TODO は「just in case」「confirm」禁止、今日の blocker のみ。ユーザが不要と明言した作業の再追加禁止。

### Step 0: Load History (Detect Repeats)

`.claude/review-history.jsonl` 読み込み、同 `file:line±3` + 同 `focus` が 3+ 回出現 → prefix `🔁 Repeated Finding (Nth time)`。history 不在 (未作成/empty/jq missing) → skip、出力末尾に `history: unavailable`。

### Step 1: Changed File Analysis

`git diff --name-only` で言語/ファイル種別/scope 判定し追加観点を自動決定。

**Serena priority** (code files、ref 漏れ防止): impact → `find_referencing_symbols` / interface↔impl → `find_implementations` / decl → `find_declaration` / type check → `get_diagnostics_for_file` (LSP 直、外部 typecheck 不要) / structure → `get_symbols_overview` + `find_symbol`。Non-code (md/yaml/json/toml/lockfile/.env) → Grep/Read。

Default lenses: `quality` (言語/FW/プロジェクト local conventions) / `architecture` (DDD / Clean Arch / modular monolith boundary を diff が横断する箇所のみ) / `root-cause` (症状でなく根本原因対応) / `security` (diff が触れる security surface)。

| Condition | Add Perspective |
|------|---------|
| Test file (`*_test.*`, `*.spec.*`) | `docs` |
| UI file (`components/*`, `*.tsx`) | `uiux-review` (separate skill) |
| Logic change (non-test) | `test-coverage` + `silent-failure` |
| Type def change (`*.d.ts`, `types/*`, struct/interface added) | `type-design` |
| SQL/ORM変更 (`*.sql`、`*Repository*`、`tx.Exec`、`SELECT.*FOR UPDATE`、`ON DUPLICATE KEY`) | `db-concurrency` |

### Step 2: Run Static Analysis Tools

```bash
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...
```

**Tool presence**: 実行結果で判定 (PATH lookup 不可)。`npx tsc` / `npm run` は `node_modules/.bin/` 経由可。

**判定順** (top-to-bottom、最初一致で確定。message match 優先、exit code 最後):

| # | 条件 | Action |
|---|---|---|
| 1 | stderr に `command not found` / `npm ERR! Missing script` / `could not determine executable` | skip → `static-analysis: skipped (<cmd>: not installed/missing)` |
| 2 | exit 127 | skip → `static-analysis: skipped (<cmd>: not found)` |
| 3 | exit 0/1 + analyzer 出力あり (lint violation / type error / `error TS` 等) | 結果反映、続行 |
| 4 | その他 non-zero | Warning として含めて続行 |

### Step 3: cleanup-enforcement

Verify unused imports/vars/functions、backward compat 残骸、progress comments。

### Step 4: Confidence Scoring (medium default)

各 finding に 0-100 score 付与: **80+** (low 90+, high 70+) → Critical / **50-79** → Warning に downgrade / **25-49** → Warning / **<25** → Discard。

### Step 4.5: Self-Filter Gate (moderate strictness)

各 candidate を下記で validate (Fail → discard、severity 不一致は downgrade):

- **Evidence**: diff/code/docs/tests/tool output に直接 anchor
- **Scope**: user request / issue / design doc / code contract / changed behavior 紐付
- **Overreach**: 新 problem statement や requirement 捏造なし
- **Actionability**: この change で著者が fix 可能
- **Severity**: Critical/Warning が実 impact と confidence に一致
- **Style/preference**: documented guideline/contract 根拠あり (美的好みでない)
- **Overprescription**: reasonable engineer が defect と呼ぶ (単なる代替案でない)

**Pre-emission sanity check**: discard findings matching「cleaner / more elegant / better naming」(rule違反なし) /「verbose / shorter」(prose preference) /「same concept in multiple places」(drift risk なし) / 既存 TODO 再掲 / 意図的設計選択を deviation 扱い /「consider X」で具体 defect なし。Gate + sanity 両方通過のみ出力、0件残存は正解 (捏造禁止)、チェックリスト本体は 0件理由説明時のみ出力。

### Step 5-6: Aggregate & Record History

Append confirmed Critical/Warning (confidence ≥25) to `.claude/review-history.jsonl` (fields: date/severity/focus/file/line/finding/confidence/branch/commit).

## Output Format

```markdown
## Comprehensive Review Results

### Perspectives Checked
- architecture / quality / readability / security / docs / test-coverage / root-cause / logging / writing / silent-failure / type-design

### Critical (Confidence 80+)
- [security] SQL injection (src/api/user.ts:120) confidence 95
- 🔁 Repeated Finding (4th time): [architecture] Domain→Infra ref (src/domain/user.ts:45) confidence 85

### Warning (Confidence 25-79)
- [quality] sort.Slice → slices.Sort (pkg/sort.go:15) confidence 65

Total: Critical N / Warning N / Discarded M / 🔁 Repeated K
```

**Zero findings rule**: section 省略禁止、0件は `### Critical: 0`。skip 観点は executed list から除外し `### skipped: <perspective> (<reason>)` 追記。

## Notes

focus=all → 12並列、large diff は 1ファイルずつ Critical 優先。具体 fix 提示、tag: `must`=Critical / `imo`,`nits`=Warning / `q`=question。根拠なき task 作成・problem framing 捏造・scope 外 operational TODO 禁止。
