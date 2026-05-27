---
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, mcp__serena__*
description: Human-facing prose quality mode (JP 規範統合)
---

## /jp-writing - Writing Quality Command

Improve human-facing prose (PR body, Design Doc body, Notion, blog, Slack, email) **readability, visibility, clarity**.

Code body, code comments, docstrings out of scope.

> **Responsibility split**:
> - `/docs` = format/structure/template compliance (Notion post/API docs/README)
> - `/design-doc` = assemble design decision document
> - `/jp-writing` = **prose quality itself** (vocab, sentence length, paragraph, signal)

## JP 執筆規範 (write/rewrite 時に必須適用)

### 文体

- 常体統一 (〜する / 〜した)、文として完結させる
- 主語を明示する (「担当者は〜」「ユーザーは〜」)
- 指示語禁止: 「これ」「それ」「上記」「前述」→ 具体名に置換する
- 半角スペース: 英数字の前後には半角スペースを入れる (`Versionチェック` → `Version チェック`、`既にdraw_slots` → `すでに draw_slots`)

### 冒頭 3 行テンプレ (報告型 doc 限定: 計測 / 障害 / RCA / 負荷試験)

```
1行目: 結論 (最大値 or 主要な変化量を含む)
2行目: 測定条件 (環境 / 負荷 / 期間)
3行目: 現場示唆 (approve / scale / 修正 のどれを読み手に決めさせるか)
```

### failure pattern 予防 checklist

- link 過多 → 本文で必須のリンクのみ残す、補足リンクは `<details>` か削除する
- 複合名詞 stack → タイトルの複合名詞は 2 個まで、抽象語の直後に具体例を 1 文添える
- 冒頭結論行に数値欠落 → 冒頭 3 行で最大値 / 測定条件 / 現場示唆を必ず書く
- **PR 文脈依存の表現**: DD §X-Y / Notion / Slack 等の社内文書参照、`incident (YYYY-MM-DD) で観測` 等の過去 incident 日付は半年〜1 年後の読者に通じない → 必要情報は本文中に書き、外部参照と日付は削除する

### NG 辞書 top (頻出)

| NG | OK |
|----|-----|
| 効果的に / 効率的に / シームレスに | 具体的な動作を書く (例: 「手動コピペを廃止する」) |
| 大幅改善 / 向上 / 強化 | p99 1.2s → 320ms (-73%) のように数値で書く |
| 〜を実現します / 〜を提供します | 主語 + 動詞の直接文にする |
| 本稿では〜について述べる | 削除して結論から書き始める |
| 適切な / 最適な / 重要な | 直後に根拠を 1 文で書く (なぜ・数値・事例) |
| 〜である / 〜となる / 当該 / 以下に示す | 常体の平易な表現に置換する |
| 状況に応じて / 適宜 | IF-THEN 形式で条件を明文化する |
| これ / それ / 上記 / 前述 | 具体名に置換する |
| `〜のため` 連鎖 (1 文 2 回以上) | 文を分割する |
| 体言止め圧縮による擬人化 (`flag 未渡しが実行を走らせない`) | 主語を明示し使役展開する (`flag を渡さない場合、実行されない`) |
| 連用形否定 (`未渡し` / `未指定時`) | 「指定されなかった場合」と展開する |
| 口語動詞 (`倒す` / `握る` / `走らせる`) | 書き言葉に置換する (`無効化する` / `保持する` / `実行する`) |
| 英単語 + `する` の動詞化 (`commit する` / `merge する` の地の文) | 日本語動詞に置換する。識別子・コマンド名はバッククォート囲みで動詞化しない |
| 専門用語 (異職種読み手向け): `middleware` / `fail-closed` / `TX` / `dead code` / `SoT` | 共通処理 / 安全側に倒す / トランザクション / 死蔵コード / 真の値。識別子・関数名・コマンド・DB カラム名は技術用語として維持 |
| 社内造語 / CS 用語の硬い表現: `派生値` / `単調減少` / `stale-write` / `race window` | `計算値` / `減る方向にしか更新されない` / `古い値による上書き` / `並行する処理が古い値で UPDATE する競合`。社内・部内でしか通じない言い回しは外向き文書 (PR / DD / Notion) では平易化する |

