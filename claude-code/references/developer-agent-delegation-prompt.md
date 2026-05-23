# Developer Agent Delegation Prompt Template

Standard prompt template for handing off work to `developer-agent` when inline exceptions are exceeded.

## Usage

When parent (Opus) needs to delegate a task:

1. Copy this template
2. Fill in all 6 required sections below (no placeholder left blank)
3. Paste as the delegation prompt to `Task(developer-agent)`
4. Expect completion report ≤300 words per `agents/developer-agent.md` section "Completion report budget"

## Template

```
# Task: [title in one sentence]

## 1. Target files & edits (specific, no inference needed)

Absolute paths only; spell out exact changes:
- `/path/to/file-A.md`: Add section "Inline exceptions" after L34, with rules table and 2 sub-rules (A, B). Do not touch other sections.
- `/path/to/file-B.md`: Rename symbol `oldFunc` to `newFunc` in L50-80. Update 3 internal calls in same file. Do not rename symbol in other files.
- (new file) `/path/to/file-C.md`: Create new reference guide, 80-120 line target, placeholder `<item>` style, 6 required sections (A-F below).

If edits are complex (>5 distinct changes), list each separately; agent will execute sequentially.

## 2. Verification (mandatory, ≥1 pattern per file)

Must run after impl and confirm all pass. Examples:
- **Lint**: `npm run lint -- src/` (if exists; else `eslint` / `prettier` / syntax check)
- **Typecheck**: `tsc --noEmit` (TypeScript projects)
- **Test**: `npm test` / `pytest` / `bats tests/` (if test file exists)
- **Smoke test**: `node scripts/build.js` / manual import check `import { func } from 'file'` 
- **File structure**: `ls -la path/to/dir/` confirm files exist
- **Regex match**: `grep -E "pattern" file` confirm string/section present
- **Line count**: `wc -l file` confirm ≥N lines (for file-size-dependent changes)

For this task:
- [ ] Lint: `npm run lint` (or equivalent skill check)
- [ ] Typecheck: N/A (Markdown project, no TS)
- [ ] Test: N/A (no test files)
- [ ] Smoke: `cat file | grep "pattern"` confirm section added at L<X>
- [ ] File existence: `ls -la path/to/new-file.md`

## 3. Commit message rule (AI footer prohibited)

Commits MUST follow:
- **No AI footer**: Do not append `Co-Authored-By: Claude`, `Generated with Claude Code`, or any LLM marker
- **Plain JP** (genshijin OFF): Use full sentences (〜する / 〜した), explicit subjects, no demonstratives (「これ」「それ」「上記」→ concrete names)
- **PREP 3-point structure** (Conclusion / Reason / Next action) — see `guidelines/writing/PRINCIPLES.md:39`
- **HEREDOC pass** (`git commit -m "$(cat <<'EOF'...EOF)"`) — do not use `-m` inline strings

Example:
```
git commit -m "$(cat <<'EOF'
CLAUDE.md の Auto-Delegation section を強化し、Inline 例外判定ルールを明確化した。

従来の「1 行修正のみ」から「1 symbol body 置換 / 1 section 編集 / 期待 LLM 実行 <20s」に拡張し、
軽量 task (17-30s 予想) の Opus inline 実行を推奨。その他は developer-agent 委譲。
これにより startup overhead 20s を避け、ROI を向上させる。

developer-agent.md に Completion report budget section を新設し、
report length 300 words / 無コード貼り付け / checkboxes-only の enforcement rule を記載。
EOF
)"
```

## 4. Push / Sync instruction

After all verification passes:
- `git add path/to/file-A path/to/file-B path/to/file-C` (never `git add -A`)
- `git commit -m "$(cat <<'EOF'...message...EOF)"` (HEREDOC, no AI footer)
- `git push origin main` (direct to main, no PR — per task scope)
- `./sync.sh to-local --yes` (if this is `claude-code/` repo)

If push fails (pre-commit hook / network), report reason + state to manager.

## 5. Completion report format (≤300 words, no AI footer)

After push succeeds, return brief report (150 words):

```
## Task completed

[One sentence summary: what was done]

## Changed files
- `/path/to/file-A.md`: Added section L34-50 (12 lines)
- `/path/to/file-B.md`: Renamed symbol + updated 3 calls (5 lines changed)
- `/path/to/file-C.md` (new): Created reference guide (98 lines)

## Verification
- [ ] Lint: pass
- [ ] Smoke: grep confirmed section present (L34)
- [ ] File exist: ✓ (all 3 files)

Git push: origin/main, commit <hash> (no AI footer)
```

**Do not include**:
- Command output (unless failure)
- Full file diffs (parent will `git diff`)
- Code snippets >10 lines
- AI footer or "Generated with Claude Code"

## 6. Inline prohibition note (no reverse delegation)

Developer-agent executes the scope from parent's instruction. **No reverse delegation** to parent, no scope creep, no "is it OK if I also...?" — if unclear, report to manager.

Once `Task(developer-agent)` starts, developer owns completion. Parent observes via completion report + `git diff` + push result.

---

## Concrete example

**Parent delegates**:
```
Implement Phase 1 of the Sonnet delegation plan:

## 1. Target files & edits
- `/Users/daichi/ghq/.../CLAUDE.md`: 
  L30-50 section, add "Edit/Write declaration rule" para below L34, 
  redefine "Inline exceptions" to narrow scope (1 line / config / read-only cmd), 
  add "Inline prohibited" bullet list.
- (new) `/Users/daichi/ghq/.../references/developer-agent-delegation-prompt.md`: 
  Create template, 80-120 lines, 6 required sections.

## 2. Verification
- [ ] Lint: `npm run lint` or `skill-lint`
- [ ] Smoke: `grep -A 5 "Edit/Write declaration"` in CLAUDE.md

## 3. Commit: Plain JP, PREP, HEREDOC, no AI footer

## 4. Push: `git push origin main` → `./sync.sh to-local --yes`

## 5. Report: ≤300 words, no footer

## 6. Scope: execute Phase 1 only (Phase 2/3 are separate)
```

**Developer executes**, reports with:
```
## Task completed

Strengthened Auto-Delegation section in CLAUDE.md L30-50. 
Added "Edit/Write declaration rule", narrowed inline exceptions 
to 1 line / config value / read-only cmd, listed inline-prohibited patterns.
Created delegation-prompt.md template (98 lines, 6 sections, copy-paste ready).

## Changed files
- `/Users/daichi/.../CLAUDE.md`: 8 lines added L34-42
- `/Users/daichi/.../references/developer-agent-delegation-prompt.md` (new): 98 lines

## Verification
- [ ] Lint: pass
- [ ] Smoke: grep confirmed "Edit/Write declaration" at L35

Git: [hash] pushed to origin/main. No AI footer.
```

---

## FAQ

**Q: What if verification fails?**
A: Report `## Status: Failure` to manager with reason (lint error / test fail). Do not retry without manager approval.

**Q: Can I suggest an improvement to the scope?**
A: No. Report as "Open questions" in IMPL_NOTES (Team flow) or in completion report. Manager / PO reviews next.

**Q: How detailed should commit message be?**
A: 2-3 sentences + 1 reason line. See PREP example above. Details go into IMPL_NOTES or PR body, not commit.

**Q: AI footer — what exactly is prohibited?**
A: Any signature like `Co-Authored-By: Claude`, `Generated with`, `AI-assisted`, `🤖`, etc. Plain text + standard git author only.

