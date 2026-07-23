# Toolchain lifecycle (痩せられる toolchain)

toolchain (claude-code 配下の定義 file 群) は本業の摩擦解消の従属物であり、増設と削除を同じ強度で仕組み化する。増加側だけ仕組み化されて削除が人力だと、未使用資産が token・保守・認知負荷として本業に逆流する。

## 増設の入場条件

skill / command / rule / hook / loop / cron の新設は、実 session で起きた摩擦 1 件を evidence として要求する。形式は「摩擦事例 1 行 + 可能なら数値 (回数・時間・block 件数)」で、「あると便利そう」「世の中で流行っている」は入場資格にしない。

## 生存条件 (sunset)

- 対象: 実行資産 (cron / loop / hook) と呼出計測可能資産 (skill / command)。rule / reference / guideline は呼出を計測できないため対象外とし、first-ctx 床値 (`scripts/first-ctx-check.sh`) で総量を監視する
- 条件: 8 週利用ゼロで archive 候補に載せる。判定材料は `scripts/skill-eval.sh` / `scripts/usage-stats.sh --zero` / analytics.db で、health report が機械集計する
- 除外: 低頻度でも必要時に重要な資産 (incident 対応等) は frontmatter に `keep: on-demand` を書けば頻度判定から外れる。tag の濫用は health report の除外一覧で可視化して抑止する

## 総量規制 (cap)

- cap = 初回 health report 時点の実測値 (下の「cap 初期値」欄)。内訳は当該 report を参照する
- cap 超過となる追加は既存資産の archive とペアで行う (one-in-one-out)。削除ペア済の追加は増減 0 と数える
- cap の引き上げは月次 health report を根拠に user が判断する。AI 単独で引き上げない
- cap 初期値: 357 file (2026-07-20 の初回 report で凍結した snapshot 値。以後の増減判定は月次 report の total と比較する)

## archive 手順

1. 参照 grep: `grep -r "<name>" claude-code/` で参照元を洗い、残参照を先に解消する
2. `git mv` で `claude-code/_archive/<category>/` へ移動する (sync 対象外 dir。`skills/_archive/` 等 sync 対象 dir 配下は不可)
3. `sync.sh to-local` で `~/.claude/` から消えたことを確認する。削除ではなく移動 + git 履歴の 2 重で可逆にする

## 責務境界

| 機構 | 対象 |
|---|---|
| 本規範 + health report | config 資産 (skill / command / hook / cron / loop) の増設 gate と棚卸し |
| `/memory-clean` | auto-memory (`memory/` 配下) のみ |
| `/retrospective` | session 分析と改善提案の生成 (棚卸しの実行系ではない) |

棚卸しの実行系は health report 1 本に寄せ、他機構は本 file への参照 link のみ持つ。

## Checklist (資産の新設・archive 判断時に見る、10 項目上限)

1. 新設に摩擦 evidence 1 件があるか
2. 既存資産の編集で足りないか (新設回避を先に検討したか)
3. cap 超過なら削除ペアを決めたか
4. auto-load 領域 (rules/ / CLAUDE.md) でなく on-demand 領域に置けないか
5. 生存条件 (8 週利用ゼロ) を資産が満たせる見込みか、`keep: on-demand` が要るか
6. archive 前に参照 grep をしたか
7. archive 先は sync 対象外の `_archive/` か
8. health report の直近抵触一覧を見たか
9. 判断 (archive 実行 / cap 引き上げ) を人間がしたか
10. report 自体を含め、この仕組みが新たな未使用資産になっていないか

## 個人 automation の状態確認手段

live-refresh 系 dashboard (数十秒間隔で自動更新する監視画面) は個人 project では default 誰も見ない。作らない、または既にあれば削除候補にする。

**Why**: 2026-07-21 の launchd 化 session で、4 job の live 状態を見るため 15 秒 refresh の Python dashboard を作った。fable 助言「15 秒 refresh は誰も見ない典型」で削除に切り替えた。通知 (Slack) が届けば必要な情報は届き、log が要る時は `tail` で足りる。live 画面は「作った本人が満足する」以外の効用が乏しい。

**How to apply**: 個人 automation の状態確認手段を設計する時、live-refresh dashboard を第一選択にしない。優先順は (1) 失敗時 push 通知 (Slack / ntfy / mail) → (2) 必要時に開く静的 log tail → (3) 実測データが十分溜まった後の週次 summary。live UI が要るのは他人監視や本番運用 SRE 用途で、個人 4 job 監視には過剰。既存の live dashboard は保守 cost 対効果を測って削除判断する。

## Related

- `scripts/toolchain-health-report.sh` — 月次集計の実行系 (第 1 月曜、maintenance cron 経由)
- `memory/sleep-triage-log.md` — sleep 提案の adopt 率の元データ
- `references/on-demand-rules/ai-tools-worktree-flow.md` — archive 移動 commit の作業手順
