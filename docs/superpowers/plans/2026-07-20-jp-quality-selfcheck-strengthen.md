# Plan: jp-quality self-check 強化 (S1 + S2)

前段 brainstorm: 本 session (2026-07-20 pending-improvements 昇格候補 recall-100char 1319 件 / recall-kanryo 461 件 が閾値 100 の 12-13 倍で surface、本 session 内 5 分間 5 連続 block の実測を根拠) から採用判定した 2 件を実装する。「AI に思い出させる型」は却下、「既存 hook 拡張」「block 後 retry 成功率向上」の 2 経路のみ実施。

## Requirements

- [ ] S1: `_inject_chat_selfcheck_if_signal` の trigger 語を「100 字超のみ」から「turn 締め語 (完了 / 〜済 / 次に) + 100 字超 + 括弧詰め込み」に拡張する
- [ ] S2: 100 字超構造 block の block message に「2 文に割った例テンプレ」を inject する

## Architecture

- Pattern: 「AI 自発的想起」に依存しない、既存 hook 機構の拡張 + block 後 retry 成功率向上
- 変更対象: 2 file (`hooks/lib/prompt-trigger-detectors.sh:146-185` / `lib/jp-quality/block-checks.sh` の `_struct_block` 組立部)
- 既存 test: `tests/unit/lib/jp-quality-check.bats` (1071 行) を該当 case で拡張
- **rule / 辞書追加は禁止** (brainstorm skeptic の「rule 追加 3 回失敗」を尊重)

## Implementation plan

### Phase 1 (S1): chat self-check injector の trigger 語拡張

- `hooks/lib/prompt-trigger-detectors.sh:151-152` の grep 条件を確認する
- 現行: `100字超文` 固定
- 変更: `(100字超文|turn締め語文末|括弧詰め込み)` の 3 pattern OR に拡張する
- 300 秒 throttle と 24h 内 2 回反復条件は維持する (誤爆連発防止)
- 変更目安: +3 行 (grep pattern 1 箇所 + comment)

### Phase 2 (S2): block message に修正例テンプレを inject

- `lib/jp-quality/block-checks.sh` の `_struct_block` 組立部を確認する
- 現行: 100 字超文 block message は「該当文の冒頭 32 字 + → 句点で 2 文以上に分割する」のみ
- 変更: 「→ 句点で 2 文以上に分割する」の後に修正例テンプレ 1 行を追加する
  - 例文: `修正例: 「Aを削り、Bを追加した」→「Aを削った。加えて Bを追加した。」`
  - 機械分割ではなく **固定テンプレ文言 1 行** (skeptic の「機械分割は文法壊す」批判を回避)
- 変更目安: +4 行

### Phase 3: 既存 bats test の拡張

- `tests/unit/lib/jp-quality-check.bats` に以下 2 case 追加する
  - S1: turn 締め語 warn 発生時に self-check injector が発火する (現状は 100 字超のみで発火するはず)
  - S2: 100 字超 block message に修正例テンプレ 1 行が含まれる
- 既存 case を壊さないことを確認する

### Phase 4: 効果測定 baseline 取得

- 本 plan 適用前の jp-quality-block.log の状態を記録する
  - 「完了」warn 件数 (現在 1221)
  - 100 字超 warn/block 件数 (recall-100char 1319 = 7 日 window)
  - self-check injector 発火件数 (grep で `_inject_chat_selfcheck_if_signal` に該当する行を探す)
- 2026-07-27 の retrospective で after 値と比較する
- 効果指標: (a) 100 字超 warn 件数の減、(b) 完了 warn 件数の減、(c) 同 pattern の連続 block 減 (5 分間で 5 回のような cluster が減るか)

## Execution mode

- Mode: **inline** (parent Edit direct)
- Basis: 2 file の小変更、変更行数合計 <10 行、既存 hook / test 拡張のみ。agent 起動 overhead (60s+) が回収できない
- 本 session で S1 の grep 条件 1 箇所拡張と S2 の block message テンプレ追加を続けて実施し、bats で通ることを確認してから commit

## Worktree

- Needed: **Yes** (ai-tools worktree-first flow に従う)
- Branch name: `feat/jp-quality-selfcheck-strengthen`

## Rejected (蒸し返し防止)

以下は brainstorm で却下判定済。再検討したい場合は根拠を更新してから別 plan を立てる。

- **R1** 新規 rule / 辞書 pattern 追加 (rule 追加 3 回失敗と同型)
- **R2** `_STYLE_CTX_FLAG` を毎 turn / N turn ごと再 inject (context bloat と忘却対策失敗)
- **R3** 草案 → self-review → 再送の 2-step workflow (Session Efficiency 原則と衝突)
- **R4** post-hoc filter (生成後 rewrite) (hook API に本文書き換え無し)
- **R5** Chat 本文生成中の gate (原理的に不可)
- **R6** 括弧内 warn → block 昇格 (誤爆リスクあり effect 対 regression 薄)
- **R7** commit message inject 単発追加 (H1 の別 plan で扱う)

## Deferred (別 plan 候補)

- **H1** commit message template 強制 (git-push script で pre-commit template を注入し AI に空欄埋めさせる型) — scope 分離のため別 plan
- **H2** 100 字超を block から warn only に緩和 — user 明示合意が要る

## Next command

inline 実施のため Next command なし (本 turn で phase 1-4 を続けて実装する)
