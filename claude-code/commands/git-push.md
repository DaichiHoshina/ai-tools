---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__*
description: Git integration — commit → push → PR/MR creation in one command. Auto-detect mode.
argument-hint: "[--pr]"
---

# /git-push - Git integration

Execute commit → push → PR/MR creation in single command.

## Current Git state

!`git status --short`
!`git branch --show-current`
!`git diff --stat`
!`git log --oneline -5`

## Mode detection

**main** (on main branch / `--main`) → commit → push to main ・ **pr** (feature branch / `--pr`) → commit → push → PR ・ **branch** (`--branch <name>`) → sync main → branch 作成 → commit → push → MR/PR。Auto-detect: no args は current branch で判定 (main → `main`, else → `pr`)。

## Options

`--main` / `--pr` / `--branch <name>` / `--draft` (Draft PR/MR) / `-m "msg"` (commit msg 指定) / `--auto-review` (`/code-review` + `coderabbit:code-review` を post-PR create 並列起動、**opt-in, pr mode のみ**、CodeRabbit は external API 課金あり) / `--no-impl-notes` (PR body draft の IMPL_NOTES MERGED.md 消費 skip、pr mode のみ)

## Flow

### Common

1. Check state (`git status --short` / `branch --show-current` / `diff --stat` / `log --oneline -5`)
2. **Writing pre-check** (commit msg 生成前): `references/writing-check-protocol.md` 参照 (対象: commit message、`/git-push` / 直接 `git commit` 共通経路)。連続漢字 5 字以上の複合語は助詞挿入か訓読みで開く (structural warn 最多 pattern の先手 sweep)。Hook (`pre-tool-use.sh`) が `git commit` で block する前に潰す。
3. Uncommitted changes present → analyze diff → generate Conventional Commits msg → confirm w/ user → commit

### main mode

3. `git push origin main`
4. **ai-tools repo only**: `./claude-code/sync.sh to-local` (skip confirm w/ `echo y |`)
5. Display result

### pr mode

3. `git push -u origin <branch>`
4. **IMPL_NOTES detection** (skip on `--no-impl-notes`): `~/.claude/plans/impl-notes/` 配下で current branch (kebab-case 正規化) に一致する `<feature-slug>` dir を探索。複数なら timestamp prefix 最新を選び、`MERGED.md` があれば **Design decisions** + **Open questions** を PR body draft 候補として user confirm step に提示する (auto-insert はしない)。Open questions は `guidelines/writing/pr-description.md` `## 残論点 (Open questions) の書き方` の形式 (各案の利点・代償 + 推奨 + 理由) へ整形してから提示する。No match は silent skip。
5. `gh pr create` / `glab mr create` (auto-detect remote)
5.5. **writing check (PR body)**: `references/writing-check-protocol.md` 参照 (対象: PR body draft)。PR body の issue/PR URL は `gh issue view` / `gh pr view` で番号存在を事前検証する (`references/on-demand-rules/ai-output.md` `## URL / Issue & PR Number Validation`)。
6. Display PR/MR URL
7. **Auto-review** (`--auto-review` only, GitHub only, default OFF): `/code-review:code-review <PR#>` と `coderabbit:code-review` を `Bash run_in_background:true` で並列起動 → `BashOutput` で順次完了確認。成功は PR comment 投稿を user に表示、失敗は tool 名 / exit code / stderr tail 10 行を表示 (PR 作成自体は成功扱い)。GitLab/`glab` 環境は skip + warn 表示。

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

## PR description

**Canonical**: `guidelines/writing/pr-description.md` (ai-tools, all-repo priority). 7-section JP template (`## 背景 / ## Related Issue / ## 実装概要 / ## 影響範囲 / ## 動作確認エビデンス / ## 動作確認手順 / ## 備考`), bullet-first / `Closes #XXX` linking / anti-patterns / 動作確認手順 ≤3 項目 / review-response 規約 を 1 ヶ所に集約。本 command の writing check (step 5.5) は canonical の `## 禁止` を参照する。

**Testing section honesty (canonical 補足)**: Verified → specific commands + results (`go test ./... pass, staging p99: 320ms`). Unverified → no fabrication, state explicitly (`Not run — docs-only` / `Manual only — ...` / `N/A — build config only`).

## Jira ticket link

Post-push/MR-create, if Jira ticket ID in commit msg or branch name, auto-comment MR/PR URL to ticket w/ `mcp__jira__jira_post`. ID not detected: warn only, push/MR create success (Jira integration is auxiliary, don't block main flow).

Auto-comment body は `references/on-demand-rules/ai-output.md` (PREP 3 / 4 questions / 6-item self-check) canonical に従う。Default template: "Conclusion: PR created → review request / Reason: <branch + change summary> / Next action: <reviewer assignment or unclear>".

## Cautions

- force push forbidden
- Pre-commit user confirm required
- Behind remote → propose pull

## Error handling

No changes → "Already up to date" で終了 / reject (conflict) → `git pull --rebase` を提案 / stash pop fail → conflict 表示 + 手動解消を誘導 / Auth error → SSH key / token 確認を誘導 / PR/MR create fail → push 済 branch URL を表示 / Auto-review fail → PR 作成は成功、review error は warn のみ (PR URL は既に表示済)

ARGUMENTS: $ARGUMENTS
