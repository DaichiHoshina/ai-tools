# diff-hygiene

差分全体の性質を問う観点。個別行の是非でなく「なぜこの diff になったか」を検査する。単一 file の Edit / Write 時 hook では見えず、commit 単位 / PR 単位で見て初めて判定できる class の指摘を扱う。

## Critical

| Item | Description |
|---|---|
| Purpose-drift edit | PR の目的から外れた「ついでの整形」が feature diff に混じっている |
| Comment removal without justification | 意図が読める既存 comment を Why not (なぜ消したか) の説明なしで削除している |

## Warning

| Item | Description |
|---|---|
| Meaningless rename | 意味変更のない同義 rename が hunk に混在 (例: `batch↔バッチ` / `インシデント↔障害` の 1:1 置換のみで挙動不変) |
| Minimal-diff violation | 触った関数の周囲、変更不要な行まで書き換えている (formatter 掛け直し / 空行整理を feature diff に混ぜている) |
| Cosmetic-only commit in feature PR | 意味変更ゼロの整形 commit が feature PR に単独 commit として混じっている |

## 検査手順

1. `git diff --stat` で hunk 総数と行数を確認する
2. hunk ごとに 3 点を判定する:
   - (a) この変更は PR の目的 (issue / title) に必要か
   - (b) 削除された comment に情報価値 (Why / Why not / 非自明な制約) があったか
   - (c) rename に semantic な理由 (意味の明確化 / 用語統一) があるか
3. 上記 3 点で正当化できない hunk が 3 個超なら Warning、purpose-drift が明らか (別 issue 由来の修正が混入) なら Critical

## 判定困難ケース

- 「意味の変わらない置換」の判定は semantic 判断。regex では拾えない、LLM 照合が向く
- 「有用 comment」の判定も情報価値を人間が測る必要がある。「関数名から自明な what を言い換えた comment」は削除して良い、「Why not / 非自明な制約」は消してはいけない
- 単一 file の Edit 時点では diff 全体が見えないため hook では検出できない。**この perspective は review skill でしか働かない**

## 根拠 (この perspective を追加した理由)

過去 code review で 5 件連発した実例:
- 「意味のない機械 rename (`batch → バッチ` / `インシデント → 障害`) を混ぜるな」
- 「有用な comment を消しちゃっている」
- 「AI をもうちょい適切に扱えるようになってもらえると助かります」

既存 quality / readability では diff 全体の性質を判定する枠がなく、rename 個々の是非 (日本語化として正しい / 正しくない) と、diff としての意味 (この rename が今この PR に必要か) を切り分けられなかった。

## 関連

- 既存 hook `_check_edit_churn` (write-checkers.sh): 同一 file への 3 回超 write を warn。churn は「頻度」を見るが、diff-hygiene は「内容」を見る
- 既存 feedback memory `feedback_ai-diff-churn.md`: churn の抽象規範
- 上位 skill: `comprehensive-review` の Step 4.5 で本 perspective を Critical / Warning に振り分けて出力する
