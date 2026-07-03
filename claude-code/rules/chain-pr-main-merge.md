# chain PR の main merge は上流から順次伝播

`base = main` 以外の PR (chain PR) が並んでいるとき、全 PR に並列で `git merge origin/main` を実行しない。差分肥大を招く。

## 原則

- **普段は main merge しない**: chain PR の `base ↔ head` diff は GitHub UI が正しく見せる。差分が古いだけなら merge しない
- **本当に必要なときのみ実施**: conflict 解消 / 重要 security 取り込み / リリース直前の同期など
- 実施するときは **最上流 PR (base=main)** から順に伝播させる。**下流 PR は `git merge --no-ff origin/<upstream-pr-branch>`** で上流 PR の HEAD を取り込む (origin/main ではなく)
- 「全 PR に一括 main merge」は禁じ手。**並列 main merge は禁止**

## Why

base と head が異なる merge commit (同じ main HEAD を取り込んでも親 commit が違う) を生じさせると、`base ↔ head` diff に「main の数千 commit 分」が紛れ込みレビューが破綻する。過去に chain 5 PR で並列 `git merge origin/main --no-ff` を実行した結果、head PR で `+31516 / -5350 / commits=100` の異常な肥大が発生した。

## 手順 (canonical)

```bash
# 最上流 PR (base=main) — main を取り込む
git switch <upstream-pr-branch>
git merge --no-ff origin/main
git push

# 下流 PR — 上流 PR の HEAD を取り込む (main ではない)
git switch <downstream-pr-branch>
git merge --no-ff origin/<upstream-pr-branch>
git push

# chain が続く場合は 1 段ずつ順次伝播させる
```

## 差分肥大に陥った場合の復旧

各 chain PR の head に `git merge --no-ff origin/<base-pr-branch>` を上流から順次実行する。base と head の merge commit が揃い、`base ↔ head` diff が本来スコープに戻る。

## chain 自体を減らす検討

- 通常 PR は `base = main` の独立構成にし、chain は本当に必要なときのみ使う
- chain が常態化するなら spr / graphite などの PR スタック tool 導入を検討する

## 適用範囲

- 全 repo (組織を問わない)
- chain PR を運用する場面
- user 指示で「全 PR に main merge」を要求された場合は、上流から順次伝播の手順を提示してから実行する (並列処理しない)

## 参照

- CLAUDE.md `## Git Merge Prohibition`
- `rules/worktree-branch-name-match.md`
