---
name: comprehensive-review
description: "Comprehensive code review across 12 perspectives (architecture/quality/readability/security/test/DB etc). Called from /review, narrow with --focus. Use when reviewing code."
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

Details: `references/review-criteria.md` / `writing-docs.md` / `silent-failure.md` / `type-design.md` / `db-concurrency.md`.

| Perspective | Description |
|---|---|
| **architecture** | DDD boundaries, Clean Arch dependency direction, layer violations |
| **quality** | Language/FW best practice, local idioms, code smell, performance, type safety |
| **readability** | Naming, cognitive complexity, consistency |
| **security** | Authn/authz, injection, secrets, tenant/data isolation, unsafe logging |
| **docs / test-coverage** | Doc quality, test adequacy & quality |
| **root-cause** | Permanent fix vs workaround, recurrence patterns |
| **logging** | Log level appropriateness, structured logs |
| **writing** | Human-facing doc quality |
| **silent-failure** | Error swallowing, empty catch |
| **type-design** | Type-encoded invariants, avoid enum abuse |
| **db-concurrency** | InnoDB deadlock / gap lock / FOR UPDATE+INSERT / ODKU / external I/O in TX / missing retry |

## Effort-Linked Mode (`${CLAUDE_EFFORT}`)

| Effort | Critical Threshold | History | Perspectives |
|--------|---------------|---------|---------|
| `low` | 90+ | Skip | Skip writing/type-design/docs |
| `medium` (default) | 80+ | Past 90 days | All 12 |
| `high` | 70+ | Full history | + design tradeoff, dependencies |

## Execution Flow

> **Execution model**: Steps 1-4 run in `reviewer-agent` (Sonnet). Step 4.5 output returns to parent Opus for Stage B aggregation.

### Step -1: Noise Suppression

- Read diff/code/docs only. Unverified → prefix "hypothesis:". No style/preference nitpicks.
- Findings must be anchored to observed violation/regression/concrete risk in scope.
- "could be better" / "might be useful" → note/question only, never Critical/Warning.
- No unsolicited issue/task/TODO creation — today's blockers only.

### Step 0: Load History (Detect Repeats)

Read `.claude/review-history.jsonl`. Same `file:line±3` + same `focus` 3+ times → prefix `🔁 Repeated Finding (Nth time)`. History absent → skip, mark `history: unavailable`.

### Step 1: Changed File Analysis

`git diff --name-only` to determine scope. **Serena priority**: impact → `find_referencing_symbols` / interface↔impl → `find_implementations` / type check → `get_diagnostics_for_file` / structure → `get_symbols_overview`. Non-code → Grep/Read.

Default lenses: `quality` / `architecture` / `root-cause` / `security`.

| Condition | Add Perspective |
|------|---------|
| All files ∈ {`.md`, `.json`, `.yaml`, `.yml`, `.txt`, `.toml`, VERSION-like} | Limit to `docs` / `writing` / `readability` / `root-cause`; skip others (note: "docs-only mode") |
| Test file (`*_test.*`, `*.spec.*`) | `docs` |
| Logic change (non-test) | `test-coverage` + `silent-failure` |
| Type def change (`*.d.ts`, `types/*`, struct/interface added) | `type-design` |
| SQL/ORM change | `db-concurrency` |
| Mixed / uncertain | Full 12 perspectives |

### Step 2: Run Static Analysis Tools

```bash
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...
```

Judge by execution result. `command not found` / exit 127 → `static-analysis: skipped`. exit 0/1 with output → incorporate. other non-zero → Warning.

### Step 3: Cleanup Enforcement

Verify unused imports/vars/functions, backward compat remnants, progress comments. Bash/shell: detect `cmd || true` + `$? -ne 0` (always 0), duplicate `[[ -z "$x" ]]` after assignment, `&&` chains under `set -e` with unreachable failure-path.

### Step 4: Confidence Scoring (medium default)

Score 0-100 per finding: **80+** (low 90+, high 70+) → Critical / **50-79** → Warning / **25-49** → Warning / **<25** → Discard.

### Step 4.5: Self-Filter Gate (moderate strictness)

Validate each candidate (fail → discard; severity mismatch → downgrade):

- **Evidence**: anchored to diff/code/docs/tests/tool output
- **Scope**: tied to user request / code contract / changed behavior
- **Overreach**: no invented problem statement
- **Actionability**: author can fix in this change
- **Severity**: matches real impact and confidence
- **Style/preference**: backed by documented guideline (not aesthetic taste)
- **Overprescription**: a reasonable engineer would call it a defect

Discard: "cleaner / more elegant" / "verbose / shorter" / restating existing TODO / intentional design choice flagged as deviation / "consider X" without concrete defect. Zero findings is valid — never invent.

### Step 5-6: Aggregate & Record History

Append confirmed Critical/Warning (confidence ≥25) to `.claude/review-history.jsonl` (fields: date/severity/focus/file/line/finding/confidence/branch/commit).

## Output Format

```markdown
## Comprehensive Review Results
### Perspectives Checked
- architecture / quality / ...
### Critical (Confidence 80+)
- [security] SQL injection (src/api/user.ts:120) confidence 95
- 🔁 Repeated Finding (4th time): [architecture] Domain→Infra ref (src/domain/user.ts:45) confidence 85
### Warning (Confidence 25-79)
- [quality] sort.Slice → slices.Sort (pkg/sort.go:15) confidence 65
Total: Critical N / Warning N / Discarded M / 🔁 Repeated K
```

Zero findings → `### Critical: 0`. Skipped → `### skipped: <perspective> (<reason>)`. Tags: `must`=Critical / `imo`,`nits`=Warning / `q`=question.

## writing 規約 enforcement (writing / docs / comment / prompt diff 検出時のみ適用)

writing 系 diff が含まれる場合、Step 4.5 の自己確認で以下を追加 check する。

| 対象 | canonical | 主要観点 |
|---|---|---|
| 通常文章 (PR / DD / docs) | `guidelines/writing/PRINCIPLES.md` | NG 辞書 (AI 定型語 / 難読漢語 / カタカナ造語) / 文単位品質 (弱い表現 / 冗長表現) / chat → 外向き翻訳 8 観点 |
| コードコメント | `guidelines/writing/code-comment.md` | WHY / 重要 memo 2 値分類 / 削除 7 カテゴリ / 識別子保護 |
| AI / LLM 向け prompt | `guidelines/writing/prompt-engineering.md` | XML タグ分離 / few-shot 3-5 / CoT 推論先行 / positive 指示 |
| 長文文書構造 | `guidelines/writing/long-form-doc.md` | PREP / SCQA / SDS / Minto / KPT / YWT / 報告書 3 層 |

検出時は confidence-80 filter を遵守し、Critical / Warning に分類する。
