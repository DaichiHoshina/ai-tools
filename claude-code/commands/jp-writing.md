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

文体・冒頭構成・failure pattern・NG辞書基礎部: `guidelines/writing/PRINCIPLES.md` 参照。以下は独自規範のみ。

### NG 辞書 (独自部分)

| NG | OK |
|----|-----|
| 体言止め圧縮による擬人化 (`flag 未渡しが実行を走らせない`) | 主語を明示し使役展開する (`flag を渡さない場合、実行されない`) |
| 連用形否定 (`未渡し` / `未指定時`) | 「指定されなかった場合」と展開する |
| 口語動詞 (`倒す` / `握る` / `走らせる`) | 書き言葉に置換する (`無効化する` / `保持する` / `実行する`) |
| 英単語 + `する` の動詞化 (地の文で `commit する`) | 日本語動詞に置換。識別子・コマンド名はバッククォート囲み、動詞化しない |
| 専門用語 (異職種向け): `fail-closed` / `TX` / `dead code` | 安全側に倒す / トランザクション / 死蔵コード。識別子・コマンド・DBカラムは維持 |
| 社内造語: `派生値` / `stale-write` / `race window` | `計算値` / `古い値による上書き` / `並行する処理が古い値でUPDATEする競合`。外向き文書は平易化 |

### 「変に略さない」原則

省略より明瞭さを優先する。体言止め圧縮で語数を削ると擬人化・主語不明で破綻する。

- 物 / 状態 / flag を主語にした使役文は書き直し対象
- fail-safe 説明テンプレ: **「{取得失敗} の場合は {既定値} で続行」+「{誤操作} があった場合に意図せず {副作用} が発生することを防ぐ目的」**

### PR body MECE 構造

詳細: `guidelines/writing/pr-description.md` (後付け H2 禁止 / 箇条書き同行括弧 / 補足は CodeRabbit Summary 前に置く)

- **構造順**: `背景 → Related Issue → 実装概要 → (設計詳細) → 依存・マージ順序 → 影響 → 動作確認 → 補足 → CodeRabbit Summary`

### 長い WHY 説明の 3 箇所分散パターン

10 行超の WHY コメントブロックは分散配置する。3 階層: **全体方針 (関数頭、2-3 行)** / **個別 WHY (操作行直上、1-2 行)** / **局所制約 (SQL 直上、1-2 行)**。WHY コア保持・重複統合・日付依存断定削除。

## Subcommand

| sub | purpose | input | output |
|-----|---------|-------|--------|
| `write` (default) | write from scratch | goal/reader/topic | draft |
| `rewrite` | rewrite existing | file or paste | revision + reason (3 line max per change) |
| `review` | proofread (no edit) | file or paste | 5-axis check + finding list |
| `outline` | structure only | goal/reader/topic | heading hierarchy + intent per section |

no arg or `write` → write mode. First token vs subcommand match; no match → treat whole arg as write topic.

## 対象解決 (target resolution)

**対象を user に聞き返さない**。以下の優先順で自動決定する。

1. ARGUMENTS に file path (existing) → その file を対象
2. ARGUMENTS に paste block (3 行以上 / 引用記号付) → その text を対象
3. ARGUMENTS が write topic (subcommand 不一致 + 短文) → `write` mode で新規執筆
4. ARGUMENTS 空 + subcommand なし → **直前 assistant 出力 (直近の chat turn の text)** を `review` 対象として self-check
5. ARGUMENTS = `review` / `rewrite` 単独 (対象なし) → 直前 assistant 出力を対象

`review` / `rewrite` で対象不明瞭でも質問せず 4 / 5 に従って実行する。

## Pre-execution (required order)

**genshijin OFF**: write/rewrite body・outline は normal Japanese。review finding / progress は genshijin。

### 1. 4-Question Checkpoint (pre-write, mandatory)

詳細: `guidelines/writing/PRINCIPLES.md` "書く前の4問" 参照。4問未確認なら **top 1 のみ質問** (reader > judgment > action > evidence)。推定値は `estimated: {Q}={value}` でデザインメモに記録する。

### 2. Load Resources

`guidelines/writing/PRINCIPLES.md` full load。詳細 pattern は `references/writing-patterns.md` on demand。

### 3. Dynamic Load by Type

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

Each 0-3 pts, total 11/15+ pass. 5-axis = evaluate output quality; 6-item pre-output (PRINCIPLES.md) = gate just-before-output. Both pass = done.

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
## 5-Axis Score: A:_/3 B:_/3 C:_/3 D:_/3 E:_/3  total _/15
## Findings (priority order, max 5)
1. [axis] location → fix direction
```

### outline

```
## Structure
1. (heading) — intent / subheading — contain what
```

## Forbidden

- AI-smell prose / verbose boilerplate / write without 4-question pass
- full load writing-patterns (PRINCIPLES.md で十分)
- apply to code body/comment/docstring (out of scope)
- **Edit/Write in `review` submode** (findings only, no file change)

## Completion (per sub)

| Condition | write | rewrite | review | outline |
|-----------|:---:|:---:|:---:|:---:|
| 4-question pass | ✓ | ✓ | – | ✓ |
| 5-axis score 11/15+ | ✓ | ✓ | ✓ | – |
| 6-item pre-output 5+ | ✓ | ✓ | – | – |
| NG dict hit 0 | ✓ | ✓ | – | – |

ARGUMENTS: $ARGUMENTS
