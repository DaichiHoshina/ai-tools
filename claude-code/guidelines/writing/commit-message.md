# コミットメッセージ原則

> **目的**: コミットメッセージの抽象化・検索可能性・prefix 規約。コミット作成時に参照。

## 原則

- **抽象化**: diff で読める内容を繰り返さない。変更ファイル名・関数名・変数名の列挙は避ける
- **WHAT は subject 1 行のみ**: 本文で WHAT を bullet / 段落で繰り返さない。WHAT が複数 file / 複数領域に渡る場合も、subject で抽象化して 1 行に収める
- **本文 = Why のみ**: 本文を書く場合は Why (動機 / 制約 / 解決対象) を 1-3 行で書く。WHAT 補足 bullet・file list・関数名列挙は禁止
- **事実のみ**: 経緯 (「指摘 N 対応」「review で〜」「あわせて〜も」) / 意図 (「〜する意図」「〜と考えた」) / 感想を書かない。最終 diff を present-state で説明する
- **検索可能性**: `git log --grep` で引ける単語を subject に含める

## 禁止語・避ける表現

| カテゴリ | 例 |
|---|---|
| AIワークフロー内部用語 | 「Generated with Claude Code」「AI出力」「AI臭」「Co-Authored-By: Claude」(`Fable` / `Opus` / `Sonnet` / `Haiku` 等 model 名 variant を含む全種) 等 (teamに晒さない用語) |
| 曖昧な抽象 | 「○○の整理」だけで終わる、変更内容が読み取れない要約 |
| 詳細列挙 | ファイル名・関数名・変数名を箇条書きで並べる、過剰な実装詳細 |
| 過剰な箇条書き | Why を 1-3 行で書けば足りるところに 5 個以上の bullet を並べる |

> AI関連のCo-Authored-Byトレーラーは、プロジェクトが**明示的に許可**している場合のみ使う。デフォルトは付けない。

## NG / OK

| NG | OK |
|---|---|
| `UserService の validateEmail を regex 修正 + test 追加` | `メールバリデーション修正` |
| `routes/users.ts の handler 修正` | `ユーザー登録の重複チェック追加` |
| `formatter / linter / type 修正` | `lint 違反解消` |
| `〜の整理` | `〜を背景に〜削除` (なぜを最低1つ) |
| `session token 累積閾値超過時の通知機構実装` | `session token が 500K 超えたら /clear を推奨する` |
| `指摘 2 対応。〜を短縮し、〜を切り出した` (review 経緯 + 過去形の作業日記) | `test 名を短縮して意図 comment を分離` (現在形で最終状態) |
| `Co-Authored-By: Claude Fable 5` (AI marker 全種) | (書かない) |

## Why を本文 1 行目に書く (必須)

commit 本文を書く場合、**1 行目は必ず Why (動機 / 制約 / 解決対象) を 1 文で書く**。subject line の 50 字で動機まで書き切れた場合のみ省略可。

「なぜこの変更をしたか」が commit を見た人に伝わらないと、将来 `git log` / `git blame` から意図を復元できず、説明の churn が発生する。

### OK 例

```
fix typo in CONTRIBUTING.md

Why: 2026-06-07 PR review で誤字指摘を受けた。
```

```
bump go.mod to go 1.22

Why: CI が go 1.21 EOL 警告を出力するようになり、pipeline が詰まる。
```

```
redis キャッシュ層を追加

Why: DB クエリが N+1 になっており、ページ応答が 3s を超えていた。
```

### NG 例

| NG | 問題 |
|---|---|
| 本文なし (subject のみ) | Why が読み取れない (自明でない変更で NG) |
| `WHAT の繰り返し: xxx.go を修正した` | diff を言い換えただけで Why が不在 |
| `リファクタ` / `整理` のみ | Why なし + 変更目的不明 |
| `パフォーマンス改善` のみ | 何が問題だったか不明 |
| 本文に `- file_a.md 新規` / `- file_b.md: 該当 entry を更新` の bullet 列挙 | WHAT を繰り返しただけ、diff で読める |
| 本文に「foo.go の Bar 関数を baz に rename」等の関数名列挙 | 同上 |
| 本文冒頭に `指摘 N 対応` / `1 回目は X だった` / `review 対応` | review 履歴は commit log でなく PR thread に残るもの、事実 (diff) を薄める |
| `[]int64 → named struct` / `ids[0] → ids.withItemIdentifiers` の rename before/after 列挙 | diff の写経、Why (何が読みにくかったか) が不在 |
| `〜する意図` / `〜のため` / `あわせて〜も` の意図・副次修正の段落化 | 書き手の解釈と副次修正が主 Why を薄める、副次修正は subject の抽象化か別 commit へ |

## 本文の構成

設計判断や非自明な変更がある場合のみ本文を書く。書く場合の構成は次のとおりとする。

1. **Why (背景)**: なぜ変えたか — 本文 1 行目に必ず書く (前 section 参照)、1-3 行
2. **(任意)** 既知の制約 / 次の TODO があれば 1 行

WHAT 補足 (file list / 関数名 / 影響範囲の列挙) は書かない。subject の抽象化で表現する。

## チェック

commit 前に `git log -1 --format=%B` で以下を確認する。

- 1行目だけで変更の輪郭が伝わるか
- diffを見ずに済む情報まで列挙してないか
- 禁止語が混入していないか
- 体言止め / 漢語連発 / 主語省略になっていないか (詳細: `PRINCIPLES.md` の「chat 草稿 → 外向き翻訳の 8 観点 sweep」)

機械検出 (**長文 / 多 commit 時は必須**): commit message を draft file に書き出して `scripts/jp-textlint.sh <draft>` を通す (詳細列挙は [PRINCIPLES.md § 機械検出 grep](PRINCIPLES.md#機械検出-grep-出力前-sweep) canonical)。commit message は AI定型語 block の最多発生源 (週 787 件)、24h 内 retrospective でも連続漢字≥5 warn 15+ / 読点≥4 warn 4+ 発生。draft → textlint → fix → commit の順で retry を減らせる。short 1 line subject のみは省略可。
