---
argument-hint: "<target> [topic-or-context]"
description: Short-form post to issue/PR/Jira/Notion/Slack — draft w/ PREP 3pts → self-check → display. Post after confirm.
allowed-tools: Bash, Read, Write
---

# /post-comment - Short-form post draft + self-check

Generate draft per `references/on-demand-rules/ai-output.md` PREP 3pts, pass 4-question self-check, display as candidate. **Post execution not here** (user runs via gh/mcp).

## Arguments

```
/post-comment [target] [topic or context]
```

| Target | Description |
|--------|-------------|
| `gh-issue` | GitHub issue creation (title + body) |
| `gh-issue-comment` | comment on GitHub issue |
| `gh-pr` | GitHub PR creation (title + body) |
| `gh-pr-comment` | comment on GitHub PR |
| `gh-pr-review` | GitHub PR review comment |
| `jira` | Jira ticket creation (summary + description) |
| `notion` | Notion page (short note/notification) |
| `slack` | Slack notification |

if target omitted, ask user.

## Flow

### Step 0: Writing memory pre-check (mandatory)

draft 生成前に `mcp__serena__list_memories` または `~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/MEMORY.md` 確認、`writing_failure_*` で関連ありそうなら read。target が gh-issue / gh-pr 系なら `writing_failure_link_overdose` / `writing_failure_compound_noun_stack` 必読相当。

### Step 1: draft generation (PREP 3pts)

```markdown
## Conclusion
<1-line: what should reader decide/do?>

## Rationale
<phenomenon / impact / (if known) root cause>

## Next Action
<assignee / deadline / unknowns>
```

For `gh-issue` / `gh-pr` / `jira`: generate title/summary (≤80 chars) separately.
Detailed logs, stack traces → `<details>` folding.

### Step 2: 4-question self-check (mandatory pass)

| # | Item | Pass? |
|---|------|-------|
| 1 | First line says "what should reader decide/do?" | ✓/✗ |
| 2 | 3+ H3s or >1-screen scroll (80 lines) | ✓/✗ |
| 3 | conclusion / rationale / next action all present? | ✓/✗ |
| 4 | evaluative words (appropriate/critical/required) backed by 1-line rationale? | ✓/✗ |

**All 4 ✓ → proceed**. Any ✗ → revise draft, retry (max 2).

### Step 2.5: writing check (NG 語チェック)

writing check: `references/writing-check-protocol.md` 参照 (対象: issue / PR comment draft、channel 共通強度)。target に issue/PR URL を含む場合は貼る前に `gh issue view` / `gh pr view` で番号実在と title 一致を検証する (`references/on-demand-rules/ai-output.md`)。

### Step 3: Display as post candidate

候補は `## 📝 Post candidate (target)` + `### Title/Summary` + `### Body (chars)` + `### self-check` ([1]-[4] ✓/✗) + `### Post command` (`gh issue comment <n> --body-file ...` 等) の section で構成する。user が "post this" と言えば AI が実行 (`--dry-run` 推奨)。

### Step 3.5: PR-scoped memory update (`gh-pr-review` のみ)

target が `gh-pr-review` かつ `~/ai-tools/memory/pr_<repo>_<number>_review.md` (命名規約・template: `commands/review.md` `## PR-scoped Memory (read → append)`) が存在する場合、**実際に post した後**に該当観点の行を更新する (draft 表示時点では更新しない、post 未確定の状態を先取りしない)。更新内容: status 列 (例: `対応中` → `check済`)、comment link 列に実際に post した URL、更新日。対応する観点が memory 側に無ければ新規行を追加する。

## Options

| Arg | Behavior |
|-----|----------|
| `--dry-run` | draft + self-check only, don't show post command |
| `--auto-post <id>` | auto-post to target after self-check pass (gh issue # / Jira key) |
| `--from-file <path>` | read draft source from file |

## Fallback

2 consecutive self-check ✗ → 残存 violations を提示し、user に 3 択 (a: allow & post / b: user 直接編集 / c: abort) を選ばせる。

## Guards

- **no auto-execution of post command** (only w/ `--auto-post`)
- long docs (Design Doc / PRD / Notion-scale) → use `/docs` / `/design-doc` (prevent misuse)
- API limits enforced by caller (GitHub: 65k chars, Slack: 4k, Jira description: 32k)

## Related

- rules: `~/.claude/references/on-demand-rules/ai-output.md` "issue/ticket/comment post rules"
- long form: `~/.claude/guidelines/writing/long-form-doc.md`
- built-in: `/git-push --pr`, `incident-response` skill
