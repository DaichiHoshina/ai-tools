# PRD: 並列 self-review reminder の逐次化検出強調

## 結論 (2026-05-31)

**本 PRD 当初の方式 (逐次化検出による強調) は実装不可能と確定した。代替として文言圧縮 (案3) を実装する。**

### 逐次化検出方式の中止理由 (原理的限界)

1. PreToolUse hook が stdin で握れる情報は `session_id` / `tool_name` / `tool_input` / `cwd` のみであり、`transcript_path` も `stop_hook_active` も渡ってこない。そのため前 Task が完了したか実行中かを hook は判別できない。
2. 時間差 (time-delta) だけでは「1 message 内の同時並列発火」と「逐次発火」を分離できない。1 message に N 個の Agent を並べる正しい並列は hook が N 回ほぼ同時に起動するため、各起動で「直前 N 秒以内に別 Task」を検出してしまい、正しい並列を逐次化と誤判定する。閾値をどう調整しても同時発火は差分がほぼ 0 秒であり分離不能である。
3. 「逐次発火の回数カウント」方式も、hook が turn 境界を観測できない以上、前 turn の Task と今 turn の Task を区別できず誤カウントする。

### 採用する代替案 (案3: checklist 文言圧縮)

commit `1baff85` で導入した 4 項目 checklist を 1 項目 + canonical 参照に圧縮する。incident `parallel-fire-format-peak-concurrency` の核心 (1 message に N 個 Agent を並べないと peak=1 に落ちる) を残し、残り項目は `references/PARALLEL-PATTERNS.md` 参照に畳む。

圧縮後文言:

```
【並列 self-review】独立 task ≥2 なら 1 message に N 個 Agent を並べる (逐次発火だと peak=1。判定詳細: references/PARALLEL-PATTERNS.md)
```

効果は token 微減と peak=1 項目への focus 集中にとどまる。当初目的の incident 再発防止 (逐次化検出) は方式限界により実現できないことを認識した上での割り切りである。

#### 同期義務 (実装時)

`tests/unit/hooks/pre-tool-use.bats` の Task test が「並列判定 self-review」を grep で検査している。圧縮後文言は「並列 self-review」に変わるため、test 側 grep 語を同一 commit で更新する (rule `markdown-anchor-sync` と同種の literal 同期)。

以下は当初設計の記録である。

## 背景と課題

直近 commit `1baff85` で、Task tool 発火直前に並列判定 self-review checklist を `additionalContext` として inject する hook を追加した。`hooks/pre-tool-use.sh` の `"Task")` case で、全 Task 発火時に 4 項目の checklist を流す実装になっている。

この実装には 2 つの弱点がある。

1. **全 Task に inject するため、慣れによる読み飛ばしが起きる**。並列が自明に不要な単発 Task (reviewer-agent や root-cause-analyzer のような単発前提の agent 起動) でも同じ reminder が出る。毎回出る reminder は回数を重ねるほど注意が薄れ、本当に矯正したい場面で効かなくなる。
2. **reminder は機械 block ではなく自己判断頼みである**。inject されても無視できる。commit message 自身が「hook は単一 tool_use しか観測できず under-parallel (不作為) を機械 block できない」と認めている。

過去 incident `parallel-fire-format-peak-concurrency` が示すとおり、繰り返し起きていた失敗は「1 message 1 Agent を N message に分けて発火し、peak concurrency が 1 に落ちる (逐次化)」というパターンである。この逐次化こそが矯正したい対象であり、単発 Task は矯正対象ではない。

## 目的

並列判定 self-review reminder を「逐次化の兆候が出ている時だけ強調する」方式に変更し、単発 Task でのノイズを減らしつつ、逐次化しかけている場面でのみ警告を強める。これにより signal/noise を改善し、本当に矯正が必要な場面での reminder の効力を回復させる。

## 対象範囲

### 含む

- `hooks/pre-tool-use.sh` の `"Task")` case における inject ロジックの変更。
- 直前の Task 発火からの経過時間を session 単位で記録する flag 機構の追加。
- 逐次化の兆候 (直前 N 秒以内に別の Task が単独発火済み) を検出した時のみ、peak=1 回避を強調する文言を追加する分岐。
- 対応する bats test の追加・更新。

