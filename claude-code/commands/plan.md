---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: 設計・計画用コマンド - PO Agent で戦略策定（読み取り専用）
---

## /plan - 設計・計画モード

## Step 0: ガイドライン自動読み込み（必須）

計画・設計開始前に必要なガイドラインを読み込む:

### A. 設計ガイドライン（必須）
```
requires-guidelines:
  - clean-architecture
  - ddd
  - requirements-engineering
```

**読み込み:**
- `~/.claude/guidelines/design/clean-architecture.md` - クリーンアーキテクチャ原則
- `~/.claude/guidelines/design/domain-driven-design.md` - DDD戦術・戦略パターン
- `~/.claude/guidelines/design/requirements-engineering.md` - 要件定義手法

### B. 言語ガイドライン
`load-guidelines` スキルで自動検出:
- TypeScript → `typescript.md`, `eslint.md`
- Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md`
- Go → `golang.md`

### C. プロジェクト種別別ガイドライン

**マイクロサービス:**
- `design/microservices-kubernetes.md` - サービス分割、通信パターン

**インフラ計画:**
- `infrastructure/terraform.md` - IaC設計
- `infrastructure/aws-eks.md` - Kubernetes運用

**UI/UX設計:**
- `design/ui-ux-guidelines.md` - ユーザビリティ、アクセシビリティ

### D. Skill連携
以下のSkillが自動的にガイドラインを読み込み:
- `clean-architecture-ddd` - アーキテクチャ設計支援
- `api-design` - API設計原則

## Agent 使用判断

### PO Agent を使用（複雑な計画）

- 新機能の設計
- アーキテクチャ決定
- 複数コンポーネントにまたがる計画
- Worktree 作成が必要な作業

### 直接実行（単純な計画）

- 単一ファイルの修正計画
- 小規模な改善計画

## PO Agent フロー

```
1. PO Agent 起動（Task tool, subagent_type: "po-agent"）
   - 要件分析
   - アーキテクチャ設計
   - Worktree 要否判断（ユーザー確認）
   - 実装方針策定
   ↓
2. 設計ドキュメント出力
   ↓
3. 次アクション提案 → `/dev` で実装開始
```

## 直接実行フロー

1. **ガイドライン読込** - 上記Step 0を実行
2. **Serena MCP でコードベース分析** - 既存構造・パターン把握
3. **設計ドキュメント作成** - ガイドライン準拠の設計
4. **次アクション提案** - `/dev` での実装計画

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

**読み取り専用** - 実装は `/dev` で実行。
