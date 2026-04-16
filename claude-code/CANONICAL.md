# 正式名称・参照パス定義（CANONICAL）

> **目的**: ドキュメント間の参照を統一し、用語の揺れを防止

---

## 📋 正式ドキュメント名称

### コアドキュメント

| 正式名称 | 参照パス | 別名（使用禁止） |
|---------|---------|-----------------|
| **AI思考法エッセンス** | `claude-code/references/AI-THINKING-ESSENTIALS.md` | AI-THINKING-ESSENTIALS, AI思考法のエッセンス |
| **用語集** | `claude-code/GLOSSARY.md` | GLOSSARY, 用語集 |
| **スキルマップ** | `claude-code/SKILLS-MAP.md` | SKILLS-MAP, スキルマップ |
| **クイックスタート** | `claude-code/QUICKSTART.md` | QUICKSTART, クイックスタート |
| **並列パターン** | `claude-code/references/PARALLEL-PATTERNS.md` | PARALLEL-PATTERNS, 並列パターン |

### ガイドライン

| 正式名称 | 参照パス | 別名（使用禁止） |
|---------|---------|-----------------|
| **ガードレール** | `claude-code/guidelines/common/guardrails.md` | GUARDRAILS.md, guardrails |
| **セッションモード** | `claude-code/guidelines/common/session-modes.md` | SESSION-MODES.md, session-modes |
| **開発プロセス** | `claude-code/guidelines/common/development-process.md` | DEVELOPMENT-PROCESS.md |
| **型安全原則** | `claude-code/guidelines/common/type-safety-principles.md` | TYPE-SAFETY-PRINCIPLES.md |

### エージェント

| 正式名称 | 参照パス | 別名（使用禁止） |
|---------|---------|-----------------|
| **POエージェント** | `claude-code/agents/po-agent.md` | po-agent, PO Agent |
| **Managerエージェント** | `claude-code/agents/manager-agent.md` | manager-agent, Manager Agent |
| **Developerエージェント** | `claude-code/agents/developer-agent.md` | developer-agent, Developer Agent |
| **検証エージェント** | `claude-code/agents/verify-app.md` | verify-app, Verify App |
| **簡素化エージェント** | `claude-code/agents/code-simplifier.md` | code-simplifier, Code Simplifier |

---

## 🏷️ 正式用語

### 圏論的概念

| 正式用語 | 英語表記 | 使用禁止 |
|---------|---------|---------|
| **操作ガード** | Operation Guard | guardrails, ガードレール（文脈外） |
| **安全操作** | Safe operation | Safe操作, Safe層 |
| **要確認操作** | Boundary operation | Boundary操作, Boundary層 |
| **禁止操作** | Forbidden operation | Forbidden操作, Forbidden層 |
| **複雑度判定** | Complexity Check | ComplexityCheck, タスク判定 |

### タスク分類

| 正式用語 | 説明 | 使用禁止 |
|---------|------|---------|
| **Simple** | 直接実装（ファイル数<5, 行数<300） | シンプル, 簡単 |
| **TaskDecomposition** | Kanban + 5フェーズ（ファイル数≥5 OR 独立機能≥3） | タスク分解, 分割実装 |
| **AgentHierarchy** | PO/Manager/Developer階層 | エージェント階層, 階層実装 |

### ワークフロー

| 正式用語 | 説明 | 使用禁止 |
|---------|------|---------|
| **5フェーズワークフロー** | 分析→設計→実装→検証→改善 | 5段階検証, 5ステップ |
| **並列実行パターン** | 複数タスクの同時実行 | 並列パターン, 並行処理 |

---

## 📁 参照パス規則

### 絶対パス（推奨）

```bash
# ホームディレクトリからの絶対パス
~/.claude/CLAUDE.md
~/.claude/guidelines/common/guardrails.md

# プロジェクトルートからの絶対パス
/Users/daichi/ai-tools/claude-code/GLOSSARY.md
```

### 相対パス（使用可）

```bash
# claude-codeディレクトリからの相対パス
references/AI-THINKING-ESSENTIALS.md
guidelines/common/guardrails.md
agents/po-agent.md
```

### 使用禁止パス

```bash
# ❌ 存在しないパス
category-theory/GUARDRAILS.md
iguchi版 GUARDRAILS.md

# ❌ 曖昧な参照
GUARDRAILS.md（どのディレクトリか不明）
AI-THINKING-ESSENTIALS（拡張子なし）
```

---

## 🔗 ドキュメント間参照ルール

### 推奨フォーマット

```markdown
**詳細**: `claude-code/references/AI-THINKING-ESSENTIALS.md` 参照

**関連**:
- `claude-code/guidelines/common/guardrails.md` - ガードレール詳細
- `claude-code/GLOSSARY.md` - 用語定義
```

### 使用禁止フォーマット

```markdown
# ❌ パス不明
詳細はAI-THINKING-ESSENTIALSを参照

# ❌ 存在しないパス
詳細はGUARDRAILS.mdを参照

# ❌ 曖昧な表現
詳細は別ドキュメント参照
```

---

## 📦 統合ドキュメント

### ガードレール関連

**主ドキュメント**: `claude-code/guidelines/common/guardrails.md`

**補足ドキュメント**:
- `claude-code/references/AI-THINKING-ESSENTIALS.md` - 操作ガードの概要

**推奨読み込み順序**:
1. `claude-code/GLOSSARY.md` - 用語定義
2. `claude-code/guidelines/common/guardrails.md` - 実践ガイド
3. `claude-code/references/AI-THINKING-ESSENTIALS.md` - 全体像

### 複雑度判定関連

**主ドキュメント**: `claude-code/references/AI-THINKING-ESSENTIALS.md`

**関連ドキュメント**:
- `claude-code/commands/flow.md` - 実装例

---

## 📝 更新履歴

| 日付 | 変更内容 |
|------|---------|
| 2026-01-23 | 初版作成 - 正式名称・参照パス定義 |
