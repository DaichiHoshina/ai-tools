---
description: Short-form post to issue/PR/Jira/Notion/Slack — draft w/ PREP 3pts → self-check → display. Post after confirm.
allowed-tools: Bash, Read, Write
---

# /post-comment - Short-form post draft + self-check

Generate draft per `rules/ai-output.md` PREP 3pts, pass 4-question self-check, display as candidate. **Post execution not here** (user runs via gh/mcp).

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

draft 生成後、`guidelines/writing/PRINCIPLES.md:111` AI定型語 27語 + `:94` 要根拠語 10語 に対して grep 突き合わせ。

- Hit ≥1 → AI定型語 (L111) は削除または具体表現に置換、要根拠語 (L94) は直後に根拠1文追記して rewrite、再チェック (max 2 loop)
- 3 回目突入時 (2 loop 後も Hit ≥1) → user に「AI語残存: <語リスト>、投稿続行?」確認
- 1 loop で 0 hit → 通過
- channel (Slack / Notion / Issue / PR comment) によらず同一 37 語 NG 強度を適用

### Step 3: Display as post candidate

```
## 📝 Post candidate (target: gh-pr-comment)

### Title / Summary
<generated title or "N/A (comment only)">

### Body (XXX chars)
<generated body>

### self-check
[1] ✓ conclusion first
[2] ✓ N H3s / ~XXX chars
[3] ✓ conclusion/rationale/next action all present
[4] ✓ rationale for evaluative words

### Post command (copy-paste)
gh issue comment <number> --body-file /tmp/post-XXXXX.md
# or
mcp__jira__jira_post ...
```

User copy-pastes post command or says "post this" → AI executes (recommend `--dry-run` for confirmation).

## Options

| Arg | Behavior |
|-----|----------|
| `--dry-run` | draft + self-check only, don't show post command |
| `--auto-post <id>` | auto-post to target after self-check pass (gh issue # / Jira key) |
| `--from-file <path>` | read draft source from file |

## Fallback

2 consecutive self-check ✗ → show remaining violations, ask user for approach:

```
⚠️ self-check violations (2 consecutive):
- [3] next action missing (pure info-share comment?)
- [2] 4 H3s (too long signal)

Options:
a) allow "no next action" & post (pure info-share)
b) user directly edits draft
c) abort
```

## Guards

- **no auto-execution of post command** (only w/ `--auto-post`)
- long docs (Design Doc / PRD / Notion-scale) → use `/docs` / `/design-doc` (prevent misuse)
- API limits enforced by caller (GitHub: 65k chars, Slack: 4k, Jira description: 32k)

## Related

- rules: `~/.claude/rules/ai-output.md` "issue/ticket/comment post rules"
- long form: `~/.claude/guidelines/writing/long-form-doc.md`
- built-in: `/git-push --pr`, `incident-response` skill
