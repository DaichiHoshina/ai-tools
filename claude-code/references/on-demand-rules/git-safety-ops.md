# Git / PR 操作の安全確認 (interrupt / merge 承認 / CODEOWNERS / 他者 comment)

## 他者 comment の編集・削除禁止

GitHub Issue / PR の comment 整理では、自分の comment だけを削除・編集の対象にする。他者の comment を minimize・削除・編集するのは発言権の侵害で、collaboration の信頼を損なう。

- `gh api` 等で comment を操作する前に投稿者を確認し、自分の comment のみ対象にする
- 整理 script を書くときは `--author=@me` 等の絞り込みを必ず付ける
- 他者の情報を統合したいときは、自分の comment に引用・参照する形にする

## interrupt 後の再試行禁止

user が Esc (interrupt) した操作を同 session で explicit approval なしに再試行しない。interrupt は「この操作に疑問あり」の signal だ。

- interrupt 後は理由を確認するか、別 approach を提案する
- 状態変更 (insert / update / delete / deploy) の auto retry を厳禁とする。error 起因の retry とは区別する

## merge 示唆発言 ≠ authorization

user 発言が文脈的に merge を示唆していても、明示的な y/n がなければ `git merge` を実行しない。「〜使えばいい」「〜でやって」は suggestion であって authorization ではない。merge 前に「<src> branch を <dst> branch にマージしてよいですか? (y/n)」を必ず確認する。文脈から merge が明らかに見えても省略しない。

## CODEOWNERS auto-review-request 発火条件

既存 PR branch への push 前に auto-review-request の発火条件を確認し、満たす push は user 承認を取る。

- 発火条件: (1) 差分 500 行以上の push (2) main merge を含む push
- `git diff --stat` で行数を確認してから push を判断する
- N PR への一括 push は事前に件数と内容を明示して承認を待つ
- reviewer の手動 assign 禁止は `ai-output.md` を参照する

## 自起案の越境 repo TODO は実行前に確認する

session の scope 外 repo に触る task を AI 側が TODO として起案し、user の「N からやって」だけで実行に入って push まで進めた事故がある (2026-07-16、文体 feedback を発端に product repo の comment 修正へ越境)。user は scope を ai-tools と認識しており、revert で巻き戻した。

**Why**: user が依頼した task の TODO 化と、AI が起案した越境 task の TODO 化は承認の重みが違う。番号指定は「その項目をやる」の合意であって「別 repo の作業 branch へ push してよい」の合意ではない。plan 承認を push 承認に流用しない。

**How to apply**: 自起案 TODO が session scope 外の repo に触る場合、実行前に「対象 repo」「push の有無と範囲」を 1 行で明示して確認を取る。特に他 PR chain への push 伝播は、修正 commit 1 本でも確認必須。

## merge based chain (merge commit 5+) は rebase せず継続 merge で追従する

100+ commit の stacked PR chain で、各 branch が上流を `git merge origin/upstream` で取り込んだ history を持つ場合、後から `git rebase upstream` で並べ直すと merge commit の親関係が壊れ、conflict と force-push の連鎖で history が破壊される。**継続 merge で追従**すれば非破壊、force-push 不要で完了する。

**Why**: 2026-07-15 snkrdunk #30472 admin chain (7 branch、chain 内に merge commit 5-10 個ずつ) を Phase 2 で rebase する計画だったが、`git log` を確認したところ既に `Merge branch 'upstream' into current` が多数積まれていた。rebase すると (a) merge commit の線形化過程で 100+ conflict、(b) force-push が chain 全 branch に必要、(c) reviewer 側の追跡不能 (commit hash が全変わる)。代わりに `git merge origin/30472-admin-2 --no-edit` → `git push` を chain 順に実行した結果、conflict は 1 file の auto-merge 1 件のみで非破壊完了。

**How to apply**:

chain 更新前 30 秒判定:

```bash
# chain 内 merge commit 数を数える
git log --merges --oneline <branch> ^main | wc -l
```

- **5 個以上** → **rebase 禁止**、`git merge upstream` で追従する
- **0-4 個** → rebase 可 (通常 pattern)

merge 追従の手順 (chain 順に実行):

```bash
cd <wt-path>
git fetch origin <upstream>
git merge origin/<upstream> --no-edit
# conflict あれば手動解消 → git add → git commit --no-edit
git push origin <branch>
```

force-push 禁止 (rebase 前提の flag)。conflict は 1 file ずつ手動解消、`ort` strategy の auto-merge が効くケースが多い。

## 並列 worktree で git stash 禁止 (refs/stash が repo 共有)

並列 worktree 作業で `git stash push` / `git stash pop` を使うと、`refs/stash` は `.git/refs/stash` に単一 ref として置かれ、repo 内の全 worktree で共有される。`git stash push` は末尾に積む LIFO stack で、wt を区別しない。片方の pop が相手の stash を取り出して conflict (unmerged / `deleted by us`) 化する事故が発生する。

**Why**: 2026-07-15 の #30472 admin chain phase 0 で 4 並列 fan-out した agent が独立に `git stash push` → `git stash pop` を使った結果、片方の pop が相手の stash を先に食った。`git stash` は元々 single-worktree 前提の設計 (2007 年頃)、`git worktree` の後付け (2015) と整合が取れておらず、worktree-scoped stash は 2026-07 時点で未実装。

**How to apply**: 並列 worktree で agent を fan-out するとき、prompt に「git stash 禁止」を明記する。代替:

| 用途 | 代替 |
|---|---|
| commit 分割用に一部変更を一時退避 | `git add -p` で staged / unstaged を分ける + `git commit --only <file>` |
| 生成 file を一時退避 (make gen-api-docs 前など) | `cp <file> <file>.bak` してから再生成、`diff` で確認後 `mv .bak` |
| conflict 解消の途中避難 | `git checkout <branch> -- <file>` で target 状態に戻す |
| 検討中の変更を保留 | 一時 branch を切って commit (`git checkout -b tmp/wip`) |

リカバリ: 誤取り込みで消えた stash は `git fsck --unreachable --no-reflogs | grep commit` で dangling commit を洗い、`git stash apply <sha>` で復元できる。GC (default 90 日) 前に対応する。
