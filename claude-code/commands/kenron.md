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

ARGUMENTS: $ARGUMENTS
