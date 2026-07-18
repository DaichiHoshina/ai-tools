---
allowed-tools: Read, Grep
name: jp-fix
description: "Japanese output readability check & rewrite (PRINCIPLES.md canonical). Used when /jp-fix is invoked."
context: fork
disallowed-tools:
  - Bash
  - Edit
  - Write
---

# jp-fix — 日本語の可読性チェック & リライト

Goal: reduce cognitive load for the reader, not just reject NG terms. Evaluates NG terms, sentence-level quality, and structure. All evaluation criteria come from `guidelines/writing/PRINCIPLES.md` canonical (no list literals inside this skill).

## Startup behavior

On `/jp-fix`, apply all self-checks below to the target text. For each hit, output the **rewritten sentence (After)** — do not stop at enumeration.

Target priority (**never ask back**):

1. ARGUMENTS has file path / pasted text → use it
2. ARGUMENTS empty → previous assistant output (latest chat turn text)
3. Neither → write new text on topic

Do not ask "What should I check?". Exclude code blocks (` ``` ` / `` ` ``) before evaluation.

## Determine medium first

Sentence length and style standards vary by medium (canonical: PRINCIPLES.md `## 媒体別構造` / `## Web 可読性`): 技術文書本文 100 字上限 (冒頭結論)、web / 短文 60 字上限 (PREP + scan)、chat は常体 plain JP。

## self-check

評価軸 canonical: `commands/jp-fix.md` §5-Axis Check ([A]-[E]) 参照。PRINCIPLES.md はコア層 (冒頭 index table「check / rewrite 実行」行の section) のみ load して A→E 順で評価する。全文 load は深い書き直し時のみ。

parent から natural-japanese lint の JSON (`references/on-demand-rules/natural-japanese-lint.md` 参照) が渡された場合、findings を [A] / [E] の評価材料に含める。`nominal_ending` (体言止めゼロ) は plain-jp 優先の裁定により不採用とする。JSON が無い場合 (paste / chat 対象) も、natural-japanese 観点 (語順 / 読点位置 / 一文一義 / 主語述語の距離 / 鋳型・文頭反復 / 翻訳調) を [A] / [E] の必須評価項目として目視で見る。

## Rewrite output format

Do not stop at hit enumeration. Output **Before → After** with rewritten text. After must use concrete action, state, or number.

```
Before: 本機能はシームレスな連携を効率的に実現します。
  → カタカナ造語(シームレス) / AI定型語(効率的に・実現します) / 読点なし長文 / 抽象
After:  認証 API と在庫 API を中断なく連携する。連携 1 回あたりの待ち時間を 200ms 短縮した。
```

If all hits = 0, report「可読性 問題なし (A-E 全通過)」.

## Hook integration

Hook block / warn behavior and log format are defined in `hooks/pre-tool-use.sh` / `hooks/user-prompt-submit.sh` (canonical). Weekly aggregation: `/analytics` command. Skip all inject: `JP_QUALITY_INJECT_OFF=1`.
