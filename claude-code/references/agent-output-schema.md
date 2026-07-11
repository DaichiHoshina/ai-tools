# agent-output-schema

Agent が返す Markdown 末尾 trailer の canonical 定義。
Team flow / 非 Team 全 agent に適用。

## Overview

Agent (Manager / Developer / Reviewer 等) は、出力 Markdown の末尾に `---` 区切りの YAML-like trailer を必ず付与する。
Parent はこの trailer を parse して `status` を判定し、次 gate を制御する。
Trailer が欠落した場合は `status: failure` と同等に扱う (`hook-payload-map.md` §Subagent failure 検知 設計方針 参照)。

適用範囲: `agent-team-contract.md` §5 で定義する全 agent output (Developer / Manager / Reviewer 等)。

## Trailer format

Markdown 本文の末尾、**区切り行 `---` の後に** YAML-like block を置く。
field 順序は以下のとおり固定する (変更禁止)。

```
---
status: <enum>
confidence: <0-100>
issues_blocking: [<string>, ...]
---
```

- `---` 行は区切り専用。コメントや他 field を同行に混在させない
- block は `---` で閉じる (trailing `---` 必須)
- field は 3 つのみ。追加 field は禁止

## Field spec

**status** — `agent-team-contract.md` §5 と完全一致の enum (この順序で固定):

| 値 | 意味 |
|----|------|
| `success` | DoD を全て満たし完了 |
| `partial` | 一部完了。`issues_blocking` に blocker を列挙済み |
| `failure` | タスク失敗。retry 2 回消費 + root cause 特定済み |
| `dep_unresolved` | 外部依存 (他 Dev 成果物 / 環境) が未解決で続行不能 |
| `blocked` | user 判断が必要な decision fork で停止 (subagent silent-fail guard 発火)。parent は user に escalate する |

`partial` は free pass ではない。具体的 blocker 行が `issues_blocking` に必須。blocker なしの `partial` は parent が `failure` 扱いで reject する。

**confidence** — `0`〜`100` の整数。運用閾値は **80** (`references/on-demand-rules/review-noise-discard.md` の confidence-80 filter と整合)。80 未満の場合は `issues_blocking` に不確実要素を記載する。

**issues_blocking** — 未解決 blocker を string 配列で列挙。解決済みなら `[]`。粒度: 1 要素 = 1 blocker (root cause 1 行)。推測は書かず、確認済み事実のみ記載。

## Evidence label (VERIFIED / REASONED / ASSUMED)

report 本文中の claim (個別の主張。測定値 / file 変更 / 重要な結論) 単位に、検証根拠ラベルを付ける。

| label | 意味 |
|----|------|
| `VERIFIED` | command 実行・test・file 読取で直接確認した |
| `REASONED` | 確認済み事実からの推論で導いた |
| `ASSUMED` | 未確認の仮定に基づく |

`confidence` は report 全体の確度を示す数値で、evidence label は claim 単位の検証根拠を示す。役割が違うため両者は併存し、evidence label が trailer field を置き換えることはない (trailer field は 3 つのまま変わらない)。

出力例:

```yaml
claims:
  - claim: "hook latency は 120ms 前後で baseline と同等"
    evidence: VERIFIED   # hook-bench.sh を実行して確認した
  - claim: "regression は import 追加が原因"
    evidence: REASONED   # 計測差分と diff から推論した
  - claim: "CI 環境でも同じ latency になる"
    evidence: ASSUMED    # CI では未計測
```

## Examples

### Template

```
---
status: success | partial | failure | dep_unresolved | blocked
confidence: 0-100
issues_blocking: []
---
```

### 良い例 (success)

```
---
status: success
confidence: 95
issues_blocking: []
---
```

### 悪い例 (status 欠落)

```
confidence: 90
issues_blocking: []
```

→ `status` field がないため parent は `failure` と判定する。`---` 区切りも欠落している点に注意。

## Inlining policy

各 agent file は trailer example (5 行) を inline 必須とする。agent が references/ を読めない context で spawn されても trailer format に従えるようにするため。semantics / enum / evidence label の定義は本 file が canonical で、inline example と本 file の enum が食い違った場合は本 file が勝つ。

## Cross-references

- `agent-team-contract.md` §5 — status enum 定義 (canonical source)
- `hook-payload-map.md` §Subagent failure 検知 設計方針 — trailer 欠落時の failure 判定方針
