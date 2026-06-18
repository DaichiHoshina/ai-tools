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
| `--auto-review` | Auto-launch `/code-review:code-review` + `coderabbit:code-review` parallel post-PR create (**opt-in, pr mode only**). CodeRabbit calls external API — billing impact |
| `--no-impl-notes` | Skip IMPL_NOTES MERGED.md consumption for PR body draft (pr mode only). Default behavior: see pr mode step 4 |

## Flow

### Common

1. Check state (`git status --short` / `branch --show-current` / `diff --stat` / `log --oneline -5`)
2. **Writing memory pre-check** (required before commit msg / PR body draft): check `writing_failure_*` via `mcp__serena__list_memories`; read relevant entries to avoid anti-patterns. ai-tools project auto-memory also at `~/.claude/projects/-Users-daichi-hoshina-ai-tools/memory/writing_failure_*` (link-overdose / compound-noun-stack etc.)
3. Uncommitted changes present → analyze diff → generate Conventional Commits msg → confirm w/ user → commit
3.5. **writing check (commit message)**: NG word check on commit msg draft **at generation time** (before confirm).
   - grep against `guidelines/writing/PRINCIPLES.md` banned AI phrases + assertion-required terms (source: PRINCIPLES.md)
   - Hit ≥1 → delete banned phrase or replace with concrete expression; append 1-sentence evidence for assertion-required terms; rewrite and re-check (max 3 loops)
   - After 3 loops with remaining hits → present remaining words, ask user to confirm continuation
   - **Note**: hook (pre-tool-use.sh) blocks banned AI phrases at `git commit` with exit 2. This pre-check avoids the reactive block→rewrite loop
   - **Pre-generation recall**: recall `**hard-to-read kanji (block)**` / `**uncommon English (block)**` lists from PRINCIPLES.md before writing; replace with plain alternatives
   - **Scope**: applies to **all paths generating commit messages**, regardless of `/git-push` or direct `git commit`

### main mode

3. `git push origin main`
4. **ai-tools repo only**: `./claude-code/sync.sh to-local` (skip confirm w/ `echo y |`)
5. Display result

### pr mode

3. `git push -u origin <branch>`
4. **IMPL_NOTES detection** (skip on `--no-impl-notes`): under `~/.claude/plans/impl-notes/`, find dir whose `<feature-slug>` matches current branch name (sanitize both to kebab-case). If multiple, pick latest by timestamp prefix. If `MERGED.md` exists, read it and surface **Design decisions** + **Open questions** as PR body draft material at user confirm step (do not auto-insert). No match → silent skip
5. `gh pr create` / `glab mr create` (auto-detect remote)
5.5. **writing check (PR body)**: apply same NG word check as step 3.5 (max 3 loops) to PR body draft. Acts as pre-check since hook blocks at `gh pr create`. If PR body includes related issue/PR URLs, verify number existence via `gh issue view` / `gh pr view` before inserting (see `rules/ai-output.md` `## URL / Issue & PR Number Validation`)
6. Display PR/MR URL
7. **Auto-review** (`--auto-review` specified only. Default OFF, on PR success, `gh` available, GitHub only):
   - Launch `/code-review:code-review <PR#>` w/ `Bash run_in_background:true` → get bash_id_A
   - Launch `coderabbit:code-review` w/ `Bash run_in_background:true` → get bash_id_B
   - Monitor completion: sequentially get bash_id_A / bash_id_B w/ `BashOutput`
   - Success: display to user PR comment posted
   - Fail: display tool name, exit code, stderr tail 10 lines (PR create itself succeeded)
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

**Short PR description (< 3 H3s or < 400 words)**: apply `ai-output.md` PREP 3 + PRINCIPLES.md "4 questions before writing" + "6-item pre-output checklist" + **web readability +4 items** (60 chars/sentence / assertion-style headings / 3-4 line paragraphs / bold for scanability — see `PRINCIPLES.md` `## Web readability`). Long PR description (Design Doc scale): long-form-doc.md 4 questions + 5 principles. Decision criteria: H3 count / word count / fits 1 screen scroll.

**Testing section style**:

Verified → specific commands, env, results (e.g. `go test ./... pass, staging p99: 320ms`).

Unverified → state honestly, no fabrication: `Not run — docs-only` / `Not run — WIP` / `Manual only — ...` / `N/A — build config only`.

Avoid: "implemented X", "improved Y" (no numbers), false test claims.

## Jira ticket link

Post-push/MR-create, if Jira ticket ID in commit msg or branch name, auto-comment MR/PR URL to ticket w/ `mcp__jira__jira_post`. ID not detected: warn only, push/MR create success (Jira integration is auxiliary, don't block main flow).

**Auto-comment body must also pass PREP 3 from `~/.claude/rules/ai-output.md` + "4 questions before writing" from PRINCIPLES.md + "6-item self-check pre-output"**. Default template: "Conclusion: PR created → review request / Reason: <branch name + change summary> / Next action: <reviewer assignment or unclear>".

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
