---
allowed-tools: Read, mcp__serena__read_memory, mcp__serena__write_memory
description: Protection Mode（操作保護モード）を読み込み - 操作チェッカー・安全性分類をセッションに適用
---

## /protection-mode - 操作保護モード

## 実行ロジック

1. **Serena memory確認**: `read_memory("protection-mode-loaded")` → 存在すればスキップ
2. **初回のみファイル読み込み**: `skill.md` + `guardrails.md`（`full`引数時は `session-modes.md` も）
3. **memoryに保存**: `write_memory("protection-mode-loaded", {loaded_at, summary})`
4. **適用報告**: 現在の制約を表示

## 3層分類

| 層 | 処理 | 例 |
|---|------|---|
| **Safe** | 即座実行 | ファイル読み取り, git status |
| **Boundary** | 確認後実行 | git commit/push, 設定変更 |
| **Forbidden** | 拒否 | rm -rf /, secrets漏洩 |

## 操作ガード

`operationGuard : Mode × Action → {Allow, AskUser, Deny}`

| Mode | Safe | Boundary | Forbidden |
|------|------|----------|-----------|
| strict | Allow | AskUser（全件） | Deny |
| normal | Allow | AskUser（重要のみ） | Deny |
| fast | Allow | AskUser/Allow（最重要のみ） | Deny |

## 複雑度判定

| 条件 | 判定 | アクション |
|------|------|-----------|
| ファイル数<5 AND 行数<300 | Simple | 直接実装 |
| ファイル数≥5 OR 独立機能≥3 | TaskDecomposition | 5フェーズWF |
| 複数プロジェクト横断 | AgentHierarchy | PO/Manager/Developer |

5フェーズWF詳細: `references/AI-THINKING-ESSENTIALS.md` 参照

## 品質ガード

`GuardQuality : Implementation → {Accept, ReviewRequired, Reject}`

| 判定 | 例 |
|------|-----|
| **Reject** | 理由なきnull check、空catch、根拠なきタイムアウト増加 |
| **ReviewRequired** | Root cause documented workaround、TODO付き暫定対応 |
| **Accept** | 初期化保証、境界での型検証、構造的修正 |

品質ガードは**検出**担当。修正戦略は `/root-cause` スキルの責務。

ARGUMENTS: $ARGUMENTS
