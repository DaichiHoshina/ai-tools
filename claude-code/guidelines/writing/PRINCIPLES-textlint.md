# 文単位の品質規約 (textlint 詳細)

`PRINCIPLES.md` の `## 文単位の品質規約` から切り出した詳細規約。textlint preset (ja-technical-writing / JTF-style) の運用知見。

## 文長 (媒体別 2 段)

- **技術文書本文 (DD / RCA / long-form-doc)**: 1 文 100 字以内
- **web / 短文 (PR / Slack / Notion)**: 1 文 60 字以内 (`PRINCIPLES.md` `## Web 可読性` 参照)

## 読点 3 個まで

1 文中の読点 (`、`) は 3 個まで。超えたら文分割。読点 4+ は読者の認知負荷が急上昇する。出典: textlint-rule-preset-ja-technical-writing (max-ten rule)。

## 連続漢字 6 文字上限

漢字 7 文字以上の連続は読解負荷が高い。固有名詞は例外。

| Before (連続漢字) | After (助詞挿入) |
|---|---|
| `利用者認証処理管理` | `利用者の認証処理を管理` |
| `構造的変化傾向分析` | `構造的な変化傾向の分析` |

出典: textlint-rule-preset-ja-technical-writing (max-kanji-continuous-len rule)。

## 冗長表現の圧縮

| Before (冗長) | After (圧縮) |
|---|---|
| 〜することができる | 〜できる |
| 〜を行う | 〜する |
| 〜であると言えます | 〜である |
| 〜ということになる | 〜となる |
| 〜することが可能 | 〜できる |

出典: textlint-rule-ja-no-redundant-expression。

## 弱い表現の禁止 (技術文書本文)

技術文書 (DD / RCA / 報告書) の本文で曖昧語を使わない。断定できないなら「検証が必要」「未確認」と明示する。

| 禁止語 | 置換 |
|---|---|
| 〜かもしれない | 検証が必要 / 仮定: 〜 |
| 〜と思います | 〜と判断する / 未確認 |
| 〜と思われる | 〜と推定する (根拠を併記) |
| 〜可能性がある | 条件: 〜 / 発生率 X% |

既存の「断定語 warn-only」とは逆方向 — 断定語は過剰断定の抑制、弱い表現禁止は曖昧の排除。両方を併用する。出典: textlint-rule-ja-no-weak-phrase。

## 逆接「が」の連続禁止

1 文中に逆接の「〜が、〜が」が複数回出ない。逆接でない順接の「が」も連続で使わない。出典: textlint-rule-no-doubled-conjunctive-particle-ga。

## 技術文書で `! ?` 不使用

PR / DD / RCA / Notion / commit message の本文 / 見出し / 箇条書きで `!` `！` `?` `？` を使わない。Slack chat は例外。出典: textlint-rule-preset-ja-technical-writing。

## 漢数字 / 算用数字の使い分け

- **算用数字**: 数量・数えられるもの (`3 件` / `10 人` / `5 GB`)
- **漢数字**: 熟語・慣用表現・概数・副詞 (`三位一体` / `数十年` / `一日中`)

混在は同一文書内で統一。出典: 文化庁「公用文作成の考え方」(2022)。

## 見出しは常体 / 体言止め統一

本文がですます調でも、heading は常体 / 体言止めが標準。出典: textlint-rule-preset-JTF-style 1.1.2。

## 全角かっこ前後にスペースを置かない

- NG: `(例) 〜` / `〜 (補足) です`
- OK: `（例）〜` / `〜（補足）です`

英数字前後の半角 space rule と独立 (英数字には space あり、全角かっこには space なし)。出典: JTF-style 3.3。
