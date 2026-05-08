---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: 設計・計画用コマンド - PO Agent で戦略策定（読み取り専用）
---

## /plan - 設計・計画モード

## /design-doc との境界

| 観点 | `/design-doc` | `/plan` |
|------|--------------|---------|
| 主目的 | チームに**設計判断**を伝える | 実装の**Phase 分け**を決める |
| 出力 | 12 セクション md（Why/比較/失敗/移行） | Phase 1/2/... + Worktree 要否 |
| 入力 | PRD or 自然言語 | Design Doc or 設計済前提 |
| Agent | なし（直接 Edit） | PO Agent（複雑時） |

大型機能は両方（design-doc → plan）。小型修正は plan のみ。詳細: `references/design-phase-flow.md`。

## Step 0: ガイドライン自動読込（必須）

### A. 設計ガイドライン（必須）

- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`

### B. 言語ガイドライン（`load-guidelines` 自動検出）

TypeScript → `typescript.md`, `eslint.md` / Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md` / Go → `golang.md`。

### C. プロジェクト種別

インフラ → `infrastructure/terraform.md`, `infrastructure/aws-eks.md`。

### D. Skill 連携

`clean-architecture-ddd` / `api-design` / `microservices-monorepo`（検出時）が自動でガイドライン読込。詳細: `references/command-resource-map.md`。

## Agent 使用判断

| 種別 | 対象 |
|------|------|
| PO Agent 使用 | 新機能設計 / アーキテクチャ決定 / 複数コンポーネント / Worktree 必要 |
| 直接実行 | 単一ファイル修正 / 小規模改善 |

## PO Agent フロー

```
Task(subagent_type: "po-agent") 起動
  → 要件分析 → アーキテクチャ設計 → Worktree 要否（要確認） → 実装方針
  → 設計ドキュメント出力
  → 次アクション提案（/dev へ）
```

## 直接実行フロー

1. ガイドライン読込（Step 0）
2. Serena MCP でコードベース分析
3. 設計ドキュメント作成
4. `/dev` 実装計画提案

## 計画保存

`plansDirectory`（既定 `~/.claude/plans`）に保存。

```
~/.claude/plans/YYYY-MM-DD_[project]_[feature].md
```

セッション間で参照可、`/reload` で読込。

## 出力フォーマット

```
# Design: [機能名]

## 要件
- [ ] 要件1

## アーキテクチャ
- パターン: [選択理由]
- 構成: [ディレクトリ構造]

## 実装計画
Phase 1: [タスク]
Phase 2: [タスク]

## Worktree
- 必要: Yes/No
- ブランチ名: [提案]
```

## 優先順位

1. 要件の明確化
2. アーキテクチャ適合性
3. 拡張性・保守性
4. テスタビリティ

## 失敗時の挙動

| 状況 | 動作 |
|------|------|
| PO Agent 起動失敗 | 直接実行降格、warning。複雑タスクは要件分割提案 |
| ガイドライン読込失敗 | common のみで継続、設計判断は保守側 |
| Serena MCP 失敗 | grep/Glob で代替、精度低下を warning |
| `plansDirectory` 書込失敗 | チャット出力のみ、手動保存案内 |

**読み取り専用** - 実装は `/dev`。
