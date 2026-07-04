# flow-baseline TSV の N 乖離 root cause 調査

調査日: 2026-06-18
対象: `~/.claude/logs/flow-baseline-YYYYMMDD.tsv` column 4 (`n_dev_agents`) と column 5 (`peak_concurrency`) の乖離

## 結論

`n_dev_agents > peak_concurrency` の乖離は **「Manager の planned N vs 実 fan-out N」ではなく**、**`Task(developer-agent)` の 1 message bundle 規則違反 = parentUuid serial chain 発火** が真の root cause。

つまり「6 個の developer-agent を起動したが、最大同時並列度は 1 (= 1 個ずつ別 message で sequential 起動)」という症状であり、`commands/flow.md` L107 が警告している「Splitting into 1-per-message creates sequential chain firing (parentUuid serial)」の規則違反が parent Opus 側で発生している。

## column 定義 (canonical: `~/.claude/scripts/flow-baseline.sh`)

| column | 意味 | 計算 logic |
|---|---|---|
| 4 (`n_dev_agents`) | developer-agent tool_use の累積起動回数 | `$my_agents | length` |
| 5 (`peak_concurrency`) | 同時実行最大数 (区間スイープ法) | start +1 / end -1 の累積 max |

`peak_concurrency` は本物の並列度を表す。bundle 規則違反で 1 個ずつ起動すると `peak_concurrency=1` で固定される。

## 観測データ (過去 7d、~/.claude/logs/flow-baseline-*.tsv)

| date | topic | n_dev_agents | peak_concurrency | wall_sec |
|---|---|---|---|---|
| 2026-06-11 | 全部やる | 6 | 4 | 883 |
| 2026-06-09 | local-docs ナレッジ蓄積 | 6 | 1 | 4155 |
| 2026-06-10 | ナレッジ抽象化 | 6 | 3 | 4270 |
| 2026-06-11 | 不具合デグレ調査 | 1 | 1 | 381 |
| 2026-06-15 | BとCやろう | 2 | 2 | 1162 |
| 2026-06-16 | できるところ全部 | 4 | 2 | 2217 |
| 2026-06-17 | 次 | 7 | 3 | 4530 |

### 観測パターン

1. **完全 serial (n_dev=6 / peak=1、4155s)**: 6 agent を 1 個ずつ別 message で起動 → serial chain
2. **部分 bundle (n_dev=6 / peak=3、4270s)**: 6 agent のうち 3 が同時、残り 3 が直列
3. **適正 bundle (n_dev=2 / peak=2、1162s)**: 全 agent が 1 message bundle

(2) と (3) の差は wall_sec で 3 倍以上。bundle 規則の遵守が体感速度に直結している。

## root cause 推定

### 一次原因 (parent Opus 側)

`Task(developer-agent)` を 1 message 内で N 個 fan-out すべきところを、複数 message に分割して発火している。原因仮説:

1. **AskUserQuestion 介入**: 並列発火直前に user confirm を挟むと、message 境界が分かれて bundle 解除される
2. **長い planning narration**: fan-out 直前に説明を長く書きすぎると、tool_use を 1 message に収めるのが構造的に困難
3. **agent dependency 誤認**: Manager allocation で実は独立 task でも、parent が「先行 task 結果を待ってから次を発火」と誤判断

### 二次原因 (spec / hook 側)

`commands/flow.md` step 7 は bundle 規則を強く明記しているが、規則違反を **静的に検知する hook が存在しない**。post-tool-use hook で「直前 N message で連続 developer-agent 起動が観測されたら warn」は技術的に可能だが現状未実装。

## /flow Self-Review gate との関係

2026-06-18 に追加した Gate A (`step 6.5`) の `N consistency` 観点は「`N_chosen` と `tasks[]` 件数の一致」を検査するが、これは Manager 出力内の整合 check であり、**parent の発火 message 数までは検査対象外**。今回の root cause はそもそも Gate A の範囲外。

→ Gate A は **症状対処として的外れではない** (Manager allocation 自体の整合 check は valid) が、**本 root cause の解決は別途必要**。

## 推奨対策

1. **runtime hook 追加**: pre-tool-use.sh で `Task(developer-agent)` 連続検知 (直前 N message で N≥2 個の developer-agent 起動) → warn 出力。違反 pattern の自己検知 = compounding engineering
2. **flow.md step 7 強化**: 「fan-out 直前に AskUserQuestion / 長い narration を挟まない」を operational note として追加
3. **flow-baseline.sh 拡張**: TSV に `bundle_violations` column 追加 (peak < n_dev_agents の差分)、retrospective で集計

## 観測継続

`~/.claude/logs/flow-baseline-$(date +%Y%m%d).tsv` を週次集計し、bundle 違反率を retrospective で trend 監視する。
