# Orchestrate Mode

親 agent が N 個の developer-agent を並列発火して makespan を最小化するモードの運用規約。

## Activation

`/flow --orchestrate <task>` で起動する。`--auto` との組み合わせ (`/flow --orchestrate --auto <task>`) も可。

user trigger 例:

- 「並列実行で」 → `/flow --parallel` (自然言語 trigger、`natural-language-triggers.md` 参照)
- 「team で」「agent team で」→ `/flow` (PO→Manager→Dev 階層強制)
- 明示的に `--orchestrate` を指定した場合は本 mode が直接適用される
- 「wt 分けて」でも同等の parallel 発火が起動する

起動後、parent は以下の Pre-delegation steps を **全て完了** させてから発火する。未完了状態での発火は subagent 内探索を誘発し、makespan 増大の主因になる。

## Pre-delegation steps (parent 必須)

委譲前に 4 step を順番に実行し、各 step の出力を chat に echo する。

1. **N 自動算定**: 独立 task 数を数え、`references/PARALLEL-PATTERNS.md` の formula を適用する。formula PASS で N を確定し chat に出力する (例: `N=3, formula PASS`)。N が確定しない場合は逐次実行に downgrade する。

2. **target file:line echo**: 委譲先の file パス (絶対パス) と変更対象 line を chat に明示する。subagent に「探索してください」と投げることを禁止する。未特定なら parent が `find_symbol` / `grep` で特定してから委譲する。

3. **verify cmd echo**: 完了確認に使う単発コマンドを確定し chat に出力する (例: `bats tests/foo.bats` / `grep -c "^## " file.md`）。build / typecheck 必須 language (TypeScript / Go) の場合は subagent 内 verify を指示する。

4. **DoD 1 行 echo**: 完了条件を 1 文で固定し chat に出力する (例: `6 section 存在 + 80-100 行 + formula 重複ゼロ`)。

4 step 全て完了後に発火する。未完了項目がある場合は発火しない。


## Firing protocol

並列発火と判断したら、**text 1 行 + Task tool_use × N を同じ assistant message 内に並べる**。これが並列化の実体であり、N 個を別々の message に分けて送ると直前の agent の STOP を待つ逐次実行になり、peak_concurrency=1 に落ちる。

禁止パターン:

- message 1: `Task(developer-agent, prompt=A)` → message 2: `Task(developer-agent, prompt=B)` (逐次発火)

必須パターン:

- message 1 に `Task(developer-agent, prompt=A)` と `Task(developer-agent, prompt=B)` を同時に記述する (並列発火)

並列化判断の計算式 (critical-path reduction formula) の詳細は `references/PARALLEL-PATTERNS.md#critical-path-reduction-formula` を参照する。本 file では再記述しない。

同一 file を複数 subagent が同時編集する場合は物理的に並列禁止。結果依存 (A の出力を B が使う) の場合も同様に逐次にする。

発火直前に self-review を行う。「独立 task か」「同一 file 競合がないか」「結果依存がないか」の 3 点を確認してから tool_use を message に並べる。

## Verify allocation

build / typecheck 必須 language (TypeScript / Go) は subagent 内で verify を実行する。それ以外は parent が各 subagent の完了報告を受け取った後に inline で verify する。

parent inline verify の利点: subagent A の verify と subagent B の起動を重ねられるため makespan が短縮される。

commit-bearing の task (push 前確認が必要な場合) は例外的に subagent 内 verify を実行する。

verify 主体の判断基準と例外条件は `references/developer-agent-delegation-prompt.md` §2 を参照する。本 file では再記述しない。

## Fail behavior

| Case | 対応 action |
|---|---|
| N 算定不能 (独立 task 数が判定できない) | sequential downgrade + user に notify (「N 算定不能のため逐次実行に切り替えます」) |
| 事前準備 echo 抜け (file:line / verify cmd / DoD の未確定) | 発火を停止し、未確定項目を parent が補完してから再実行する |
| subagent 失敗 (timeout / retry 超過) | 失敗 subagent のみ sequential downgrade で parent が inline 実行、他は並列継続 |
| 1 message 内 N tool_use 形式違反 (逐次発火) | `scripts/flow-baseline.sh --summary` の `peak_concurrency distribution` で 1 偏重を検出した場合、次回発火から同一 message 並列に修正する |

subagent 失敗時の retry 上限は developer-agent.md の timeout / retry 仕様に従う (Timeout 30min / Retry 2×)。

他 subagent が完了済みの場合、失敗 subagent の再実行は parent が inline で行い、全体完了報告を遅延させない。

逐次発火違反を検出した後の修正手順: 次回同類 task 発火時に自己レビュー checklist を 1 回追加し、同一 message 内複数 tool_use の書式を守る。継続違反の場合は `scripts/flow-baseline.sh --summary` で peak_concurrency を計測して記録する。

## Related

- [`references/PARALLEL-PATTERNS.md`](PARALLEL-PATTERNS.md) — formula / N cap 8 / T_i estimation の canonical 定義
- [`references/developer-agent-delegation-prompt.md`](developer-agent-delegation-prompt.md) — parent pre-delegation checklist + verify allocation の詳細
- [`commands/flow.md`](../commands/flow.md) — `--orchestrate` activation entry と task type detection

> 本 file は orchestrate mode の運用規約のみを定義する。parallel 化の数値基準・計算式の詳細は canonical source (`PARALLEL-PATTERNS.md`) を参照すること。
