---
allowed-tools: Read, Glob, Grep, Bash, Skill, Agent, AskUserQuestion, mcp__playwright__*, mcp__context7__*
description: Live UI/UX design review via Playwright (Stripe/Airbnb/Linear standards)
---

# /design-review - Live UI/UX Design Review

> Adapted from [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows/tree/main/design-review) (Patrick Ellis). Playwright MCP で実画面を動かしながら 7-phase review、最終的に Blocker/High/Medium/Nitpick 4 段階の triage matrix 出力。

## When to use

- significant UI/UX feature 完成時、PR 化前
- responsive / accessibility / interaction の総合検証
- visual polish 系の判定 (typography 階層、spacing、color contrast)

## Delegation

`design-review-agent` (Sonnet) に委譲する。parent Opus は git diff の収集と report の最終 surface のみ。

```
Agent(subagent_type=design-review-agent, prompt=<下記の context>)
```

Parent prep: 

```bash
git status
git diff --name-only origin/HEAD...
git log --no-decorate origin/HEAD...
git diff --merge-base origin/HEAD
```

を agent に渡す。preview URL (dev server) を user に確認、未起動なら `npm run dev` 等を `/run` で起動してから渡す。

## Review phases (agent が実行)

1. **Preparation**: PR 説明 / diff scope / Playwright viewport (1440x900)
2. **Interaction & user flow**: 主要 flow 実行、hover/active/disabled state、破壊操作 confirm
3. **Responsiveness**: 1440 / 768 / 375 viewport で screenshot、horizontal scroll / overlap 検出
4. **Visual polish**: alignment / spacing / typography / color / 視覚階層
5. **Accessibility (WCAG 2.1 AA)**: Tab order / focus visible / Enter/Space 動作 / semantic HTML / label / alt / contrast 4.5:1
6. **Robustness**: form validation / content overflow / loading/empty/error state / edge case
7. **Code health & content**: 既存 pattern 遵守 / design token 使用 / grammar / console error

## Triage matrix

| Level | Meaning |
|---|---|
| **[Blocker]** | Critical failure、即修正必要 |
| **[High-Priority]** | merge 前に修正 |
| **[Medium-Priority]** | follow-up improvement |
| **[Nitpick]** | minor、prefix `Nit:` |

## Communication principles

- **Problems Over Prescriptions**: 「margin を 16px に」ではなく「隣接 element と spacing が不整合」と問題を記述
- **Evidence-Based**: 視覚問題は screenshot 添付、positive acknowledge を冒頭に
- **Objective + constructive**: 実装者の good intent を前提

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
| `--url <URL>` | preview URL 明示 (default: localhost dev) |
| `--viewport <px>` | desktop viewport (default 1440) |
| `--skip-mobile` | viewport テスト desktop のみ |

## References

- 設計原則の project-specific 補強: project root の `context/design-principles.md` / `context/style-guide.md` があれば agent に渡す。無ければ Stripe/Airbnb/Linear 風 default 規範で実行
- Playwright MCP 未 install の場合 dev server 起動して chrome devtools 経由でも代替可、ただし screenshot evidence は人手撮影
