# natural-japanese lint (外向き長文 doc の AI 臭検出)

[coji/natural-japanese](https://github.com/coji/natural-japanese) の lint script を、外向き長文 doc (記事 / DesignDoc / RCA / long-form) の draft 完成後に on-demand で実行する。sudachipy 形態素解析による決定的検出で、既存 jp-quality 体系 (NG 語 / 100 字上限 = 文単位 rule) が持たない文書全体の統計指標を補完する。plugin 導入は token 常時消費を避けて見送り、CLI 直叩きだけ使う。

## 実行

```bash
cd ~/ghq/github.com/coji/natural-japanese
uv run skills/natural-japanese/scripts/lint.py --json <対象file>
```

- `--genre {business,essay,tech}` でコーパス校正済み閾値に切替える (未指定は保守的閾値)
- `--baseline prev.json` で前回結果と比較し resolved / new / persisting を判定する (収束ループ用)
- 出力 JSON は `{file, stats, findings[{line, category, excerpt, severity, detail}]}` の形
- repo が無ければ `ghq get coji/natural-japanese`、uv 未導入なら実行を skip して手動 check に切替える

## 主要 detector (default 有効分)

| category | 検出内容 |
|---|---|
| `forbidden_phrase` / `translationese` / `translationese_morph` | 禁止語・紋切り型・翻訳調の語彙 |
| `antithesis_repetition` | 「〜ではなく」対比構文の反復 |
| `low_burstiness` / `low_sentence_variance` | 文長リズム・段落構造の均質さ |
| `uniform_paragraph_structure` / `repeated_sentence_lead` | 段落刻みの均一・文頭 2 形態素の反復 |
| `nominal_ending` | 長文なのに体言止めゼロ (人間的修辞の欠如) — **不採用、下記裁定** |
| `low_lexical_diversity_ttr` / `low_lexical_diversity_mtld` / `low_specificity` | 語彙多様性・具体性の不足 |
| `english_syntax_inanimate_subject` / `inanimate_subject_morph` | 無生物主語 + 他動詞の英語統語 |

`--experimental` 指定時のみ出る未校正 detector は採用しない。

## 裁定: nominal_ending は不採用

`rules/plain-jp.md` の体言止め禁止を全 context で優先し、`nominal_ending` (体言止めゼロ = AI 的) の指摘は直さずに無視する。lint 側の設計も「検出は機械、判断は人間」で、detector 単位の不採用はこの思想と整合する。外向き公開記事 (Zenn 等) だけは体言止め解禁の検討余地があるが、その判断は user に委ねる。

## 運用

- 適用は外向き長文 doc のみとする。統計指標は文書長が前提で、chat / commit message に適用しない
- 指摘への対応は「直す」か「理由を 1 行つけて残す」の 2 択とし、機械的な全指摘追従をしない (Goodhart 対策)
- 修正後は `--baseline` 付き再実行で new 指摘ゼロを収束条件にする
