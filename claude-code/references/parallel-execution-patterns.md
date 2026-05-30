# Parallel Execution Patterns

CLAUDE.md `## Auto-Delegation` Parallel-first 原則の具体パターン集。

## 同一 message で並列発火する典型 case

### 1. Investigate + Plan + Skeleton 同時並走

ユーザ要求が「機能 X を追加」の時、調査 (explore-agent) / 設計案 (po-agent) / 既存 file skeleton 把握 (Bash grep) を同一 message 内で並列発火する。

### 2. 複数 domain explore

domain が独立している場合 (例: frontend / backend / infra) の調査は `explore-agent` を domain 数だけ同一 message で発火する。max 4。

### 3. 独立 file 群の edit

依存なし file の edit は `developer-agent` 委譲 1 件にまとめる (subagent 内で並列処理)、または独立 file group ごとに別 `developer-agent` を同一 message で複数発火する。

### 4. Verification 並列

test / lint / typecheck 等の独立 verify は Bash tool を同一 message 内に並べて実行する。

## 並列禁止 case

- 同一 file への複数 edit (race condition)
- 前 task 結果が次 task 入力 (依存あり逐次)
- commit-bearing op の前後 (順序保証必要)

## 実装 hint

- Agent tool は複数 call を同一 message に並べれば自動並列
- 結果が一通り揃ってから合流判断する
- 個別 agent prompt は ≤500 word (CLAUDE.md "Subagent prompt context budget" 準拠)
- 並列数 max 4 (`parent + Dev×N ≤ 5` 制約、詳細: `references/PARALLEL-PATTERNS.md`)