詳細規範: `guidelines/writing/README.md` / AI 出力禁止: `rules/ai-output.md`

### 「変に略さない」原則

省略より明瞭さを優先する。体言止め圧縮で語数を削ると文章が擬人化・主語不明で破綻する。

- 物 / 状態 / flag を主語にした使役文は擬人化として書き直し対象
- fail-safe / fallback の説明テンプレ: **「{取得失敗} の場合は {既定値} で続行」+「{誤操作} があった場合に意図せず {副作用} が発生することを防ぐ目的」** の 2 文構成

### textlint 観点 (機械検出可能な NG)

- 末尾「。」抜け / 1 文 100 文字超 / 漢字 7 連続 / 助詞重複 / である-ですます混在 / 読点 3 個超
- 識別子 (関数名 / コマンド / DB カラム) は技術用語として例外扱い
- `CodeRabbit` auto-gen 部分など機械生成領域の指摘は管轄外 (自分が書いた部分のみ修正対象)

### PR body MECE 構造

- **構造順**: `背景 → Related Issue → 実装概要 → (設計詳細) → 依存・マージ順序 → 影響 → 動作確認 → 補足 → CodeRabbit Summary`
- 「補足」「備考」「最新ステータス」は **CodeRabbit Summary の前** に置く (auto-gen 領域の後ろは読まれない)
- 検証は `## 動作確認` 1 セクションに統合し、`### ローカル` / `### dev` 等の小見出しで時系列分離する
- 時系列の追記 (「追加対策」「最新ステータス」等) は既存セクションに統合する。後付け H2 を並べない
- 箇条書きは 1 行に結論を入れ、詳細値 (commit hash / 関数名 / 数値) は同行内 `()` に添える
- 表の軸は 2 列統一 (3 列以上は読み負担増)

### 長い WHY 説明の 3 箇所分散パターン

設計判断の WHY を 1 箇所に集中させた 10 行超のコメントブロックは「該当コードより長い」読み負担を生む。**全体方針 + 個別 WHY を切り分け、関連コードの直上に分散配置**する。

- **集中型 (アンチパターン)**: 関数頭 or 処理ブロック頭に 10 行以上の WHY を全部置く。後段コードを読む際に上に戻る必要がある
- **分散型 (推奨)**: 以下 3 階層に分ける
  - **全体方針 (関数・ブロック頭、2-3 行)**: なぜこの設計か / 何を排除したか / 失敗時の挙動の総論
  - **個別の WHY (操作行の直上、1-2 行)**: timeout 分割、ガード句、placeholder 選択など各操作の根拠
  - **同 TX 整合性等の局所制約 (該当 SQL の直上、1-2 行)**: WHERE 句のガード条件、INSERT/UPDATE 順序の理由

13 行 → 3 ブロック分散 (3+2+2) の実例: 別 TX 同期処理の WHY を「subquery 排除の理由」(関数頭) / 「個別 timeout の理由」(SELECT 直上) / 「単調減少ガードの理由」(UPDATE 直上) に分けると、各 WHY が読み手の視線位置に届く。

判断基準:
- WHY のコアは保持する (regression 防止根拠、設計判断の前提)
- 重複 (失敗時自動修復が 2 回登場等) は統合する
- 補足情報 (incident 日付 / バージョン依存の挙動断定) は削除する

## Subcommand

| sub | purpose | input | output |
|-----|---------|-------|--------|
| `write` (default) | write from scratch | goal/reader/topic | draft |
| `rewrite` | rewrite existing | file or paste | revision + reason (3 line max per change) |
| `review` | proofread (no edit) | file or paste | 5-axis check + finding list |
| `outline` | structure only | goal/reader/topic | heading hierarchy + intent per section |

no arg or `write` → write mode.
**ARGUMENTS parse**: first token vs subcommand match, no match → treat whole arg as write topic.

