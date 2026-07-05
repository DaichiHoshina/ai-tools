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

wt は単一 branch 専用の作業 dir とする。wt 内で `git switch` / `git checkout` による別 branch 切替は禁止する。別 topic の並行作業は別 wt を新設する (`git worktree add`)。

詳細 (禁止例 / 畳み手順 / 親 repo での silent 不一致問題): 手順は `CLAUDE.md ## Quick Reference` の worktree pattern に従う。

## 適用範囲

- 全 repo (ai-tools / 個人 repo / 業務 repo 問わず)
- AI が `git worktree add` を発行する時、および user に worktree 手順を提案する時
- 既存の不一致 wt に遭遇した時は user に「dir 名と branch 名がずれています、揃えますか」と 1 問確認する (`minimize-questions.md` の scope 欠落例外に該当)

## 参照

- `~/ai-tools/memory/feedback-worktree-branch-scope-guard.md` (2026-06-19 branch 混入 incident の再発防止)
- CLAUDE.md `## Quick Reference` Golden workflow の worktree pattern
