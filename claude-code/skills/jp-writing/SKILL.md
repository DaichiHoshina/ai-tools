---
allowed-tools: Read, Grep
name: jp-writing
description: "Japanese output readability check & rewrite. Evaluates NG terms, sentence-level quality, and structure using PRINCIPLES.md canonical. Used when /jp-writing is invoked."
context: fork
disallowed-tools:
  - Bash
  - Edit
  - Write
---

# jp-writing — 日本語の可読性チェック & リライト

Goal: reduce cognitive load for the reader, not just reject NG terms. All evaluation criteria come from `guidelines/writing/PRINCIPLES.md` canonical (no list literals inside this skill).

## Startup behavior

On `/jp-writing`, apply all self-checks below to the target text. For each hit, output the **rewritten sentence (After)** — do not stop at enumeration.

Target priority (**never ask back**):

1. ARGUMENTS has file path / pasted text → use it
2. ARGUMENTS empty → previous assistant output (latest chat turn text)
3. Neither → write new text on topic

Do not ask "What should I check?". Exclude code blocks (` ``` ` / `` ` ``) before evaluation.

## Determine medium first

Sentence length and style standards vary by medium. Determine medium first (details: PRINCIPLES.md `## 媒体別構造` / `## Web 可読性`).

| 媒体 | 1 文上限 | 構造 |
|---|---|---|
| 技術文書本文 (DD / RCA / long-form) | 100 字 | 冒頭結論 → 詳細 |
| web / 短文 (PR / Slack / Notion / Issue) | 60 字 | PREP + scan 対応 |
| chat | 緩め | genshijin (体言止め) |

## self-check (all dimensions, canonical reference)

Load PRINCIPLES.md and evaluate A→D in order.

### A. NG term detection (delete / replace)

Extract all keys from `guidelines/writing/NG-DICTIONARY.md` → enumerate hits.
- AI定型語 / カタカナ造語禁止 / 難読漢語 / 弱い表現 / 冗長表現 / 非日常英語 (block) / 断定語 (warn-only)
- Katakana compound replacements: `PRINCIPLES-word-replace.md` `## カタカナ造語 → 説明的代替`
- English word replacements: `PRINCIPLES-word-replace.md` `## 英単語 → 日本語の平易表現`

### B. Sentence-level readability (PRINCIPLES.md `## 文単位の品質規約`)

- **Sentence length**: exceeds medium limit → split
- **Commas ≤3**: 4 or more → split sentence
- **Consecutive kanji ≤4**: 5+ consecutive kanji → insert particle / kun-reading / verbify (e.g. `利用者認証処理管理` → `利用者の認証処理を管理`)
- **Open 7 word classes**: convert 形式名詞・副詞・接続詞・補助動詞 etc. to hiragana (test: "would you handwrite this kanji?")
- **No consecutive adversative が** / no `! ?` in body / unify kanji/arabic numerals

### C. AI smell removal (PRINCIPLES.md `## AI臭を消す3変換`)

- (a) 抽象語 (改善 / 最適化 / 効率化) → 数字 or 事例
- (b) 評価語 (低 / 中 / 高 / 重要 / 必須) → 根拠 1 文を加える
- (c) 難語 → 削除でなく定義を併記する
- (d) 英単語 → 平易表現
- (e) **書き手不在チェック** (canonical: PRINCIPLES.md `## AI臭の根本: 書き手不在`)
  - L1 主体: 「多くの〜」「一般に〜」「よく〜される」等の主体不明断定 → 特定主体 + 根拠 1 文。語源 `NG-DICTIONARY.md` `主体不明断定 (skill-only)`
  - L2 見出し: 主観形容詞 (重要 / 効率的 / 強力 / シンプル) 入り heading → 事実 / 数値 / 対象を含む中立名詞句
  - L4 リズム: 段落長 / 文長 / 文末が均質化していないか。1 段落 1 文段や短中長交互配置で書き手の呼吸を出す
- 初出 jargon は和訳併記 / 初出略語はフルスペル (list: PRINCIPLES.md `### NG辞書`)

### D. Structure (PRINCIPLES.md `## PREP 法 + 5W1H` / `## 避けるパターン`)

- Conclusion in first 1-3 sentences (remove「本稿では」)
- Long text / report / PR body: PREP (conclusion → reason → example how/number/path → reconfirm)
- Decision request: leading `要決定:` block
- End with reader's next action (approve / execute / ask)

## Rewrite output format

Do not stop at hit enumeration. Output **Before → After** with rewritten text. After must use concrete action, state, or number.

```
Before: 本機能はシームレスな連携を効率的に実現します。
  → カタカナ造語(シームレス) / AI定型語(効率的に・実現します) / 読点なし長文 / 抽象
After:  認証 API と在庫 API を中断なく連携する。連携 1 回あたりの待ち時間を 200ms 短縮した。
```

If all hits = 0, report「可読性 問題なし (A-D 全通過)」.

## Hook integration architecture

Each key in PRINCIPLES.md / NG-DICTIONARY.md (canonical) is dynamically extracted by hooks.

```
NG-DICTIONARY.md (canonical)
  ├── AI定型語 / カタカナ造語禁止 / 難読漢語 / 弱い表現 / 冗長表現 / 非日常英語
  │     → pre-tool-use.sh extracts → blocks on outward tools
  └── jargon / 略語 (PRINCIPLES.md NG辞書)
        → user-prompt-submit.sh injects warn
```

Block log `~/.claude/logs/jp-quality-block.log`: `timestamp | tool_name | hit_term | block|warn`. Rotated at 1MB; `analytics` skill aggregates weekly.

Skip all inject: env var `JP_QUALITY_INJECT_OFF=1` (user-prompt-submit.sh). Hook block is controlled separately in `pre-tool-use.sh`.
