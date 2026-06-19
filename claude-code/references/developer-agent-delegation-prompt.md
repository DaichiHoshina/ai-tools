# Developer Agent Delegation Prompt Template

Copy this template, fill all 6 sections (no placeholder left blank), paste to `Task(developer-agent)`.


## 0. Parent pre-delegation checklist

- [ ] target file:line 特定済 (`find_symbol` or `grep`)
- [ ] verify cmd 確定済 (build / typecheck / test / bats — single runnable cmd)
- [ ] DoD 1 行化済
- [ ] 単 domain (no mixed file groups / root causes)
- [ ] scope 明示 (`task.files` literal + 編集可な additional_files 併記、それ以外は scope creep 違反)
- [ ] blocker-on-stop 方針記載 ("blocker 検出時は独断進行禁止、`unresolved_errors[]` に書いて `status: partial` で停止")

All 6 must be ✓ before firing. Parent completes these; do not push exploration to subagent.

最後 2 項目 (scope / blocker-on-stop) は **completion 力低下対策**。曖昧 scope は subagent の「ついで修正」を誘発、blocker 黙殺は「error のまま report」を誘発する。delegation prompt に literal で含める。

## 0.5 Prompt quality rules

### A. verify cmd must be bash literal

- ❌ "check what differs" / "confirm lint passes"
- ✅ "`diff -u $A $B`; exit code 1 → report first 5 lines" / "`npm run lint 2>&1 | tail -20`; report exit 0 or stderr"

**Why**: Ambiguous verify causes result variance across same prompt, making parent oversight difficult.

### B. Parent fact-check on agent return

Do not accept agent report immediately — perform at least 1 cross-check parent-side.

- Numerical claim → verify formula/unit consistency
- Measured claim → reproduce 1 sample parent inline
- File change claim → `git diff --stat` to confirm line/file counts

**Fact-check not needed**: when verify cmd is run agent-side and included in report, and verify cmd is deterministic (lint / typecheck / bats).

**Why**: 2026-06-04 session: agent misjudged "true wall=56s", parent adopted immediately and made a downstream error. Same pattern as `[[parallel-fire-format-peak-concurrency]]`.

## 1. Target files & edits

Absolute paths + exact changes (no inference):
- `/path/to/file-A.md`: Add section "Inline exceptions" after L34 (rules table, 2 sub-rules)
- `/path/to/file-B.md`: Rename `oldFunc` → `newFunc` (L50-80), update 3 calls in file
- (new) `/path/to/file-C.md`: Create reference guide, 80-120 lines, 6 sections

Complex edits (>5 changes): list separately for sequential execution.

## 2. Verification (parent-side default)

**Default**: run parent inline after agent completion report (`bats` / `lint` / `grep` smoke etc). Agent-side verify only for:
- Build/typecheck-required languages (TypeScript / Go — self-correction on compile error)
- Commit-bearing tasks requiring pre-push confirmation

Reason: agent-side verify adds CI-equivalent time (tens of seconds to minutes) to single makespan. Parent can overlap next subagent launch with prior subagent's verify.

Available verify commands:
- **Lint**: `npm run lint` / `eslint` / `skill-lint`
- **Typecheck**: `tsc --noEmit`
- **Test**: `npm test` / `pytest` / `bats tests/`
- **Smoke**: `grep "section-name" file` or `wc -l file ≥N`
- **Structure**: `ls -la path/`

Per-task pattern (only when agent-side verify is needed):
- [ ] agent verify: `<command>` (reason: <build required / pre-commit>)
- [ ] parent verify: `<command>` (default, parent inline after completion report)

## Code comment policy (required in delegation prompt)

Agent does not write comments by default. Prohibit WHAT comments (behavior readable from code).

Write only WHY comments when non-obvious (hidden constraints / workarounds / counter-intuitive invariants).

When adding/changing comments, verify content matches actual code. Do not leave stale comments on implementation change.

Do not reference current task / PR / caller in comments ("for X" / "issue #N fix" → put in PR description).

Parent must include this policy as 1 line in delegation prompt (e.g., "Comments: WHY-only when non-obvious, verify matches code").

## 3. Commit rule (no AI footer)

