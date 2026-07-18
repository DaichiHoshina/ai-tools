---
allowed-tools: Read, Glob, Grep, Bash, mcp__serena__*
description: 確定前の設計案を詰問して前提の穴と未決定点を炙り出す (read-only)
argument-hint: "[設計案の要約 / plan file path / issue・PR URL]"
---

# /grill - 設計案への詰問 (read-only)

> **Goal**: 「設計案が既にある」状態で、実装に入る前に前提の穴・未決定点・却下済み代替案の妥当性を炙り出す。修正はしない。

## When to use (棲み分け)

| Command / skill | Use |
|---|---|
| `/grill` | 設計案あり、確定前に穴を突きたい |
| `/brainstorm` | design unclear、選択肢を発散させたい |
| mino-problem-framing | 要件・前提そのものが曖昧、重量級の前提監査 |
| `/plan` | 設計 settled、impl phase に分解する |

`/plan` の直前 gate として使うのが基本線 (grill → 未決定点解消 → plan)。

## Flow

1. 入力 (設計案要約 / plan file / issue URL) を読む。file・URL なら実物を Read / WebFetch する
2. 関連 code を pinpoint で確認する (Serena `find_symbol` / grep、設計案の主張と実物の食い違い検出が目的)
3. 下記 6 観点で詰問を生成し、設計案が既に答えている問いと未回答の問いに仕分ける
4. 未決定点表 + 総評を出力する

## 詰問 6 観点

1. **必要性** — なぜ今この変更か。やらないと何が起きるか。問題は実測 / 実例で確認済みか
2. **完成条件** — 何を満たせば done か。exit code / 数値で判定できるか。DoD のどれを適用するか
3. **責務境界** — どの module / file が何を持つか。既存の責務と重複・越境しないか
4. **却下した代替案** — 検討して捨てた案は何か。却下理由は現時点でも有効か。「より simple な案」を検討したか
5. **失敗時の戻し方** — rollback 経路はあるか。不可逆操作 (削除 / migration / 外部送信) はどこか
6. **非機能** — 性能 / security / 運用負荷 / token cost の見落としはないか

## Output format

```markdown
# Grill: [設計案名]

## 詰問と現状回答
- Q1 (必要性): [問い] → 回答済: [設計案の記述] / 未回答
- ...

## 未決定点
| 点 | 影響 | 推奨 |
|---|---|---|

## 総評
このまま /plan に進めるか (可 / 未決定点 N 件の解消が先) を 1-2 文で言い切る
```

## minimize-questions との整合

詰問は chat 出力への列挙であり、AskUserQuestion を連発しない (rule canonical: `rules/minimize-questions.md`)。未決定点にも推奨を 1 件ずつ添え、user は差分だけ返せばよい状態にする。user が回答したら再詰問は差分観点のみに絞る。

## Read-only

file 編集・実装をしない。詰問の結果「設計修正が要る」となったら `/brainstorm` か手動修正へ、solid なら `/plan` へ誘導する。
