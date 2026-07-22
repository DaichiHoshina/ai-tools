---
allowed-tools: Bash, Read, Edit
name: chain-pr-update
description: stacked PR chain (親子関係を持つ複数 PR) を最新 main / 上流 branch へ順に伝播させる。merge --no-ff 方式で force push 回避。「chain 更新」「chain 追従」「PR chain rebase」「stacked PR 更新」「chain 整合確認」で起動する。
---

# chain-pr-update

stacked PR (child の base が別 PR の head になっている 2 段以上の chain) を最新 main へ追従させる作業を、chain 全 branch を worktree で回して merge + push で伝播させる。**rebase は使わない** (履歴を破壊し force push を強いる)。

## 前提

- 各 PR の branch が別 worktree で checkout されていること (`git worktree list` で確認)
- `gh` CLI が authenticate 済み (chain 検出に使う)
- 破壊的操作 (force push) はしない前提。merge --no-ff で新規 commit を積む

## Flow

### Step 1. chain 全体の整合を確認する

`chain-status.sh` で自 open PR の全 pair を behind / ahead 集計する。

```bash
# 全 open PR chain を自動検出して集計する
~/ai-tools/claude-code/skills/chain-pr-update/chain-status.sh

# root を指定して下流だけ辿る (root 自身の behind は表示されない。root vs main の
# 追従は default モードか手動 `git rev-list --count <root>..origin/main` で別途確認する)
~/ai-tools/claude-code/skills/chain-pr-update/chain-status.sh <root-branch>

# 明示的な pair 列を渡す (chain が複数走っている時)
~/ai-tools/claude-code/skills/chain-pr-update/chain-status.sh --pairs \
  "child-a parent-a" "child-b child-a"
```

出力の `behind=N (N>0)` が付いた行が更新候補である。behind=0 は skip する。

### Step 2. 上流 root から順に merge + push を伝播させる

chain の **上流から下流の順** で 1 branch ずつ **直列** に処理する。順序が崩れる or 並列に走らせると history が壊れる (詳細は「禁止 pattern」節)。

各 branch について:

```bash
# worktree path / branch / parent / grandparent (省略可) を渡す
~/ai-tools/claude-code/skills/chain-pr-update/chain-propagate.sh \
  <worktree-dir> <branch> <parent-branch> [grandparent-branch]
```

第 4 引数 `grandparent` を渡すと **下流先取り gate** が発動する。parent が更に上流と behind な状態で child を merge しようとすると script が拒否する。

例 (14 branch chain を admin-2-reader を root として順に更新):

```bash
S=~/ai-tools/claude-code/skills/chain-pr-update
W=~/ghq/worktrees

# root branch (main 起点、grandparent なし)
$S/chain-propagate.sh $W/repo-admin-2-reader        admin-2-reader        main

# 以降は grandparent を明示して gate を効かせる
$S/chain-propagate.sh $W/repo-admin-2-plan-fixtures admin-2-plan-fixtures admin-2-reader        main
$S/chain-propagate.sh $W/repo-admin-2               admin-2               admin-2-plan-fixtures admin-2-reader
# ...以降 chain 順に続ける
```

`chain-propagate.sh` は下記を内蔵する:

- dirty check / HEAD 一致 check
- flock による同一 repo の並列実行拒否
- 下流先取り gate (grandparent 引数を渡した時のみ)
- behind=0 skip
- merge retry (最大 3 回)

conflict が出たら止まるので、手で resolve して commit + push する。

### Step 3. Step 1 を再実行して全 pair behind=0 を確認する

伝播中に main が更に進むと再度 behind が発生する。user 意図次第で再伝播する。

## 禁止 pattern (絶対に踏まない)

`chain-propagate.sh` が script レベルで拒否する 2 pattern。SKILL.md でも明示する。

### 下流先取り (child が親より先に main を merge する)