Plain JP (〜する / 〜した), explicit subjects, PREP 3-point (conclusion/reason/next), HEREDOC pass.
No: `Co-Authored-By: Claude`, `Generated with`, AI markers.

NG word self-check (pre-write): 「影響なし」「完了」「効果的に」「鑑みる」「喫緊」「踏襲」「leverage」「utilize」「mitigate」「seamless」「最適化」「解消」「問題なし」(canonical: `~/.claude/guidelines/writing/PRINCIPLES.md` AI定型語 list). Generate then grep list; rewrite on hit. Hook (`pre-tool-use.sh:_check_jp_quality`) blocks post-generation, but catching at generation time reduces cost and retry churn.

Example:
```
git commit -m "$(cat <<'EOF'
developer-agent-delegation-prompt.md を圧縮した。

冗長な説明と重複 example を削除し、必須 rule（no placeholder / AI footer 禁止 / 具体例）は維持。
6 section 構造を保存して parent の template 作成 overhead を低減する。
EOF
)"
```

## 4. Push

After verification passes:
```bash
git add path/to/file-A path/to/file-B
git commit -m "$(cat <<'EOF'...EOF)"
git push origin <worktree-branch>
```

(never `git add -A`, no PR, no sync.sh unless parent approves)

## 5. Report format (≤300 words)

```
## Task completed
[1 sentence summary]

## Changed files
- `/path/to/file.md`: [change] (N lines)

## Verification
- [x] Lint: pass (or N/A)
- [x] Smoke: grep confirmed [pattern] at L<X>

Git: [hash] pushed to origin/<branch>
```

Skip: command output / full diffs / code >10 lines / AI footer.

## 6. Scope (no reverse delegation)

Execute parent's instruction fully. No scope creep, no reverse questions — report blockers to manager.
Parent observes via completion report + `git diff` + push log.

## 7. Markdown heading rename guard (when applicable)

When rename / EN conversion / wording change of markdown headings is included → follow `~/.claude/rules/markdown-anchor-sync.md`.

## 8. Implicit constraints (task-independent fixed rules)

### memory dir is non-git

`~/.claude/projects/<project>/memory/` is outside git management. Creating/updating memory file completes persistence (no commit needed).
For tasks that create memory files: even if "commit" is instructed, **memory files do not need a commit** — only ai-tools side commits are in scope.

### wt tasks: do not touch parent repo staged changes

When running under wt isolation, parent repo (`~/ai-tools/`) may have existing staged/modified files.
These are parent session's WIP — **wt agent must not touch / mention / include in commits**.
wt commits target only the wt branch; ignore parent repo state.

### Self-exclusion allowlist (files permitted to contain social-hit terms literally)

`~/ai-tools/` repo is public; writing internal product names / identifiers (social-hit terms) is blocked by `pre-tool-use.sh` by default. However the following files are in the **self-exclusion allowlist** of `rules/public-repo-private-data-block.md` and are permitted to hold social-hit terms literally as rule explanation text.

Allowlist files:
- `claude-code/rules/public-repo-private-data-block.md` (literal required as rule explanation)
- `claude-code/CLAUDE.md` (term list explanation)
- `claude-code/hooks/pre-tool-use.sh` (literal needed for block detection logic)

When the delegated task includes editing these files, the assigned dev must write internal product names literally. Canonical social-hit term list: `rules/public-repo-private-data-block.md`.

**Prohibit safe-side avoidance**: Using `<product-name>` notation or broad prefix match (`~/ghq/github.com/*`) when editing allowlist files makes block detection logic inaccurate. Literal writing is the correct implementation inside allowlist files.

**This file is NOT in the allowlist**: `developer-agent-delegation-prompt.md` itself is not included; do not write social-hit terms literally here. Cross-ref social-hit term list from `rules/public-repo-private-data-block.md`.

### Branch scope guard (wt tasks)

Before committing, confirm current branch with `git branch --show-current`.
The result must match the branch specified in this delegation prompt exactly.
If different: **stop immediately**, do not commit, report as blocker in `unresolved_errors[]`.

Commit only files listed in `task.files` (§1 target files). Committing files outside the listed scope — even if modified — is a scope violation. Stage by explicit path (`git add path/to/file`), never `git add -A` or `git add .`.
