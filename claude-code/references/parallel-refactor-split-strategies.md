# Parallel Refactor Split Strategies

> **目的**: 大量 file refactor を developer-agent N 並列に分割する戦略 library。CLAUDE.md "委譲分割義務" rule を refactor domain に特化した実装ガイド。

並列 N の formula と overhead 計算は `references/PARALLEL-PATTERNS.md` canonical。本 file は **refactor 固有の分割戦略** のみ扱う。

## 適用条件

以下を**全て満たす**場合に並列分割を検討する。

- 対象 file 数 5+
- file 間の依存が低い (同一 symbol を複数 file が参照しない)
- deadline が tight または makespan 短縮を優先する

## 3 戦略

### A. directory 単位分割

**file group を dir tree で切り、dir ごとに dev を割り当てる。**

同一 dir 内に変更が集中し、dir 間に共有 import / 共通 symbol がない場合に有効。

実例 (commit `fdd03c6`, 28 file):

| dev | target dir |
|-----|-----------|
| dev1 | `guidelines/backend/*` (mysql-performance.md, database-performance.md 他) |
| dev2 | `guidelines/common/*` (session-modes.md, investigation-protocol.md 他) |
| dev3 | `guidelines/languages/*` (eslint.md, typescript.md 他) |
| dev4 | `guidelines/writing/*` + `guidelines/operations/*` |

この分割なら 4 並列で makespan ≈ max(T_dev) に短縮できた。逐次実施より ~75% 短縮見込み。

**禁則**: dir をまたぐ cross-reference anchor を変更するとき → 同一 dev に両 file を入れるか、anchor 変更を別 phase に切り出す。

### B. layer 単位分割

**1 file 内の layer (frontmatter / body / footer) を dev 別に担当する。**

file 数が少なく、各 layer が独立している場合に有効。ただし同一 file への並列 edit は git conflict を起こすため **1 file に 1 dev のみ** という物理制約が優先される。

実用場面: 大量 file の frontmatter だけ一斉更新 + body リファクタリングを別 dev に分ける (フェーズ分割)。

```text
Phase 1: dev1-N で frontmatter 更新 (全 file)
Phase 2: dev1-N で body リファクタリング (Phase 1 完了後)
```

Phase 間の依存があるため Phase 1 完了を確認してから Phase 2 を発火する。

### C. rule 適用単位分割

**PRINCIPLES.md 等の rule ごとに dev を割り当て、各 dev が全 file の自担当 rule のみ touch する。**

rule 間に独立性があり、1 file を複数 dev が同時編集しない保証が取れる場合に有効。

例:

| dev | 担当 rule | touch する変更内容 |
|-----|----------|--------------------|
| dev1 | preamble 圧縮 | 各 file の冒頭前置きを 1 文に圧縮 |
| dev2 | code block 短縮 | 5 行超 code block を table 化 |
| dev3 | surplus examples 削減 | 例示 section を 2-3 block に削減 |

**禁則**: 同一 file を 2+ dev が同時に touch するルール割り当ては物理 conflict 確定 → 戦略 A に切り替える。

## 戦略 decision tree

```text
対象 file 5+?
  No → 逐次実行 (並列 overhead が割に合わない)
  Yes
    ↓
  dir 間の共有 symbol / anchor 変更あり?
    Yes → 依存箇所を別フェーズに切り出し → 残りを戦略 A
    No
      ↓
    1 file を複数 dev が同時 touch する rule があるか?
      Yes → 戦略 A (dir 単位) に統一
      No
        ↓
        rule 間が独立? → 戦略 C
        layer 間が独立? → 戦略 B (フェーズ分割)
        それ以外 → 戦略 A
```

## N (並列数) 概略

```text
N = min(8, ceil(total_files / 5))
```

詳細な formula (overhead 込み) は `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula` canonical。本 file は概略のみ。

## conflict 事前検出

並列 dev 起動前に以下を実行し、編集対象と modified file の重複を確認する。

```bash
# modified file と target file の重複チェック
git ls-files -m | grep -Fx -f <(echo "$TARGET_FILES")
```

重複あり → 先行 session の完了を待つか、target 振り分けを変更する。

## NG pattern (束ね禁止)

**1 dev に 28 file 全投げは逐次処理と等価。**

| パターン | 弊害 | 代替 |
|---------|------|------|
| 1 prompt に全 file を列挙 | dev 内で逐次処理、makespan = sum(T_i) | 戦略 A/B/C で dir / layer / rule 単位に分割 |
| 2+ domain (異 dir group) を 1 dev に束ねる | CLAUDE.md "委譲分割義務" 違反、makespan 累積 | domain 別に並列発火 |
| 全 file の anchor 変更を並列 dev に分散 | cross-reference desync、bats 破壊リスク | anchor 変更のみ先行フェーズで逐次実施 |

逐次 vs 並列の makespan 試算例 (commit `fdd03c6` 実績から):

```text
逐次 (1 dev, 28 file): sum(T_i) ≈ 28 × 60s = 1680s
並列 (4 dev, 戦略 A): LPT_makespan ≈ 420s + overhead_direct(4) = 420 + 100 = 520s
短縮率: (1680 - 520) / 1680 ≈ 69%
```

## 関連ドキュメント

- `references/PARALLEL-PATTERNS.md` — 並列判定 formula、N 選択 rule、worktree 適用フロー (canonical)
- `CLAUDE.md` "委譲分割義務" section — 束ね禁止 rule の根拠
- `rules/markdown-anchor-sync.md` — anchor 変更時の bats / cross-ref 同期手順
