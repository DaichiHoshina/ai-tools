---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
description: Git integration — commit → push → PR/MR creation in one command. Auto-detect mode.
---

# /git-push - Git integration

Execute commit → push → PR/MR creation in single command.

## Current Git state

!`git status --short`
!`git branch --show-current`
!`git diff --stat`
!`git log --oneline -5`

## Mode detection

| Mode | Condition | Action |
|------|-----------|--------|
| **main** | on main branch or `--main` | commit → push to main |
| **pr** | on feature branch or `--pr` | commit → push → create PR |
| **branch** | `--branch <name>` | sync main → create branch → commit → push → MR/PR |

**Auto-detect**: no args → judge by current branch. main → `main`, else → `pr`.

## Options

| Option | Description |
|-----------|------|
| `--main` | Direct push to main |
| `--pr` | Create PR |
| `--branch <name>` | Create branch → push → MR/PR |
| `--draft` | Draft PR/MR |
| `-m "msg"` | Specify commit message |
| `--auto-review` | Auto-launch `/code-review:code-review` + `coderabbit:code-review` parallel post-PR create (**opt-in, pr mode only**). CodeRabbit calls external API・billing impact |
| `--no-impl-notes` | Skip IMPL_NOTES MERGED.md consumption for PR body draft (pr mode only). Default behavior: see pr mode step 4 |

## Flow

### Common

1. Check state (`git status --short` / `branch --show-current` / `diff --stat` / `log --oneline -5`)
2. **Writing memory pre-check** (commit msg / PR body draft 前必須): `mcp__serena__list_memories` で `writing_failure_*` を確認、関連ありそうなら read してアンチパターン回避。ai-tools project の auto-memory にも `~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/writing_failure_*` あり (link-overdose / compound-noun-stack 等)
3. Uncommitted changes present → analyze diff → generate Conventional Commits msg → confirm w/ user → commit
3.5. **writing check (commit message)**: commit msg draft を **生成時点で** NG 語チェックする (confirm 前)。
   - `guidelines/writing/PRINCIPLES.md` AI定型語 + 要根拠語 (source: PRINCIPLES.md) に対して grep 突き合わせ
   - Hit ≥1 → AI定型語は削除または具体表現に置換、要根拠語は直後に根拠1文追記して rewrite、再チェック (max 3 loop)
   - 3 loop 後も hit 残存 → 残存語を提示して user に続行確認
   - **注**: hook (pre-tool-use.sh) が `git commit` 実行時に AI定型語を exit 2 でブロックする。reactive な block→rewrite loop を避けるため、生成時点で proactive に回避する事前 self-check として機能する
   - **生成前想起**: PRINCIPLES.md の `**難読漢語 (block)**` / `**非日常英語 (block)**` list を出力前に想起し、和語・平易語に置換してから書く。例: 鑑みる→踏まえる、喫緊→急ぎ、leverage→使う
   - **適用範囲**: `/git-push` 経由か parent 直接 `git commit` かを問わず、**commit message を生成する全ての経路で適用する原則**。今日 block 実例: 「影響なし」(AI定型語)

### main mode

3. `git push origin main`
4. **ai-tools repo only**: `./claude-code/sync.sh to-local` (skip confirm w/ `echo y |`)
5. Display result

### pr mode

3. `git push -u origin <branch>`
4. **IMPL_NOTES detection** (skip on `--no-impl-notes`): under `~/.claude/plans/impl-notes/`, find dir whose `<feature-slug>` matches current branch name (sanitize both to kebab-case). If multiple, pick latest by timestamp prefix. If `MERGED.md` exists, read it and surface **Design decisions** + **Open questions** as PR body draft material in the user confirm step (do not auto-insert). No match → silent skip
5. `gh pr create` / `glab mr create` (auto-detect remote)
5.5. **writing check (PR body)**: PR body draft を対象に NG 語チェックを実行。
   - `guidelines/writing/PRINCIPLES.md` AI定型語 + 要根拠語 (source: PRINCIPLES.md) に対して grep 突き合わせ
   - Hit ≥1 → AI定型語は削除または具体表現に置換、要根拠語は直後に根拠1文追記して rewrite、再チェック (max 3 loop)
   - 3 loop 後も hit 残存 → 残存語を提示して user に続行確認
   - **注**: hook (pre-tool-use.sh) が `gh pr create` 実行時に AI定型語を exit 2 でブロックするため、このステップは事前 self-check として機能する
   - PR body に関連 issue/PR URL を含む場合、貼る前に `gh issue view` / `gh pr view` で番号実在を検証する (`rules/ai-output.md` `## URL / Issue・PR 番号検証` 参照)
