# Developer Agent Delegation Prompt Template

Copy this template, fill all 6 sections (no placeholder left blank), paste to `Task(developer-agent)`.


## 0. Parent pre-delegation checklist (parent 用、委譲前必須)

- [ ] target file:line 特定済 (`find_symbol` または `grep`)
- [ ] verify cmd 確定済 (build / typecheck / test / bats 等の単発 cmd)
- [ ] DoD 1 行化済
- [ ] 単 domain (異 file group / 異 root cause 混入なし)

4 項目全て ✓ で発火する。未充足は parent が完了させてから委譲する (探索 phase の subagent 押し付け禁止)。

## 0.5 Prompt quality rules (verify cmd literal + parent fact-check)

委譲 prompt の品質と完了報告の信頼性を担保する 2 rule。

### A. verify cmd literal 必須

委譲 prompt の verify cmd は **bash literal で実行可能な形** で渡す。「〜で確認」の動作説明は禁止。

- ❌ 「diff で何が違うか確認」「lint 通るか確認」
- ✅ 「`diff -u $A $B` 実行、exit code 1 なら差分の冒頭 5 行を報告」「`npm run lint 2>&1 | tail -20` 実行、exit 0 か stderr 内容を報告」

**Why**: agent が verify 解釈で揺れると同 prompt でも結果がバラつき、parent 監督が困難になる。

### B. Parent fact-check on agent return

agent 完了報告は **即採用せず parent 側で 1 つ以上の cross-check** を行う。

- 数値主張 → 数式 / 単位整合確認 (例: 「真の peak は X」報告に対し `n_dev × avg vs wall` で再計算)
- 実測主張 → 1 sample で parent inline 再現
- file 変更主張 → `git diff --stat` で行数 / 変更 file 数確認

**fact-check 不要 case**: verify cmd を agent 側で実行させ結果を報告に含めるよう指示済、かつ verify cmd が deterministic (lint / typecheck / bats など、再実行で同結果) な場合。

**Why**: 2026-06-04 session の peak_concurrency 検証で agent が「真の wall=56s」と誤判定、parent が即採用し後続判断を一度誤った。`[[parallel-fire-format-peak-concurrency]]` と同種「parent 自発判断依存からの脱却」。

## 1. Target files & edits

Absolute paths + exact changes (no inference):
- `/path/to/file-A.md`: Add section "Inline exceptions" after L34 (rules table, 2 sub-rules)
- `/path/to/file-B.md`: Rename `oldFunc` → `newFunc` (L50-80), update 3 calls in file
- (new) `/path/to/file-C.md`: Create reference guide, 80-120 lines, 6 sections

Complex edits (>5 changes): list separately for sequential execution.

## 2. Verification (parent 分担 default)

**verify 主体**: 委譲 task 完了報告後に **parent 側 inline** で実行 (`bats` / `lint` / `grep` smoke 等)。subagent 内 verify は以下 case のみ:
- build / typecheck 必須 language project (TypeScript / Go 等で compile error 自己訂正が必要)
- commit-bearing で push 前確認必須 (subagent 側 commit 時)

理由: subagent 内 verify は CI 相当時間 (数十秒〜分) を単発 makespan に積算する。parent が完了報告後 inline で verify すれば、次 subagent 起動と verify を重ねられる (subagent A 自身の verify は A 完了後でないと不可、ただし A の verify と subagent B 起動は並列可)。

利用可能 verify command:
- **Lint**: `npm run lint` / `eslint` / `skill-lint`
- **Typecheck**: `tsc --noEmit`
- **Test**: `npm test` / `pytest` / `bats tests/`
- **Smoke**: `grep "section-name" file` or `wc -l file ≥N`
- **Structure**: `ls -la path/`

Per-task pattern (subagent 内 verify が必要な時のみ):
- [ ] subagent verify: `<command>` (理由: <build 必須 / commit 前確認>)
- [ ] parent verify: `<command>` (default、subagent 完了報告後 parent inline)

## Code comment policy (委譲時必須明示)

subagent はコメントを default で書かない。WHAT (コードを読めば分かる動作) の説明コメントを禁止する。

コメントを書くのは WHY が非自明な時のみ (隠れた制約 / 回避策 / 直感に反する不変条件)。

コメントを追加・変更する場合、コメント内容が実コードと一致するか検証する。実装変更時に古いコメントを残さない。

現タスク・PR・呼び出し元への言及をコメントに書かない (「X 用」「issue #N 対応」等は PR 説明に書く)。

委譲 prompt 作成時、parent はこのポリシーを prompt に 1 行で再掲する (例: 「コメントは WHY 非自明時のみ、実コードと一致を検証」)。

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

## 8. Implicit constraints (task-independent fixed rules)

### memory dir は非 git

`~/.claude/projects/<project>/memory/` 配下は git 管理外。memory file 作成・更新で永続化完了 (commit 不要)。
memory file を作る task では「commit する」指示を受けても **memory file には commit 不要**、ai-tools 側 commit のみ対象。

### wt 内 task: 親 repo の staged 変更に触れない

wt isolation 下で動く時、親 repo 側 (`~/ai-tools/`) に既存 staged / modified file がある可能性あり。
これらは親 session の作業中物なので **wt agent は触らない / 言及しない / commit 対象に含めない**。
wt 内 commit は wt branch のみに対する commit、親 repo の状態は無視。