## Pre-execution (required order)

### 1. Temp Turn OFF genshijin (by output type)

| Output Type | Prose |
|---------|----------|
| write/rewrite body/draft | normal Japanese |
| outline heading/intent | normal Japanese |
| review finding/score | genshijin |
| progress/confirm/error | genshijin |

### 2. 4-Question Checkpoint (pre-write, mandatory)

```
1. Who reads? (reader background/interest)
2. What decide/understand? (target judgment)
3. How act after? (intended behavior)
4. Evidence for claim? (number/case/compare)
```

If any unconfirmed, ask **top 1 only** (priority: reader > judgment > action > evidence).
Post-answer, if still unconfirmed, continue with design-memo default:

- reader = same-role engineer / judgment = boost understanding / action = reader optional / evidence = optional

**Mark in design memo: `estimated: {Q}={value}`**.

### 3. Load Resources (heading anchor extract)

Main: `guidelines/writing/PRINCIPLES.md` (~180 line) full load OK. Detailed pattern: need? load `references/writing-patterns.md` heading anchor only.

PRINCIPLES.md main sections:

- `## Top Priority — Lower Reader Cognition Load` / `## Pre-write 4 Questions` / `## Keep (7 principles)` / `## Avoid Patterns`
- `## Kill AI Smell 3 Transform` + nested `### NG Dictionary (delete targets)`
- `## Avoid Patterns` / `## Pre-output Self-Check (6 items, 5+ pass)`

### 4. Dynamic Load by Type

| Detect Keyword | Extra Load |
|---------|-----------|
| Notion / page | `guidelines/common/notion-writing.md` |
| Design Doc / ADR / RCA | `guidelines/writing/design-doc-protocol.md` |
| PR / pull request | `guidelines/writing/pr-description.md` |
| rewrite | `references/document-iteration-patterns.md` + `references/writing-patterns.md` "Rewrite Phase 1-8" |

## 5-Axis Check (review/rewrite required)

```
[A] readability: 1 sentence ≤60 chars / paragraph 3-5 sentences / explicit subject
[B] visibility: heading hierarchy / bullet use / tables for types
[C] signal: PREP or TL;DR+detail / conclusion first
[D] evidence: praise word + number/case (AI smell 3-transform)
[E] coherence: term consistency / no duplication / NG dict hit 0
```

Each 0-3 pts, total 11/15+ pass (= avg 2.2, all ≥2 + 1 full assumed practical threshold). Below: cite specific point.

> **5-axis vs 6-item pre-output**:
> - 5-axis = **evaluate** output quality (review/rewrite output score)
> - 6-item pre-output = **gate** just-before-output (PRINCIPLES.md derived, 5+ pass)
> Both pass = done.

## Output Format

### write / rewrite

```
## Draft
(body)

## Design Memo (≤3 line)
- reader: ...
- argument order: ...
- dropped topic: ...
```

### review

```
## 5-Axis Score
A:_/3 B:_/3 C:_/3 D:_/3 E:_/3  total _/15

## Findings (priority order, max 5)
1. [axis] location → fix direction
...
```

### outline

```
## Structure
1. (heading) — intent 1 line
   - subheading — contain what
...
```

## Forbidden

- generate AI-smell prose ("important" "effectively" "seamlessly" etc unsupported)
- verbose boilerplate ("below shows" "you can" etc)
- execute write without 4-question pass
- full load writing-patterns (token waste, PRINCIPLES focus enough)
- apply to code body/comment/docstring (out of scope)
- **run Edit/Write in `review` submode** (output = findings only, no file change)

## Completion (per sub)

| Condition | write | rewrite | review | outline |
|-----------|:---:|:---:|:---:|:---:|
| 4-question pass | ✓ | ✓ | – | ✓ |
| 5-axis score 11/15+ | ✓ | ✓ | ✓ | – |
| 6-item pre-output 5+ | ✓ | ✓ | – | – |
| NG dict hit 0 | ✓ | ✓ | – | – |

ARGUMENTS: $ARGUMENTS
