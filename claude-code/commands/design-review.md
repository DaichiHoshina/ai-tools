---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__playwright__*, mcp__context7__*
argument-hint: "[url-or-pr-number]"
description: Live UI/UX design review via Playwright (Stripe/Airbnb/Linear standards)
---

# /design-review - Live UI/UX Design Review

> Adapted from [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows/tree/main/design-review) (Patrick Ellis). Live UI review via Playwright MCP with 7-phase systematic eval. Output: Blocker/High/Medium/Nitpick triage matrix.

## When to use

- Significant UI/UX feature ready for PR
- Full responsive / accessibility / interaction validation
- Visual polish judgment (typography hierarchy, spacing, color contrast)

## Delegation

Delegate to `design-review-agent` (Sonnet). Parent Opus collects git diff and surfaces final report only.

```
Agent(subagent_type=design-review-agent, prompt=<context below>)
```

Parent prep (pass to agent):

```bash
git status
git diff --name-only origin/HEAD...
git log --no-decorate origin/HEAD...
git diff --merge-base origin/HEAD
```

Confirm preview URL (dev server) with user. If not running, start with `npm run dev` etc. before passing.

## Review phases (agent executes)

1. **Preparation**: PR description / diff scope / Playwright viewport (1440x900)
2. **Interaction & user flow**: Run main flows, verify hover/active/disabled states, destructive-action confirmation
3. **Responsiveness**: Screenshot at 1440 / 768 / 375 viewport, detect horizontal scroll / element overlap
4. **Visual polish**: alignment / spacing / typography / color / visual hierarchy
5. **Accessibility (WCAG 2.1 AA)**: Tab order / focus visible / Enter+Space activation / semantic HTML / labels / alt text / contrast 4.5:1
6. **Stability check**: form validation / content overflow / loading+empty+error states / edge cases
7. **Code health & content**: existing pattern compliance / design token usage / grammar / console errors

## Triage matrix

| Level | Meaning |
|---|---|
| **[Blocker]** | Critical failure — fix immediately |
| **[High-Priority]** | Fix before merge |
| **[Medium-Priority]** | Follow-up improvement |
| **[Nitpick]** | Minor — prefix `Nit:` |

## Communication principles

- **Problems Over Prescriptions**: Describe the problem ("adjacent elements have inconsistent spacing"), not the prescription ("set margin to 16px")
- **Evidence-Based**: Attach screenshot for visual issues; open with positive acknowledgment
- **Objective + constructive**: Assume good intent from the implementer

## Report structure

```markdown
### Design Review Summary
[positive opening + overall assessment]

### Findings

#### Blockers
- [Problem + Screenshot]

#### High-Priority
- [Problem + Screenshot]

#### Medium-Priority / Suggestions
- [Problem]

#### Nitpicks
- Nit: [Problem]
```

## Options

| Flag | Behavior |
|---|---|
| (none) | full 7-phase review |
| `--url <URL>` | explicit preview URL (default: localhost dev) |
| `--viewport <px>` | desktop viewport (default 1440) |
| `--skip-mobile` | Desktop viewport only |

## Blocker gate (parent が実行)

`design-review-agent` の出力 trailer を読み、以下の判定を行う。

- `issues_blocking != []` → 処理を停止し、`issues_blocking` の内容をそのまま user に提示して escalate する
- `status` が `failure` または `dep_unresolved` → 同様に停止 + escalate (次 step に進まない)
- `issues_blocking == []` かつ `status: success` → 次 step に進む

trailer field の意味と enum 定義は `references/agent-output-schema.md` を参照。

## References

- Project-specific augmentation: pass `context/design-principles.md` / `context/style-guide.md` from project root to agent if present. Otherwise use Stripe/Airbnb/Linear default standards
- If Playwright MCP not installed: start dev server and use Chrome DevTools as fallback (manual screenshot required)
