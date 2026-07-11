---
allowed-tools: Bash, Read, Grep, Glob, mcp__serena__find_symbol, mcp__serena__find_referencing_symbols, mcp__serena__get_symbols_overview, mcp__serena__find_declaration, mcp__serena__find_implementations
name: impact-analysis
description: 変更対象 symbol の fan-in 影響分析 skill。設計前に影響範囲を確定する時に使用し、呼び出し元列挙 → 層判定 → DB 4 経路 → 影響表を出す。「影響分析して」「影響範囲を調べて」で起動。— 層境界の review は clean-architecture-ddd、実装は /dev を使う
requires-guidelines:
  - common
---

# impact-analysis

変更対象 symbol の fan-in (呼び出し元) を洗い、影響する module / 層 / DB 経路を影響表 1 枚に確定させてから設計に入るための skill。巨大モノリスで「変更の影響範囲が読めない」状態を設計前に解消する。

## When to Use

- 「影響分析して」「影響範囲を調べて」と言われた時
- `issue-dev-flow` Step 3 (設計前の影響分析) として
- 共有 symbol (model / repository / util) の変更や DB schema 変更を含む設計時

## Steps

### 1. 変更対象 symbol の列挙

DD / issue / diff から変更する symbol (関数・struct・interface・table) を列挙する。DD が無い場合は user 指示の変更点から起こす。

### 2. Fan-in 洗い出し

symbol ごとに `mcp__serena__find_referencing_symbols` で呼び出し元を列挙する。呼び出し元が共有層 (interface / 共通 util) なら 1 hop 追加して間接影響まで辿る。追跡は 2 hop を上限とし、超える分は影響表に「未追跡」と明記する。interface 変更は `find_implementations` で実装側も列挙する。

### 3. 層判定

呼び出し元ごとに所属層 (handler / usecase / domain / infra / frontend) を判定し、変更が層境界を跨ぐかを見る。層境界が妥当かの確認は `clean-architecture-ddd` skill へ委譲する。

### 4. DB 4 経路確認 (DB 変更時のみ)

DoD #7 の 4 経路を必ず見る: FK 制約 / long TX / replica lag / maintenance scope への影響。schema は migration file でなく実 DB (`make db-schema` 等の project 手段) から取る。

### 5. 影響表の出力

結果を 1 表に集約し、issue / DD に貼れる形で出す。

| 変更 symbol | 呼び出し元 (module/層) | 影響内容 | 対応 |
|---|---|---|---|
| `Foo.Bar()` | `handler/x` (handler) | 引数追加で compile error になる | 同 PR で修正 |
| `orders` table | `batch/y` (infra) | long TX で lock 競合する | 分割 migration |

表には影響の総量と危険箇所を 1-2 文で添える。fan-in 件数と層の判定根拠は表の外に 1 行で残す。

## Guard

- 影響表の件数・行数は grep / find_referencing_symbols の実測値のみ書く (推定値を実測のように書かない)
- 「影響する呼び出し元は該当なし」と結論する場合も、探索した範囲 (symbol 数・hop 数) を明記する

## Out of Scope

- 層設計そのものの review (`clean-architecture-ddd`)
- 影響先の実装・修正 (`/dev` / `/flow`)
- PR 分割設計 (`references/on-demand-rules/pr-release-order.md`)
