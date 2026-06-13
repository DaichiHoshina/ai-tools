---
name: jp-writing
description: "日本語出力の可読性チェック & リライト。NG語 + 文単位品質 + 構造を PRINCIPLES.md canonical で評価し、綺麗で読みやすい文章に直す。/jp-writing 呼出し時に使用。"
context: fork
disallowed-tools:
  - Bash
  - Edit
  - Write
---

# jp-writing — 日本語の可読性チェック & リライト

NG 語を弾くだけでなく、**読み手の認知負荷を下げる読みやすい文章**に直すのが目的。判定規範は全て `guidelines/writing/PRINCIPLES.md` canonical を読み込んで適用する (skill 内に list literal を持たない = 派生値禁止)。

## 起動時の動作

`/jp-writing` 呼出し時、対象テキストに下記 self-check を全て適用し、hit ごとに**書き換え後の文 (After)** を提示する。指摘で終わらせず、直した文を出す。

対象の優先順 (**user に聞き返さない**):

1. ARGUMENTS に file path / paste text → それを対象
2. ARGUMENTS 空 → 直前 assistant 出力 (直近 chat turn の text)
3. いずれも無ければ topic として新規執筆

「何をチェックしますか」等の質問返しは禁止。最初に code block (` ``` ` / `` ` ``) を除外してから判定する。

## 媒体を先に判定する

文長・文体の基準が媒体で変わるため、最初に媒体を確定する (詳細: PRINCIPLES.md `## 媒体別構造` / `## Web 可読性`)。

| 媒体 | 1 文上限 | 構造 |
|---|---|---|
| 技術文書本文 (DD / RCA / long-form) | 100 字 | 冒頭結論 → 詳細 |
| web / 短文 (PR / Slack / Notion / Issue) | 60 字 | PREP + scan 対応 |
| chat | 緩め | genshijin (体言止め) |

## self-check (全 dimension、canonical 参照)

PRINCIPLES.md を読み込み、A→D を順に判定する。

### A. NG 語検出 (削除 / 置換)

`guidelines/writing/NG-DICTIONARY.md` の全 key を抽出 → hit 列挙。
- AI定型語 / カタカナ造語禁止 / 難読漢語 / 弱い表現 / 冗長表現 / 非日常英語 (block) / 断定語 (warn-only)
- カタカナ造語の置換: `PRINCIPLES-word-replace.md` `## カタカナ造語 → 説明的代替`
- 英単語の置換: `PRINCIPLES-word-replace.md` `## 英単語 → 日本語の平易表現`

### B. 文単位の可読性 (PRINCIPLES.md `## 文単位の品質規約`)

- **文長**: 媒体上限超 → 分割
- **読点 ≤3**: 4 個以上 → 文分割
- **連続漢字 ≤4**: 漢字 5 連続以上 → 助詞挿入 / 訓読み開く / 動詞化 (例: `利用者認証処理管理` → `利用者の認証処理を管理`)
- **ひらく漢字 7 品詞**: 形式名詞・副詞・接続詞・補助動詞 等をひらがな化 (判定: 「手書きでこの漢字を書くか?」)
- **逆接「が」連続禁止** / 本文で `! ?` 不使用 / 漢数字・算用数字の統一

### C. AI 臭の除去 (PRINCIPLES.md `## AI臭を消す3変換`)

- (a) 抽象語 (改善 / 最適化 / 効率化) → 数字 or 事例
- (b) 評価語 (低 / 中 / 高 / 重要 / 必須) → 根拠 1 文併記
- (c) 難語 → 削除でなく定義併記
- (d) 英単語 → 平易表現
- 初出 jargon は和訳併記 / 初出略語はフルスペル (list: PRINCIPLES.md `### NG辞書`)

### D. 構造 (PRINCIPLES.md `## PREP 法 + 5W1H` / `## 避けるパターン`)

- 冒頭 1-3 文に結論 (「本稿では」削除)
- 長文 / 報告 / PR body は PREP (結論 → 理由 → 具体例 how/数値/path → 再確認)
- decision 要求は冒頭に `要決定:` 枠
- 末尾に読み手の次アクション (approve / 実行 / 質問)

## リライトの出し方

hit 列挙で終わらず、**Before → After** で直した文を出す。After は具体的な動作・状態・数値にする。

```
Before: 本機能はシームレスな連携を効率的に実現します。
  → カタカナ造語(シームレス) / AI定型語(効率的に・実現します) / 読点なし長文 / 抽象
After:  認証 API と在庫 API を中断なく連携する。連携 1 回あたりの待ち時間を 200ms 短縮した。
```

全 hit 0 なら「可読性 問題なし (A-D 全通過)」と報告。

## hook 連携アーキテクチャ

PRINCIPLES.md / NG-DICTIONARY.md (canonical) の各 key を hook が動的抽出する。

```
NG-DICTIONARY.md (canonical)
  ├── AI定型語 / カタカナ造語禁止 / 難読漢語 / 弱い表現 / 冗長表現 / 非日常英語
  │     → pre-tool-use.sh が抽出 → 外向き tool で block
  └── jargon / 略語 (PRINCIPLES.md NG辞書)
        → user-prompt-submit.sh が warn inject
```

block ログ `~/.claude/logs/jp-quality-block.log`: `timestamp | tool_name | hit_term | block|warn`。1MB 超で rotation、`analytics` skill が週次集計。

全 inject を skip: 環境変数 `JP_QUALITY_INJECT_OFF=1` (user-prompt-submit.sh)。hook block は `pre-tool-use.sh` 側で別途制御。
