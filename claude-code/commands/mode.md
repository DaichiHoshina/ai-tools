---
allowed-tools: Read, mcp__serena__read_memory, mcp__serena__write_memory, mcp__serena__list_memories
model: haiku
description: セッションモード切替 - strict/normal/fast で確認レベルを変更
---

## /mode - セッションモード切替

## 使い方

```
/mode           # 現在のモードを確認
/mode strict    # 厳格モード（すべてのBoundary操作で確認）
/mode normal    # 通常モード（8原則に従う）
/mode fast      # 高速モード（確認最小化）
```

---

## モード一覧

| モード | 確認レベル | ユースケース |
|--------|----------|-------------|
| **strict** | すべてのBoundary操作で確認 | 本番作業、重要リファクタリング |
| **normal** | 標準（git操作、設定変更で確認） | 通常の開発作業（デフォルト） |
| **fast** | git push、重要削除のみ確認 | プロトタイピング、探索 |

---

## 実行ロジック

### Step 1: 引数解析

| 引数 | 効果 |
|------|------|
| (なし) | 現在のモードを表示 |
| `strict` | 厳格モード + ガイドライン読み込み |
| `normal` | 通常モード |
| `fast` | 高速モード |

### Step 2: Serena Memory 操作

1. `read_memory("session-mode")` で現在の状態取得
2. `write_memory("session-mode", { mode, activated_at, previous_mode })` で保存

### Step 3: ガイドライン読み込み（strict のみ）

strict モード時、以下を自動読み込み:
- `~/.claude/guidelines/common/session-modes.md`
- `~/.claude/guidelines/common/guardrails.md`

### Step 4: 報告

```
## セッションモード

モード: {mode}
確認レベル: {説明}
永続化: Serena Memory
```

---

## 引数なし時の出力例

```
## セッションモード

現在: normal（デフォルト）

| モード | 説明 |
|--------|------|
| strict | すべてのBoundary操作で確認。ガイドライン自動読み込み。 |
| normal | 8原則に従う。git操作・設定変更で確認。 |
| fast   | 確認最小化。git push・重要削除のみ確認。 |

切替: /mode strict | /mode fast
```

---

## 各モードの詳細

### strict モード

| 操作 | 処理 |
|------|------|
| git commit/push | 確認必須 |
| ファイル編集 | 確認必須 |
| npm install | 確認必須 |
| 設定変更 | 確認必須 |
| ファイル読み取り | 自動許可 |

### normal モード

| 操作 | 処理 |
|------|------|
| git commit/push | 確認 |
| 重要ファイル削除 | 確認 |
| 設定変更 | 確認 |
| npm install（安全） | 自動許可 |
| ファイル編集 | 自動許可 |

### fast モード

| 操作 | 処理 |
|------|------|
| git push | 確認 |
| 重要ファイル削除 | 確認 |
| git commit | 自動許可 |
| npm install | 自動許可 |
| ファイル編集 | 自動許可 |

---

## Serena Memory

```yaml
memory_key: "session-mode"
content:
  mode: "strict" | "normal" | "fast"
  activated_at: ISO8601
  previous_mode: string | null
```

---

## 関連

- `session-mode` スキル - モードの詳細定義
- `guidelines/common/session-modes.md` - モード定義
- `guidelines/common/guardrails.md` - ガードレール定義

ARGUMENTS: $ARGUMENTS