- **やってはいけない例**: parent が main と behind の状態で、`chain-propagate.sh <child-wt> child main` を叩いて child に main を先取りさせる
- **害**: 後で親→子伝播する時に、child は「main の変更 + parent 経由の同じ main 変更」を二重に merge する。conflict 頻発、reviewer から見ても history が非直線化して読めなくなる
- **正しい順**: root (parent が main の branch) から順に下流へ伝播する。root が main と同期してから次の branch を触る
- **gate**: `chain-propagate.sh` の第 4 引数 `grandparent` を渡すと発動。「parent が grandparent と behind なら child を merge しない」で script が exit する
- **例外**: root branch を main 起点で更新する時のみ grandparent なし (or `CHAIN_SKIP_GRANDPARENT_CHECK=1`) で回す

### 同一 repo での並列実行 / 並列 push

- **やってはいけない例**: 別 terminal で複数 branch の `chain-propagate.sh` を同時に kick する / `&` で背景実行して連射する
- **害**: `.git/index` の write が競合して `fatal: Unable to write index` が出る。GitHub 側も並列 push で PR base 差分が発散する。中間 branch の history が飛ぶことがある
- **gate**: `chain-propagate.sh` は `.git/chain-propagate.lock` を flock で取る。取れなければ即 exit する
- **正しい実行**: 1 branch ずつ **直列** で回す。for loop や 1 行ずつ手打ちする

## Gotchas

### rebase ではなく merge を使う理由

chain PR は force push すると reviewer の approval が消える / URL comment がずれる / 下流 chain の base が空中に浮く。**merge --no-ff で新規 merge commit を積む**方式なら force push 不要で、chain の commit history もそのまま維持される。今回の repo でも既存 chain 全て merge commit 方式で運用されている。

### `fatal: Unable to write index` は retry で解消

大量の worktree で並行に fetch / merge を走らせると index write が競合して失敗することがある。`chain-propagate.sh` は 3 回まで自動 retry する。手動運用時も同じ merge を 1〜2 回打てば通る。

### worktree path 名と branch 名が一致しないケース

`git worktree list --porcelain` で worktree path と持ち branch を確認する。名前が入れ替わっているときは `git worktree move` で揃える (直接 swap は不可、一時名を経由する)。

```bash
git worktree move path-a path-a.tmp
git worktree move path-b path-a
git worktree move path-a.tmp path-b
```

### behind=0 でも child 側の base が更新済みとは限らない

`gh pr list --json baseRefName` は PR の設定 base を返す。実際に merge が走った base の SHA は `origin/<parent>` を fetch し直して `git rev-list --count` で見る。`chain-status.sh` はこの方式を使う。

### 更新後に flaky test が落ちたら再実行する

chain 内で同一 SHA でも fail / pass が分かれる場合は flaky。まず再実行を試す:

```bash
gh run rerun <run-id> --failed
```

同じ test が chain 上流の PR で pass、下流だけ fail するケースも rerun で通ることがある。連続 fail するなら test 側 or code 側の root cause 調査に切り替える。

### root branch (chain の起点) は main を merge した後で下流に伝播する

root が behind=N なら最初に `chain-propagate.sh <root-wt> <root-branch> main` を回す。root を skip すると下流全部が古い main のままになる。

## Troubleshooting

### `fatal: '<branch>' is already used by worktree at '<path>'`

該当 branch は別 worktree で checkout 中。その worktree に `cd` して作業するか、`chain-propagate.sh` に該当 worktree path を渡す。

### `merge failed (attempt 3/3)`

3 回 retry しても失敗するときは conflict の可能性が高い。手動で `git -C <wt> merge origin/<parent>` を打って conflict marker を resolve し、`git commit` + `git push` する。

### `error: index file smaller than expected`

`.git/index` 破損。該当 worktree で `git reset` で index 再生成する。

## 検証済み動作

- 14 branch (admin 7 + app 7) を 1 run で main → 全 chain 伝播 (2026-07-22 実測、conflict 0、retry 1 回で完走)
- `chain-status.sh 30472-admin-2-reader` で BFS 走査 → 13 downstream pair 出力
