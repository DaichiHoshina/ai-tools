# Workflow / Loop 設計の罠

`/workflow` `/loop` `commands/workflow.md` / `commands/loop.md` の template 設計・fan-out 構成を編集する時、および research / verifier / loop-until-dry を組む時に読む。

## 1. 外部 fetch は /workflow research template で fan-out する

外部 URL fetch を N 件並列でこなす task (公式 doc の version 確認・release 情報収集・複数 source 突合) は `/workflow` (research template) 一発が default 候補。2026-07-15 に 7 file の version 主張 verify を 47 秒 / null-guard 込みで完走した (parent inline なら 20 分規模、20 倍速)。

**Why**: WebFetch 単体は 1 site 30-60 秒かかる I/O bound task で、直列だと N 倍時間かかるうえ context も汚染する。Workflow tool は fan-out 並列 + `schema` で structured 返却 + `.filter(Boolean)` + `dropped: N` の null-guard を script レベルで組める。parent は task-notification 完了後の 1 message だけ受ける形で context 消費を最小化できる。

**How to apply**: 「file / URL / 情報源が 3+ 独立、内容が read-only 検証、fetch 失敗も許容 (null-guard で拾える)」の 3 条件が揃ったら `/workflow research` template を fire する。script 内で必ず `schema` + `.filter(Boolean)` + `dropped` を含める (canonical: `commands/workflow.md` § Null-guard)。parent inline (7 回逐次 WebFetch) や developer-agent fan-out (context 消費大) より先に検討する。

## 2. verifier N lens は prompt 本体を分ける

verifier N lens を組む時、lens 名だけ変えて prompt 本体を同一にすると実質単一 verifier で偽陽性が残る。lens ごとに探索先を明示的に分けると精度が上がる。

**Why**: 2026-07-22 の unused-flag 発掘 workflow で第 1 run (3 lens 同一 prompt) = 45 confirmed、第 2 run (grep-verify / natural-trigger / user-invocation の 3 lens 分離) = 38 confirmed、7 件の偽陽性 (CLAUDE.md 経由で発火する flag) を削除できた。resume は cache hit で cheap (finder 段は同一 prompt で instant、verifier のみ再走)。

**How to apply**: verifier lens は「探索元 (grep / user-facing doc / natural-language trigger 表)」で分ける。lens 名だけの diff (`grep-verify` / `context-verify` / `skeptic`) は禁止、prompt 本体に「read this specific file」等の具体指示を lens ごとに書く。majority ≥ 2/3 で採用。

## 3. loop-until-dry の dedupe は seen set

loop-until-dry pattern (K round 連続で新規ゼロ = 停止) は `seen` set (見た候補全部、確定 / 却下 問わず) で dedupe する。`confirmed` (verify 通過分) で dedupe すると verifier で却下された候補が毎 round 再発見されて dry しない。

**Why**: 2026-07-22 に workflow-templates.md § 7 の template を実 workflow (147 agent) で試した。node mock でも `seen`=3 iter 収束、`confirmed`=20 iter dry 判定不能を挙動確認済。canonical は `references/loop-engineering.md` § dedupe vs seen。

**How to apply**: `/workflow loop-until-dry <task>` を組む時、seen set を script scope 外に置き `fresh.forEach(b => seen.add(key(b)))` を verifier 前に打つ。verifier 結果で filter する `confirmed.push` とは分離する。

## 4. /loop の gate は「達成度 && 品質」2 段で組む

`/loop` の gate を「test 数 ≥N」の数量条件にすると、maker が最安の pure helper test だけで N を満たして 1 iteration で完走扱いになる (2026-07-16 dashboard-tests loop 実踏)。「対象関数名が test から grep できる」参照網羅条件に締め直して 4 group 分回った。

**Why**: gate は exit code しか見ず、maker は gate を満たす最短経路に収束する。数量・行数などの proxy 指標は「何をカバーしたか」を測れない。逆に「bats green」だけでも着手前から green で即終了する (達成度を測る条件が 1 つ要る)。

**How to apply**:
1. gate = 「達成度条件 (行数上限 / 対象 symbol の参照網羅 / skip 数上限) && 品質条件 (test green / lint 0)」の 2 段で組む
2. 文字列 match の網羅条件は false negative に注意 (do_GET を HTTP 経由で test され match しなかった例)。関数名でなく挙動で書けるならそちら
3. 運用実測: sonnet maker 1 iter ≈ $1-4、default cap $5 は 2 iter 前後で到達する。完走見込み iter 数 × $3 で `--max-cost-usd` を先に見積もる

## 5. reviewer prescribe fix の効果は独立 pipeline で cross-check する

reviewer が「この fix でこの誤爆が減るはず」と prescribe した修正を当てても、実 data の構造上 fix が効かないことがある。SDD の fix subagent は言われた通り実装するが、実 log で before/after を独立に取らないと「fix したが実は無効」の状態で ok を返す。

**Why**: 2026-07-20 の rule-recall-surface Task 2 で発覚した。reviewer が「pattern を log field-3 に絞れば bleed-through が減る」と prescribe。実 log は `連続漢字` warn と `完了` warn が同一 line に bundle されており、field 境界では分離できず 完了 count は 455 → 455 で変わらなかった。fix subagent が独立 pipeline で before/after を測って初めて発覚した。

**How to apply**: fix subagent の dispatch prompt に「fix 前後の実測値を独立 pipeline で cross-check する」を必ず入れる。集計 command の shape は fix と別 form を選ぶ。期待した差分が出ないなら DONE_WITH_CONCERNS で報告する。before/after が同値なら fix の前提を見直す。

## 関連

- `commands/workflow.md` — template 定義
- `commands/loop.md` — /loop 定義
- `references/loop-engineering.md` — loop-until-dry canonical
- `references/workflow-templates.md` — 7 template 一覧
