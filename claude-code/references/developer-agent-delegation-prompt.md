# Developer Agent Delegation Prompt Template

Copy this template, fill all 6 sections (no placeholder left blank), paste to `Task(developer-agent)`.

## 1. Target files & edits

Absolute paths + exact changes (no inference):
- `/path/to/file-A.md`: Add section "Inline exceptions" after L34 (rules table, 2 sub-rules)
- `/path/to/file-B.md`: Rename `oldFunc` → `newFunc` (L50-80), update 3 calls in file
- (new) `/path/to/file-C.md`: Create reference guide, 80-120 lines, 6 sections

Complex edits (>5 changes): list separately for sequential execution.

## 2. Verification

Must run after impl and confirm all pass:
- **Lint**: `npm run lint` / `eslint` / `skill-lint`
- **Typecheck**: `tsc --noEmit` (TypeScript only)
- **Test**: `npm test` / `pytest` / `bats tests/`
- **Smoke**: `grep "section-name" file` or `wc -l file ≥N`
- **Structure**: `ls -la path/` confirm files exist

Per-task pattern (≥1):
- [ ] Lint: `npm run lint` (Markdown: N/A)
- [ ] Smoke: `grep "keyword" file` at L<X>

## 3. Commit rule (no AI footer)

Plain JP (〜する / 〜した), explicit subjects, PREP 3-point (conclusion/reason/next), HEREDOC pass.
No: `Co-Authored-By: Claude`, `Generated with`, AI markers.

Example:
```
git commit -m "$(cat <<'EOF'
developer-agent-delegation-prompt.md を 179 行から 100 行以下に圧縮した。

冗長な説明と複数の example variation を削除し、必須 rule（no placeholder left blank / AI footer 禁止 / 具体例）は維持。
6 section 構造を保存して parent の template 作成 overhead を低減し、委譲閾値を下げる。

次は cross-ref を grep で propagation 確認する。
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

## 7. Markdown heading rename guard (該当時のみ)

Markdown heading の rename / EN 化 / 表記変更を含む場合 → `~/.claude/rules/markdown-anchor-sync.md` の手順に従う。

