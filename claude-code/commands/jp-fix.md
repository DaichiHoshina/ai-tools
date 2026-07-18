---
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, mcp__serena__*
description: Human-facing prose quality mode (JP 規範統合)
argument-hint: "[file or text]"
---

## /jp-fix - Writing Quality Command

Improve human-facing prose (PR body, Design Doc body, Notion, blog, Slack, email) **readability, visibility, clarity**.

Code body, code comments, docstrings out of scope.

> **Responsibility split**:
> - `/docs` = format/structure/template compliance (Notion post/API docs/README)
> - `/design-doc` = assemble design decision document
> - `/jp-fix` = **prose quality itself** (vocab, sentence length, paragraph, signal)

## JP 執筆規範 (write/rewrite 時に必須適用)

文体・冒頭構成・failure pattern・NG辞書基礎部: `guidelines/writing/PRINCIPLES.md` 参照。以下は独自規範のみ。

### NG 辞書 (独自部分)

NG 辞書の詳細 (体言止め擬人化 / 連用形否定 / 口語動詞 / 英動詞化 / 専門用語 / 社内造語) は `guidelines/writing/NG-DICTIONARY.md` § `jp-fix 固有 NG (skill-only)` 参照。

### 「変に略さない」原則

省略より明瞭さを優先する。体言止め圧縮で語数を削ると擬人化・主語不明で破綻する。

- 物 / 状態 / flag を主語にした使役文は書き直し対象
- fail-safe 説明テンプレ: **「{取得失敗} の場合は {既定値} で続行」+「{誤操作} があった場合に意図せず {副作用} が発生することを防ぐ目的」**

### PR body / 長い WHY 説明

PR body の構造順・配置規範は `guidelines/writing/pr-description.md`、10 行超の WHY 説明の 3 階層分散パターンは `references/writing-patterns.md` 参照。

## Subcommand

| sub | purpose | input | output |
|-----|---------|-------|--------|
| `write` (default) | write from scratch | goal/reader/topic | draft |
| `rewrite` | rewrite existing | file or paste | revision + reason (3 line max per change) |
| `review` | proofread (no edit) | file or paste | 5-axis check + finding list |
| `outline` | structure only | goal/reader/topic | heading hierarchy + intent per section |

no arg or `write` → write mode. First token vs subcommand match; no match → treat whole arg as write topic.

## 対象解決 (target resolution)

**user に聞き返さない**。優先順で自動決定する: (1) ARGUMENTS が existing file path → 該当 file / (2) paste block (3 行以上 / 引用記号付) → 該当 text / (3) write topic (subcommand 不一致 + 短文) → `write` mode 新規執筆 / (4) ARGUMENTS 空 + subcommand なし → 直前 assistant 出力を `review` 対象 / (5) `review` / `rewrite` 単独 → 直前 assistant 出力。`review` / `rewrite` で対象不明瞭でも質問せず実行する。

## Pre-execution (required order)

**文体**: write/rewrite body・outline・review finding・progress のすべてを plain JP 常体 (`rules/plain-jp.md`) で書く。

### 1. 4-Question Checkpoint (pre-write, mandatory)

詳細: `guidelines/writing/PRINCIPLES.md` "書く前の4問" 参照。4問未確認なら **top 1 のみ質問** (reader > judgment > action > evidence)。推定値は `estimated: {Q}={value}` でデザインメモに記録する。

### 2. Load Resources

`guidelines/writing/PRINCIPLES.md` はコア層 (冒頭 index table の「check / rewrite 実行」行に列挙した section) のみ load する。詳細層 (AI臭を消す3変換 / 避けるパターン / Web 可読性詳細) と全文 load は深い書き直し (`rewrite` mode) 時のみ。詳細 pattern は `references/writing-patterns.md` on demand。

### 3. Dynamic Load by Type

| Detect Keyword | Extra Load |
|---------|-----------|
| Notion / page | `guidelines/common/notion-writing.md` |
| Design Doc / ADR / RCA | `guidelines/writing/design-doc-protocol.md` |
| PR / pull request | `guidelines/writing/pr-description.md` |
| rewrite | `references/document-iteration-patterns.md` + `references/writing-patterns.md` "Rewrite Phase 1-8" |
| file 対象の review / rewrite | `references/on-demand-rules/natural-japanese-lint.md` を load し、parent 側で lint を Bash 実行して JSON を 5-Axis の補助入力に渡す (skill は Bash 禁止のため実行しない)。短文でも省略しない (禁止語 / 翻訳調は文 1 つでも検出される)。統計系 detector (文長リズム / 段落均質 / 語彙多様性) は外向き長文 doc のみ採用する |
| paste / chat 対象の review / rewrite | lint CLI が使えないため、natural-japanese 観点 (語順 / 読点位置 / 一文一義 / 主語述語の距離 / 鋳型・文頭反復 / 翻訳調) を [A] / [E] で目視評価する |
| AI 臭さの採点依頼 / full 精査の明示 | `natural-japanese:natural-japanese` skill (score / full) へ委譲する。jp-fix 側は結果を 5-Axis に転記して締める |

## 5-Axis Check (review/rewrite required)

```
[A] readability: 1 sentence ≤60 chars (web/short) or ≤100 (tech doc) / 読点 ≤3 / 連続漢字 ≤4 / paragraph 3-5 sentences / explicit subject / 語順・読点位置・一文一義・主語述語の距離 (natural-japanese 観点)
[B] visibility: heading hierarchy / bullet use / tables for types
[C] signal: PREP or TL;DR+detail / conclusion first
[D] evidence: praise word + number/case (AI smell 3-transform)
[E] coherence: term consistency / no duplication / NG dict hit 0 / 同一鋳型・文頭反復なし・翻訳調 0 (natural-japanese 観点)
```

Each 0-3 pts, total 11/15+ pass. 5-axis = evaluate output quality; 6-item pre-output (PRINCIPLES.md) = gate just-before-output. Both pass = done.

## Output Format

- **write / rewrite**: `## Draft` (body) + `## Design Memo (≤3 line)` (reader / argument order / dropped topic)
- **review**: `## 5-Axis Score: A:_/3 B:_/3 C:_/3 D:_/3 E:_/3 total _/15` + `## Findings (priority order, max 5)` (`[axis] location → fix direction`)
- **outline**: `## Structure` の番号付き `(heading) — intent / subheading — contain what`

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
