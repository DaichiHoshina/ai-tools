---
allowed-tools: Read, mcp__serena__read_memory, mcp__serena__write_memory
description: 圏論的思考法を読み込み - Guard関手・射の分類をセッションに適用
---

## /kenron - 圏論的思考法ロード

## 実行ロジック

### Step 1: Serena memory確認

```
mcp__serena__read_memory("kenron-loaded")
```

- **存在する場合**: memoryから要約を読み込み、ファイル読み込みをスキップ
- **存在しない場合**: ファイルを読み込み、memoryに保存

### Step 2: 初回のみファイル読み込み

| 引数 | 読み込むファイル |
|------|-----------------|
| (なし) | skill.md, guardrails.md |
| `full` | skill.md, guardrails.md, session-modes.md |

ファイルパス:
- `~/.claude/skills/session-mode/skill.md`
- `~/.claude/guidelines/common/guardrails.md`
- `~/.claude/guidelines/common/session-modes.md`（fullのみ）

### Step 3: memoryに保存（初回のみ）

```
mcp__serena__write_memory("kenron-loaded", {
  loaded_at: ISO8601,
  summary: "Guard関手・3層分類適用済み"
})
```

### Step 4: 適用報告

```
## 圏論的思考法を適用

現在の制約:
- Safe射: 自動許可（読み取り、分析、提案）
- Boundary射: 確認必要（git操作、設定変更）
- Forbidden射: 拒否（システム破壊、セキュリティ侵害）
```

---

## 3層分類クイックリファレンス

| 層 | 処理 | 例 |
|---|------|---|
| **Safe** | 即座実行 | ファイル読み取り, git status |
| **Boundary** | 確認後実行 | git commit/push, 設定変更 |
| **Forbidden** | 拒否 | rm -rf /, secrets漏洩 |

---

## Guard関手

```
Guard_M : Mode × Action → {Allow, AskUser, Deny}
```

---

## ComplexityCheck射（タスク判定）

```
ComplexityCheck : UserRequest → {Simple, TaskDecomposition, AgentHierarchy}
```

### 判定基準

| 条件 | 判定 | アクション |
|------|------|-----------|
| ファイル数<5 AND 行数<300 | **Simple** | 直接実装 |
| ファイル数≥5 OR 独立機能≥3 OR 行数≥300 | **TaskDecomposition** | 5フェーズワークフロー |
| 複数プロジェクト横断 OR 戦略的判断 | **AgentHierarchy** | PO/Manager/Developer |

### 5フェーズワークフロー（TaskDecomposition時）

| Phase | 目的 | 不変条件（違反時は次フェーズ不可） |
|-------|------|----------------------------------|
| 0 | 要求分析 | 必須要件に説明・受け入れ条件あり |
| 1 | タスク分解 | カバレッジ = 100% |
| 2 | ファイル作成 | トレーサビリティ完全 |
| 3 | 依存整理 | 循環依存なし |
| 4 | Agent起動 | 全タスク成功完了 |
| 5 | 統合検証 | 未実装要件 = ∅ |

**詳細**: `claude-code/references/AI-THINKING-ESSENTIALS.md` 参照

---

ARGUMENTS: $ARGUMENTS
