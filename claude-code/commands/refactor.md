---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, TodoWrite, mcp__serena__*, mcp__context7__*
description: リファクタリング用コマンド（言語ガイドライン自動読み込み）
---

## /refactor - リファクタリングモード

## 思考モード（重要）

**always ultrathink** - リファクタリングでは必ず深く思考してから実行。既存コードの意図を理解し、動作を変えずに改善する。

## Step 0: ガイドライン自動読み込み（必須）

リファクタリング開始前に必要なガイドラインを読み込む:

### A. 言語ガイドライン
`load-guidelines` スキルで自動検出:
- TypeScript → `typescript.md`, `eslint.md`
- Next.js → `nextjs-react.md`, `tailwind.md`, `shadcn.md`
- Go → `golang.md`

### B. 設計ガイドライン（必須）
```
requires-guidelines:
  - clean-architecture
  - ddd
```

**読み込み:**
- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`

### C. Skill連携
以下のSkillが自動的にガイドラインを読み込み:
- `clean-architecture-ddd` - クリーンアーキテクチャ・DDD原則
- `code-quality-review` - 設計・コード品質・型安全性の統合チェック（旧: code-smell-review, type-safety-review 等を統合）

## フロー

1. **ガイドライン読み込み** - 上記Step 0を実行
2. **分析** - Serena MCP で品質問題特定、影響範囲分析
3. **計画作成** - リファクタリング計画を TodoWrite で管理
4. **ユーザー確認**（必須）
5. **実行** - 段階的にリファクタリング
6. **テスト実行** - 動作が変わっていないことを確認
7. **レポート** - Before/After 比較

## 優先順位

1. **型安全性向上** - any/as 排除（最優先）
2. **ガイドライン準拠**
3. **アーキテクチャパターン** - Clean Architecture・DDD
4. **重複コード排除** - DRY原則
5. **可読性向上**

## 出力フォーマット

```
# Refactoring: [対象]

## Changes
- Files: X件 / +Y -Z lines

## Improvements
- ✅ any 型を X箇所削除
- ✅ 複雑度 Y → Z に改善

## Test: [PASS/FAIL]
```

## 次のアクション

- 成功 → `/test` or `/review`
- テスト失敗 → `/debug`
- 追加改善可能 → `/refactor [内容]`

**リファクタリング前はユーザー確認必須。動作を変えない（テストで保証）。**
