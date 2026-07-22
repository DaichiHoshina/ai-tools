# ai-tools worktree 作業フロー (main 直接作業の禁止)

ai-tools repo では **main で直接作業せず、worktree を切って隔離作業する**。main の直接編集は config (hooks / commands / skills) を sync 経由で即 live に影響させかねない。検証前の壊れた状態が混入するのを防ぐ。dir 名と branch 名の一致規約は `worktree-branch-name-match.md` を参照する。

## 定着手順

1. main に未 commit 変更があれば `git stash push -u -m "<desc>" <files>` で退避し、main を clean にする (自分が触っていない変更も含めて全退避する)
2. `EnterWorktree` (または `git worktree add ../ai-tools-wt-<topic> -b <topic>`) で wt を作成する
3. wt で `git stash apply` を実行し (drop でなく apply、main 側に stash を残して保険にする)、作業と検証を済ませて commit する
4. main への反映は元 repo 側で `git merge <wt-branch> --ff-only` を実行する。元 repo の main は別 worktree が掴んでいるため、wt 内から `git checkout main` はできない。必ず元 repo path で操作する
5. ff-only merge 時に元 repo の未 commit 残骸が衝突したら、wt commit と内容の一致を `diff` で確かめてから `git checkout --` で破棄する (一致確認は必須、破壊操作)
6. `git push origin main` を実行し、live 反映が必要なら `./claude-code/sync.sh to-local --yes` を続ける
7. 後始末では不要 stash の削除を user に依頼し (`! git stash drop` を session 内で実行してもらう)、commit が main に含まれることを `git branch --contains <sha>` で確かめてから `git worktree remove` + `git branch -d` で wt を畳む

## 注意点

- **未 push commit があると diverge する** (2026-07-11 実踏)。worktree を origin/main から分岐させると、local main の未 push commit を含まない branch になり、`--ff-only` merge が fail する。対処は 2 つある。(a) wt を切る前に push しておく。(b) 発生後なら wt commit を main へ `git cherry-pick <sha>` する (行が重ならなければ clean に入る)
- PR は基本不要で、ff-only の main 直接マージ運用とする (user 合意 2026-05-31)
- `git merge` / branch 削除は通常 user 確認が必須の破壊操作だが、この repo の wt フローは合意済みパターンとして確認不要とする
- worktree の前提は「未編集の状態から切る」こと。main を編集済みなら branch commit 方式に切替える (`worktree-branch-name-match.md` の後退手順 (B))
- `git stash drop` / `git stash clear` は permission denied で AI から実行できない。stash 削除は user に `! git stash drop` を session 内で打ってもらう (`!` prefix で出力が会話に入る)。代替 command での回避は deny-rule no-escalation で禁止
- **worktree 内 file に Serena 編集 tool を使わない** (2026-07-13 / 2026-07-18 実踏)。Serena の project root は main repo 固定のため、relative_path が main 側に解決されて main を誤編集するか、成功報告しつつ worktree に反映されない silent fail になる。worktree では絶対 path の Read/Edit/Write を使い、subagent への delegation prompt にも同じ制約を明記する。誤編集した場合は patch 移送 (main 側で `git diff` → `git checkout --` → worktree で `git apply`) で復旧する
- **`git worktree add` の path は絶対 path で書く** (2026-07-20 実踏)。相対 path は cwd 基準で解決されるため、cwd が `<repo>/claude-code` のサブ dir だと `../ai-tools-wt-<name>` が `<repo>/ai-tools-wt-<name>` (repo 内部) にネストして作られる。3 手いずれかを守る: (1) 絶対 path で書く (`/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools-wt-<name>`) / (2) Bash tool call の先頭で `cd <repo-root> && git worktree add ../...` と repo root への `cd` を必ずセット / (3) 作成後に `git worktree list` で actual path を verify してから mv 等を続ける
