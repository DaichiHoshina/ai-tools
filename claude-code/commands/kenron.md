---
allowed-tools: Read
description: 圏論的思考法を読み込み - Guard関手・射の分類をセッションに適用
---

## /kenron - 圏論的思考法ロード

## 使い方

```
/kenron        # 基本（skill.md + guardrails.md）
/kenron full   # フル（+ session-modes.md）
```

---

## 実行ロジック

### Step 1: 引数解析

| 引数 | 読み込むファイル |
|------|-----------------|
| (なし) | skill.md, guardrails.md |
| `full` | skill.md, guardrails.md, session-modes.md |

### Step 2: ファイル読み込み

**基本（デフォルト）:**
1. `~/.claude/skills/session-mode/skill.md` - Guard関手の数学的定義
2. `~/.claude/guidelines/common/guardrails.md` - 3層分類（Safe/Boundary/Forbidden）

**フル:**
1. 上記2ファイル
2. `~/.claude/guidelines/common/session-modes.md` - モード別確認フロー

### Step 3: 適用報告

```
## 圏論的思考法を適用

読み込んだファイル:
- session-mode/skill.md（Guard関手定義）
- guardrails.md（3層分類）

現在の制約:
- Safe射: 自動許可
- Boundary射: 確認必要
- Forbidden射: 拒否
```

---

## 読み込まれる概念

### Guard関手
```
Guard_M : Mode × Action → {Allow, AskUser, Deny}
```

### 3層分類
- **Safe**: 読み取り、分析、提案
- **Boundary**: git操作、設定変更、パッケージ追加
- **Forbidden**: システム破壊、セキュリティ侵害

### 不変条件
```
∀m ∈ Mode, Forbidden ⊂ Mor(Forbidden)  # Forbiddenは不変
```

---

## /mode との違い

| コマンド | 目的 |
|---------|------|
| `/kenron` | 思考法をロード（圏論的制約を意識） |
| `/mode` | 確認フローを変更（strict/normal/fast） |

両方使う場合: `/kenron` → `/mode strict`

---

ARGUMENTS: $ARGUMENTS
