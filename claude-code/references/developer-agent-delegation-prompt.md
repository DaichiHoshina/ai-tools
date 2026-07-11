# Developer Agent Delegation Prompt Template

Copy this template, fill all 6 sections (no placeholder left blank), paste to `Task(developer-agent)`.

## Prompt assembly order (cache hit 率改善)

**"Static first, dynamic last"** (Anthropic 公式): 静的 section を先、動的データを末尾に置くと prompt cache が効く。Parent は §番号順でなく、静的 prefix (§0 / §0.5 / §2-§8) → 動的 suffix (§1 Target files & edits) の順で連結する。§1 を中央に挟むと以降が全部 cache miss になる。


## 0. Parent pre-delegation checklist

- [ ] target file:line 特定済 (`find_symbol` or `grep`)
- [ ] verify cmd 確定済 (build / typecheck / test / bats — single runnable cmd)
- [ ] DoD 1 行化済
- [ ] 単 domain (no mixed file groups / root causes)
- [ ] scope 明示 (`touchable_files:` YAML block + 任意の `additional_files:`、`touchable_files` / `additional_files` に記載のない path は scope creep 違反 — §1 参照)
- [ ] blocker-on-stop 方針記載 ("blocker 検出時は独断進行禁止、`unresolved_errors[]` に書いて `status: partial` で停止")
- [ ] Self-Review Gate 明示 ("完了報告前に `agents/developer-agent.md` §Self-Review Gate 4 項目を literal 実行、`self_review:` block を report YAML に含める。欠落時 parent reject")

All 7 must be ✓ before firing. Parent completes these; do not push exploration to subagent. 最後 3 項目 (scope / blocker-on-stop / Self-Review) は completion 力低下対策のため delegation prompt に literal で含める。

## Parent reject criteria (report 受領時)

報告受領後、parent は以下を **literal 確認**してから採用判定する。1 つでも欠落 → parent 側で `status: failure` 扱い、re-run か別 agent への振り直し。

1. `self_review:` block 存在 (4 項目全 ✓ または ✗ 理由付き)
2. `unresolved_errors:` field 存在 (空でも `[]` literal、欠落は failure 同等)
3. `changed_files[]` の各 path が `touchable_files` literal 含有
4. verify cmd 結果が report に literal 反映 (`agent_verify_output` or `parent_verify_planned`)

上記 self_review / unresolved_errors / changed_files / verify cmd の 4 field が無ければ「report は受け取らず再投入」を default 挙動とする。fact-check (§0.5 B) は 4 chunk 通過後の最終 layer。

## 0.5 Prompt quality rules

### A. verify cmd must be bash literal

- ❌ "check what differs" / "confirm lint passes"
- ✅ "`diff -u $A $B`; exit code 1 → report first 5 lines" / "`npm run lint 2>&1 | tail -20`; report exit 0 or stderr"

### B. Parent fact-check on agent return

Do not accept agent report immediately — perform at least 1 cross-check parent-side.

- Numerical claim → verify formula/unit consistency
- Measured claim → reproduce 1 sample parent inline
- File change claim → `git diff --stat` to confirm line/file counts
- Doc content claim (「file A は file B と重複」「§X が canonical と drift」「canonical 不在」) → plan の Phase に組み込む前に file B の該当 section を Read し、意味的 overlap を直接確認する。keyword hit と行数だけの重複判定は誤検出が多く、link 化で唯一の canonical を消す事故につながる。検証 cost が高い場合 (>5 file / >200 行 / 多数 cross-ref) は finding を保留に分類して user 判断に回す

**Fact-check not needed**: when verify cmd is run agent-side and included in report, and verify cmd is deterministic (lint / typecheck / bats). 経緯: `[[parallel-fire-format-peak-concurrency]]`。

## 1. Target files & edits

### touchable_files (MUST — scope allowlist)

Parent must include `touchable_files:` block as literal YAML in delegation prompt. Absolute paths only. Subagent rejects prompt with empty / missing block as `status: partial` blocker (`unresolved_errors[].blocker = "touchable_files missing"`).

```yaml
touchable_files:
  - /abs/path/to/file-A.md
  - /abs/path/to/file-B.md
additional_files:           # optional, read-only or commit-excluded ref files
  - /abs/path/to/ref-C.md
```

Subagent rule:
- Edit / Write / Bash mutation against any path **not in `touchable_files`** → stop immediately, report scope creep blocker
- Read on `additional_files` is allowed; Edit / Write is forbidden
- No "discovered another file that needs fixing" — record under `out_of_scope_observations[]` and stop

