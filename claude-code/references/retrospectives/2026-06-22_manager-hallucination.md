# retrospective: manager-hallucination-2-consecutive (2026-06-22)

## task / goal

`/flow` team 階層で pending 3 phase (flow.md 圧縮 / flow-baseline.sh 4 column / agent-team-contract task_type) を着手した。1 loop 目で Manager が allocation を hallucinate、PO `modify` callback で再 allocation したが 2 loop 目も別形態で hallucinate、`refix_loop_limit: 1` 消費済で fail エスカレーション、user 判断で parent inline orchestration に降格して即決した。

## 事象 (Manager hallucination 2 連発)

### 1 loop 目: file path 化け

P2 タスク `scripts/flow-baseline.sh に 4 column 追加` を Manager が `references/PARALLEL-PATTERNS.md の baseline 列に追記` と allocation 出力した。

- 入力 (PO): `scripts/flow-baseline.sh` 末尾 append 指示、対象 file 1 件
- Manager 出力: `references/PARALLEL-PATTERNS.md` の baseline 列を編集
- 差: file path の root が `scripts/` → `references/`、ファイル名も別物、編集内容も「TSV 末尾 append」→「md table の列追加」

### 2 loop 目: scope 縮退 + 割り当て shuffle

PO oversight callback `modify` で fix_request (P2 の file path を正しく指定) を渡して再 allocation したら、今度は P3 `agent-team-contract.md §1 schema に task_type field 追加` が「contract への cross-ref を張るだけ」に後退した。同時に worktree path / branch / developer_id 割り当ても shuffle した (元: P1=dev1 / P2=dev2 / P3=dev3、再 allocation: P1=dev2 / P2=dev3 / P3=dev1 のような無意味な並び替え)。

- 入力 (PO modify): P2 の path 修正のみ。P3 は元のまま据え置きを明示
- Manager 出力: P3 を勝手に簡素化、P2 P3 の dev 割り当ても reshuffle
- 差: 「指示されたフィールド追加」→「cross-ref を張る」(意味的に別タスク)、割り当て shuffle は指示なし

`refix_loop_limit: 1` を消費済のため 2 loop 目失敗で fail escalation 発火、user 確認後 parent inline orchestration に降格した。

## root cause 仮説

### 仮説 A: PO modify callback の input contract が scope-narrow を強制していない

`agent-team-contract.md §2.2 (PO → Manager modify)` の field 一覧に「変更すべき task の id」「触らない task の id 集合」が明示されてない可能性。Manager が fix_request を受けたとき、全 allocation を再計算する自由度を持ってしまい、変更不要 task の dev 割り当て / scope まで書き換える余地が残る。

### 仮説 B: Manager の allocation 生成時に PO 入力 literal echo を強制してない

`manager-agent.md` の `## Base flow` step 1-3 では「PO instruction を analyze → task decompose → allocation create」と書いてあり、task 名・file path・scope を **そのまま literal で echo して context に焼く** 強制がない。Manager は LLM 推論で「より良い」allocation を作ろうとして、PO の literal file path や field 名を意訳・要約してしまう。1 loop 目の `scripts/flow-baseline.sh` → `references/PARALLEL-PATTERNS.md` 化けは literal echo があれば検出可能。

### 仮説 C: canonical file path 改変への hook guard 不在

`pre-tool-use.sh` の touchable_files allowlist (commit afaca1d 2026-06-25) は **Developer agent 起動時の Edit/Write 単位** で発火する。Manager の allocation 出力 (parent への return text) 段階では未介入。Manager の YAML allocation 内で `file_path: scripts/flow-baseline.sh` を書くべきところを別 path に化けても、parent はそのまま受けて Developer に投げる。parent 側 echo / 検証 layer が薄い。

## 改善案

### 案 1: PO modify callback の input contract に narrow-scope field 強制

`references/agent-team-contract.md §2.2` (PO → Manager modify) に必須 field を追加する:

- `modify_target_task_ids: [string]` — 変更すべき task id (Manager は他 task を touch 禁止)
- `unchanged_task_ids: [string]` — 触らない task id (Manager は dev 割り当て / scope を literal preserve)
- `modify_reason: string` — 1 行で fix の理由

Manager 側 fallback: `modify_target_task_ids` 欠落時は parent に re-request (stop) で fail-fast。

### 案 2: Manager allocation 出力に PO literal echo 強制

`manager-agent.md` の `## Allocation plan format` に 1 行追加:

> 各 task の `file_path` / `file_count` / `bundle_justification` は PO instruction の literal string をそのまま preserve する。意訳 / 要約 / 改名は禁止する。元 string と異なる場合は parent が allocation を reject する。

検証: parent 側で PO instruction string と Manager allocation の file_path を `grep -F` 完全一致で diff、不一致なら reject loop。実装は `commands/flow.md` step 5 (Manager output validation) に 5 行追加レベル。

### 案 3: parent allocation echo を user 提示 + 1 turn 確認

`commands/flow.md` step 5 と step 7 の間に「user に allocation summary を 1 行 echo して『この allocation で実行するか?』 1 turn 確認」を入れる。`/flow-auto` mode では skip、`/flow` (forced) のみで挟む。Manager hallucination は user 目視で即発見可能 (本事象も user が気付いた)。trade-off: 1 turn 介在で flow 中断、autonomous 性が下がる。

## 推奨

**案 1 + 案 2 のセット採用**。canonical file (contract + manager-agent) 編集のみで完結、user UX 損傷なし、parent 側 validation も 5 行追加レベル。

- 案 1: `references/agent-team-contract.md` §2.2 に 3 field 追加 (10 分)
- 案 2: `agents/manager-agent.md` に literal echo 強制 1 段落 + `commands/flow.md` step 5 に grep -F validation 5 行追加 (20 分)

案 3 は autonomous 性を損なうため見送り、`/flow-auto` には不適。1 + 2 で再発しなかったら案 3 は不要。

## 実装条件

本 retrospective doc 化のみで実装は別 session 持ち越し。実装前に以下を満たす:

- [ ] contract §2.2 の現状 field 一覧を確認 (3 field 追加で衝突しないか)
- [ ] manager-agent.md の token budget を確認 (≤300 行 cap)
- [ ] commands/flow.md の step 5 周辺 line を確認 (5 行追加で 150 行 cap を超えないか)
- [ ] bats `tests/integration/flow.bats` に hallucination 検出 case 1 件追加

## 関連 memory / commit

本事象の root data source は memory `work-context-20260622-flow-pending-3phase.md`。同系統の品質 guard 強化文脈として retrospective `2026-06-19_agent-oversight.md` (PO Gate v2 8 観点導入) があり、本 retrospective はその延長として位置付ける。

降格した parent inline orchestration で完了した 3 commit を以下に記す。`a6c1fca` (flow.md 155→125 行)、`4be0587` (flow-baseline.sh 4 column)、`17874ad` (agent-team-contract.md task_type) の 3 件で、いずれも main 直 push 済み。

## 学び

- Manager hallucination は Opus 4.7 でも 1 session 2 連発しうる。`refix_loop_limit: 1` の前提が崩れる
- parent inline orchestration は Manager 経由より file path / scope の literal preservation が確実、N=3 並列 fan-out なら 1 message 即決可能
- canonical file path の改変は touchable_files allowlist (Developer 起動時 guard) と Manager allocation literal echo (parent return 時 guard) の 2 段 guard が望ましい
