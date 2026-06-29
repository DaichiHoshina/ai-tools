# agent-output-schema

Agent が返す Markdown 末尾 trailer の canonical 定義。
Team flow / 非 Team 全 agent に適用。

## Overview

Agent (Manager / Developer / Reviewer 等) は、出力 Markdown の末尾に `---` 区切りの YAML-like trailer を必ず付与する。
Parent はこの trailer を parse して `status` を判定し、次 gate を制御する。
Trailer が欠落した場合は `status: failure` と同等に扱う (`hook-payload-map.md` §Subagent failure 検知 設計方針 参照)。

適用範囲: `agent-team-contract.md` §3.1 で定義する全 agent output (Developer / Manager / Reviewer 等)。

## Trailer format

Markdown 本文の末尾、**区切り行 `---` の後に** YAML-like block を置く。
field 順序は下記で固定 (変更禁止)。

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

**status** — `agent-team-contract.md` §3.1 と完全一致の enum (この順序で固定):

| 値 | 意味 |
|----|------|
| `success` | DoD を全て満たし完了 |
| `partial` | 一部完了。`issues_blocking` に blocker を列挙済み |
| `failure` | タスク失敗。retry 2 回消費 + root cause 特定済み |
| `dep_unresolved` | 外部依存 (他 Dev 成果物 / 環境) が未解決で続行不能 |

`partial` は free pass ではない。具体的 blocker 行が `issues_blocking` に必須。blocker なしの `partial` は parent が `failure` 扱いで reject する。

**confidence** — `0`〜`100` の整数。運用閾値は **80** (`references/on-demand-rules/review-noise-discard.md` の confidence-80 filter と整合)。80 未満の場合は `issues_blocking` に不確実要素を記載する。

**issues_blocking** — 未解決 blocker を string 配列で列挙。解決済みなら `[]`。粒度: 1 要素 = 1 blocker (root cause 1 行)。推測は書かず、確認済み事実のみ記載。

## Examples

### Template

```
---
status: success | partial | failure | dep_unresolved
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

## Cross-references

- `agent-team-contract.md` §3.1 — status enum 定義 (canonical source)
- `hook-payload-map.md` §Subagent failure 検知 設計方針 — trailer 欠落時の failure 判定方針
