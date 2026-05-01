---
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*, mcp__context7__*
description: 設計・計画用コマンド - PO Agent で戦略策定（読み取り専用）
---

## /plan - 設計・計画モード

## /design-doc との境界

| 観点 | `/design-doc` | `/plan`（このコマンド） |
|------|--------------|----------------------|
| 主目的 | チームに **設計判断** を伝える | 実装の **Phase 分け** を決める |
| 出力 | 12 セクション md（Why/比較/失敗ケース/移行戦略） | Phase 1/2/... と Worktree 要否 |
| 入力 | PRD or 自然言語 | Design Doc or 設計済前提 |
| 連携 Agent | なし（直接 Edit） | PO Agent（複雑時） |

両方必要なケースは大型機能（`/design-doc` で設計を伝える → `/plan` で手順に落とす）。小型修正は `/plan` のみで十分。

詳細フロー: `references/design-phase-flow.md`

## Step 0: ガイドライン自動読み込み（必須）

計画・設計開始前に必要なガイドラインを読み込む:

### A. 設計ガイドライン（必須）
```
requires-guidelines:
  - clean-architecture
  - ddd
```

**読み込み:**
- `~/.claude/guidelines/design/clean-architecture.md` - クリーンアーキテクチャ原則
- `~/.claude/guidelines/design/domain-driven-design.md` - DDD戦術・戦略パターン

### B. 言語ガイドライン
`load-guidelines` スキルで自動検出:
- TypeScript → `typescript.md`, `eslint.md`
- Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md`
- Go → `golang.md`

### C. プロジェクト種別別ガイドライン

**インフラ計画:**
- `infrastructure/terraform.md` - IaC設計
- `infrastructure/aws-eks.md` - Kubernetes運用

### D. Skill連携
以下のSkillが自動的にガイドラインを読み込み:
- `clean-architecture-ddd` - アーキテクチャ設計支援
- `api-design` - API設計原則
- `microservices-monorepo` - マイクロサービス・モノレポ設計（検出時）

詳細な Skill / Agent マッピングは `references/command-resource-map.md` を参照。

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

## 計画保存（v2.1.9新機能）

設計ドキュメントは `plansDirectory`（デフォルト: `~/.claude/plans`）に自動保存:

```
~/.claude/plans/
  ├── YYYY-MM-DD_[project]_[feature].md  # 計画ファイル
  └── ...
```

**保存コマンド例:**
```bash
mkdir -p ~/.claude/plans
cat > ~/.claude/plans/$(date +%Y-%m-%d)_${PROJECT}_${FEATURE}.md
```

計画はセッション間で参照可能。`/reload` で以前の計画を読み込み可能。

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
| PO Agent 起動失敗 | 直接実行に降格、warning ログ。複雑タスクは要件を分割提案 |
| ガイドライン読込失敗 (load-guidelines skip) | common のみで継続、warning。設計判断は保守的に倒す |
| Serena MCP 失敗 | grep / Glob でコードベース分析、依存関係把握精度低下を warning |
| `plansDirectory` 書込失敗 | 計画はチャット出力のみ、ユーザーに手動保存案内 |

**読み取り専用** - 実装は `/dev` で実行。