6. Display PR/MR URL
7. **Auto-review** (`--auto-review` specified only. Default OFF, on PR success, `gh` available, GitHub only):
   - Launch `/code-review:code-review <PR#>` w/ `Bash run_in_background:true` → get bash_id_A
   - Launch `coderabbit:code-review` w/ `Bash run_in_background:true` → get bash_id_B
   - Monitor completion: sequentially get bash_id_A / bash_id_B w/ `BashOutput`
   - Success: display to user PR comment posted
   - Fail: display tool name・exit code・stderr tail 10 lines (PR create itself success)
   - GitLab/`glab` env: skip even if `--auto-review` specified (plugin unsupported, warn display)

### branch mode

3. Refresh main → create branch (`git stash` → `checkout main && pull` → `checkout -b` → `stash pop`)
4. Same as pr mode 3-7

## Remote judgment

```bash
git remote get-url origin | grep -q "gitlab"   # GitLab → glab, else gh
```

**Judgment impossible** (`git remote get-url` fail / origin unset): stop at push stage, guide "remote unset — run `git remote add origin <url>`". Skip PR/MR create.

## Commit message

Conventional Commits format: `<type>(<scope>): <subject>`

## PR description template

4 sections corresponding to `guidelines/writing/long-form-doc.md` questions:

```markdown
## Why
<why needed. 1-2 sentences w/ supporting numbers/requirements>

## What changed
<what changed. specific names>

## Testing
<verification run. if not run, state honestly>

## Review focus
<areas to check / decisions needed from reviewer>
```

**Short PR description (< 3 H3s or < 400 words)**: pass `ai-output.md` PREP 3 + PRINCIPLES.md "4 questions before writing" + "6-item pre-output checklist" + **Web 可読性 +4 項目** (1 文 60 字 / 主張型 heading / 段落 3-4 行 / 太字 scan 化、`PRINCIPLES.md` `## Web 可読性` 参照). Long PR description (Design Doc scale): long-form-doc.md 4 questions + 5 principles. Decision criteria: H3 count / word count / fits 1 screen scroll.

**Testing section style**:

Verified → specific commands, env, results (e.g. `go test ./... pass, staging p99: 320ms`).

Unverified → state honestly, no fabrication: `Not run — docs-only` / `Not run — WIP` / `Manual only — ...` / `N/A — build config only`.

Avoid: "implemented X", "improved Y" (no numbers), false test claims.

## Jira ticket link

Post-push/MR-create, if Jira ticket ID in commit msg or branch name, auto-comment MR/PR URL to ticket w/ `mcp__jira__jira_post`. ID not detected: warn only, push/MR create success (Jira integration is auxiliary, don't block main flow).

**Auto-comment body also must pass PREP 3 from `~/.claude/rules/ai-output.md` + "4 questions before writing" from PRINCIPLES.md + "6-item self-check pre-output"**. Default template example: "Conclusion: PR create complete → review request / Reason: <branch name + change summary> / Next action: <reviewer assign or unclear>".

## Cautions

- force push forbidden
- Pre-commit user confirm required
- Behind remote → propose pull

## Error handling

| Error | Action |
|--------|------|
| No changes | Exit "Already up to date" |
| reject (conflict) | Propose `git pull --rebase` |
| stash pop fail | Display conflict, guide manual resolve |
| Auth error | Guide SSH key/token confirm |
| PR/MR create fail | Display pushed branch URL |
| Auto-review fail | PR create success. Review error warn only (PR URL output already) |

ARGUMENTS: $ARGUMENTS
