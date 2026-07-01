# Worktree dir 名と branch 名の一致 (必須)

`git worktree add` する時は **dir basename と branch name の slug 部を必ず一致させる**。不一致は事故源。

## 原則

- `git worktree add ../<slug> -b <slug>` の形を default とする
- ai-tools canonical prefix pattern (`../ai-tools-wt-<topic>` + `-b <topic>`) を使う場合も、`<topic>` 部を dir と branch で 1:1 対応させる。prefix (`ai-tools-wt-`) の有無を除いて slug が同じであること
- 1 wt = 1 branch = 1 slug。複数 wt が同 branch を指す運用は禁止

## 禁止例

```bash
# NG: dir と branch の slug がずれる
git worktree add ../wt-foo -b feature/bar

# NG: prefix なし dir に prefix ありっぽい branch を紐付ける
git worktree add ../foo -b ai-tools-wt-foo

# NG: 既存 branch を別 slug の dir に checkout
git worktree add ../wt-review some-old-branch
```

## OK 例

```bash
# ai-tools canonical (topic = reload-fix)
git worktree add ../ai-tools-wt-reload-fix -b reload-fix

# 汎用 (slug = size-selection-doc)
git worktree add ../size-selection-doc -b size-selection-doc
```

## Why

- `git worktree list` と `git branch` の突合が目視 diff になると、誤 branch 上での commit / push を誘発する
- 並列 fan-out 時に dev agent が dir 名から branch 名を推測できず、誤 branch 共有事故を再発する (`[[feedback-worktree-branch-scope-guard]]` 2026-06-19 incident と同系)
- 事後の cleanup (`git worktree remove` + `git branch -d`) で対象 slug を 1 つ指定するだけで済む

## wt 内で branch 切替禁止

wt は **単一 branch 専用の作業 dir** とする。wt 内で `git checkout <other>` / `git switch <other>` / `git switch -` で別 branch に切り替える運用は禁止する。

### 禁止例

```bash
# NG: wt 内で main に戻る
cd ../ai-tools-wt-foo
git switch main

# NG: wt 内で別 topic branch に切り替える
cd ../ai-tools-wt-foo
git checkout bar
```

### OK 手順 (別 branch を触りたくなった時)

```bash
# 1. wt 内の作業を commit or stash してから wt を出る
cd ../ai-tools-wt-foo && git status  # clean 確認
cd -                                  # 親 repo に戻る

# 2. wt を畳む
git worktree remove ../ai-tools-wt-foo
git branch -d foo   # merge 済みなら

# 3. 親 repo で目的の branch に切り替える (main 等)
git switch main
```

もし別 topic の並行作業がしたいだけなら、既存 wt を残したまま**別 wt を新設**する:

```bash
git worktree add ../ai-tools-wt-bar -b bar
```

### Why

- wt 内で branch 切替すると dir 名 slug と HEAD branch がずれ、本 rule 冒頭の「dir 名 = branch 名」不一致状態を発生させる
- `git worktree list` の表示 (dir → branch mapping) が実態と食い違い、cleanup / ff-merge 時の対象取り違えを誘発する
- 「main に戻る」用途は wt の設計思想 (1 wt = 1 作業単位で親 repo を汚さない) と真逆。畳んでから戻るのが正
- 親 repo 側で main が既に checkout されている時に wt 内で `git switch main` すると `already checked out` で fail するが、他 branch は fail せず silent に不一致を作る

## 適用範囲

- 全 repo (ai-tools / 個人 repo / 業務 repo 問わず)
- AI が `git worktree add` を発行する時、および user に worktree 手順を提案する時
- 既存の不一致 wt に遭遇した時は user に「dir 名と branch 名がずれています、揃えますか」と 1 問確認する (`minimize-questions.md` の scope 欠落例外に該当)

## 参照

- `~/ai-tools/memory/feedback-worktree-branch-scope-guard.md` (2026-06-19 branch 混入 incident の再発防止)
- CLAUDE.md `## Quick Reference` Golden workflow の worktree pattern