### 含まない

- under-parallel の機械 block 化 (不作為は単一 tool_use から原理的に検出不可能なため、対象外とする)。
- checklist 本体の文言全面書き換え (canonical は `references/PARALLEL-PATTERNS.md` のまま維持する)。
- 単発前提 agent の subagent_type による出し分け (parent の意図は hook から判別できず、完全な出し分けは不可能なため、本 PRD では採用しない)。

## 検出ロジックの設計方針

既存の today-commit-inject 機構 (commit `abd3f14` で導入、session_id 単位の flag file で 2 回目以降の inject を抑止する仕組み) と同じ flag file 方式を再利用する。

- Task 発火のたびに、session_id をキーとした flag file に「直前の Task 発火 timestamp」を記録する。
- 新たな Task 発火時、flag file の前回 timestamp と現在時刻の差分を取る。
- 差分が閾値 N 秒以内であれば「直前に別の Task が単独で発火済み = 1 message 1 Agent の逐次発火パターン」と判定し、peak=1 回避を強調する文言を `additionalContext` に追加する。
- 差分が N 秒超、または初回発火であれば、通常の checklist のみ inject する (現行どおり)。

timestamp の単位に注意する。incident `jq-timestamp-ms-vs-s-incident` のとおり、外部 file の timestamp は必ず sample を確認してから比較する。`date +%s` (秒) で統一するか、ms を使うなら両辺を ms に揃える。

閾値 N は初期値を仮置きとし、実測で調整する。1 message 内の複数 tool_use は同時並列発火されるため flag 更新がほぼ同時刻になり差分が極小になる。逐次発火 (前 agent の STOP 待ち) は数十秒〜分の間隔が空く。この差を分離できる値を選ぶ。

## 成功基準

1. 単発 Task (前回 Task から N 秒超、または初回) では従来どおり checklist のみが inject され、強調文言は出ない。
2. 逐次発火パターン (直前 N 秒以内に別 Task が単独発火) を検出した時のみ、peak=1 回避を強調する文言が追加される。
3. 1 message 内の複数 Agent 同時発火 (正しい並列) では強調文言が出ない (同時発火は flag 差分が極小のため、逐次化と誤判定しない閾値設計が必要)。
4. 既存 bats test (today-commit-inject 系を含む) が全件 pass を維持する。
5. flag file が session_id 単位で分離され、並列 session 間で干渉しない (incident: task-count flag が空 session_id で全 session 共有されたバグ、commit `abd3f14` の修正を踏襲)。

## 検証方法

- bats unit test: 逐次発火を模した連続入力 (前回 timestamp を N 秒以内に設定した flag file を用意) で強調文言が出ることを確認する。
- bats unit test: 初回発火・N 秒超経過の入力で強調文言が出ないことを確認する。
- 既存 test 全件 pass を CI 相当 (`/lint-test`) で確認する。
- 実運用での効果は `scripts/flow-baseline.sh --summary` の peak_concurrency 分布で後追いする。逐次化 (peak=1 偏重) が減れば改善とみなす。

## リスクと留意点

- **誤判定リスク**: 閾値 N が大きすぎると、独立した 2 つの作業を別々の message で正当に発火したケースまで「逐次化」と誤判定する。小さすぎると 1 message 内同時発火を逐次化と取り違える。実測で調整前提とする。
- **flag file の汚染**: session_id が空の場合に全 session 共有となるバグ (commit `abd3f14` 既知) を再発させないこと。空 session_id 時のフォールバック挙動を test で固定する。
- **timestamp 単位の取り違え**: incident `jq-timestamp-ms-vs-s-incident` のとおり、秒と ms の混在は差分計算を破壊する。flag に書く単位と比較時の単位を統一する。

## 関連

- 直近 commit `1baff85` (本 PRD の改善対象)
- incident `parallel-fire-format-peak-concurrency` (逐次化の核心)
- incident `jq-timestamp-ms-vs-s-incident` (timestamp 単位の注意)
- commit `abd3f14` (session_id 単位 flag 機構、再利用元 + 空 session_id バグ修正)
- canonical: `references/PARALLEL-PATTERNS.md` (checklist 本体)