### Edits per file

Exact changes (no inference):
- `/abs/path/to/file-A.md`: Add section "Inline exceptions" after L34 (rules table, 2 sub-rules)
- `/abs/path/to/file-B.md`: Rename `oldFunc` → `newFunc` (L50-80), update 3 calls in file
- (new) `/abs/path/to/file-C.md`: Create reference guide, 80-120 lines, 6 sections

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

**Canonical**: `guidelines/writing/code-comment.md`。Agent must Read canonical **before** adding/editing any `// ` `# ` `-- ` `/* ` `<!-- ` line — delegation prompt MUST include this Read directive as 1 line. 要点: default = 書かない / 書くなら WHY only 1 行 / 削除 9 カテゴリ・AI marker・擬人化・stale comment は canonical の基準で自己分類して削除する (confidence < 80% の判定は discard)。

## 3. Commit rule (no AI footer)

Plain JP (〜する / 〜した), explicit subjects, PREP 3-point (conclusion/reason/next), HEREDOC pass.
No: `Co-Authored-By: Claude`, `Generated with`, AI markers.

NG word self-check (pre-write): canonical `~/.claude/guidelines/writing/PRINCIPLES.md` の AI 定型語 list で generate 後に grep し、hit したら書き直す。Hook (`pre-tool-use.sh:_check_jp_quality`) が post-generation で block するが、生成時に捕捉する方が retry 損失が小さい。

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

When rename / EN conversion / wording change of markdown headings is included → follow `~/.claude/references/on-demand-rules/markdown-anchor-sync.md`.

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
- `claude-code/CLAUDE.global.md` (term list explanation)
- `claude-code/hooks/pre-tool-use.sh` (literal needed for block detection logic)

When the delegated task includes editing these files, the assigned dev must write internal product names literally. Canonical social-hit term list: `rules/public-repo-private-data-block.md`.

**Prohibit safe-side avoidance**: Using `<product-name>` notation or broad prefix match (`~/ghq/github.com/*`) when editing allowlist files makes block detection logic inaccurate. Literal writing is the correct implementation inside allowlist files.

**This file is NOT in the allowlist**: `developer-agent-delegation-prompt.md` itself is not included; do not write social-hit terms literally here. Cross-ref social-hit term list from `rules/public-repo-private-data-block.md`.

### Branch scope guard (wt tasks)

Before committing, confirm current branch with `git branch --show-current`.
The result must match the branch specified in this delegation prompt exactly.
If different: **stop immediately**, do not commit, report as blocker in `unresolved_errors[]`.

Commit only files listed in `touchable_files` (§1 target files). Committing files outside the listed scope — even if modified — is a scope violation. Stage by explicit path (`git add path/to/file`), never `git add -A` or `git add .`.

### Stage は commit 直前まで遅延する (並行 session 対策)

git index は session 間で共有される単一状態だ。staged のまま放置すると、並行 session の `git commit` が意図せず取り込む (2026-07-10: subagent の `git mv` 6 rename が別 session の hooks fix commit に混入した)。

- commit しない task では subagent に stage させない。`git mv` の代わりに `mv` を使い、親が commit 直前に `git add` する
- commit する task では stage → commit を連続で実行し、staged 状態を跨いで放置しない
- parent 側も commit 前に `git status` で自分の変更だけが staged かを確認する

上記「Stage by explicit path」は commit を伴う task 前提の記述であり、commit しない task には適用しない。

### Shell script exec bit (new `.sh` files)

Write tool は mode 644 で file を作るため、新規 `.sh` は `100644` のまま commit されると runtime で `Permission denied` になる。New `*.sh` 作成時: (1) Write 直後に `chmod +x`、(2) commit 前に `git ls-files -s` で `100755` を確認、(3) `claude-code/hooks/` 配下なら exec-bit smoke test (`tests/unit/hooks/<name>.bats`) を追加する。経緯: `[[new-shell-script-exec-bit-rule]]`。

### Hook command path convention

`claude-code/templates/settings.json.template` の hook entry は `~/.claude/hooks/<name>.sh` 形式で参照する (`$CLAUDE_PROJECT_DIR/hooks/...` は project root を指し hooks/ が存在しないため禁止)。Verify before commit: `grep -rn '\$CLAUDE_PROJECT_DIR/hooks' claude-code/templates/` が 0 hits であること。経緯: 2026-06-20 stop-verify path incident (commit `cc8c015`)。
