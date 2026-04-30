---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: 直接実装コマンド - Agent不使用で直接実行。--quickオプションでhaiku高速実行。Agent Teamが必要なら /flow を使用。
---

## /dev - 実装モード

> **📌 /flow との使い分け**
> - `/dev`: 実装フェーズのみ実行（タスク内容が明確な場合）。**Agent Team 不使用**
> - `/flow`: タスク自動判定 → 親が PO→Manager→Developer×N を順次起動（Team使用時）
> - 迷ったら `/flow` を使用
>
> **重要**: Agent Team（PO/Manager/Developer並列）は **`/flow` からのみ** 起動される。`/dev` は単独実行もしくは PO が「直接実行推奨」と判断した時のフォールバック先。`/dev` を直接呼ぶと Team階層は起動しない。

## オプション

```bash
/dev --quick <task>      # 高速モード（haiku、1-2ファイル修正専用）
/dev --parallel <task>   # 直接実行 worktree 並列（PO/Manager 経由なし）
/dev <task>              # 通常モード（sonnet、直接実行）
# Team 階層 + 並列が必要な場合は /flow --parallel を使用
```

## --parallel フラグ仕様（直接実行 worktree 並列）

`/dev --parallel` は PO/Manager 経由なしで Developer×N を worktree 並列起動。判定式・適用条件詳細は `references/PARALLEL-PATTERNS.md` 参照。

### `/dev --parallel` 3 軸

| 項目 | 動作 |
|---|---|
| 並列度評価 | 強制 |
| worktree 提案 | 強制 |
| worktree 作成 | ユーザー確認必須 |

### `/dev --parallel --auto` 確認スキップ 4 条件

`--auto` 併用時、以下 4 条件すべて満たす場合のみ確認をスキップ:

1. 直接実行判定式 PASS（`LPT_makespan + 21N + 20 < sum × 0.7`、`N=4 + T_task>58s` が第一候補、+ 独立 2 件 + 完全分離）
2. clean worktree
3. branch / worktree 名衝突なし
4. 作成失敗時の自動フォールバック

### worktree 後片付け方針

- 変更あり: ブランチ返却 → 親がマージ → worktree 削除
- 変更なし: 自動削除
- マージ衝突: 順次実行降格、worktree 残置してユーザー引き継ぎ

### --quick モード（旧 /quick-fix）

**用途**:
- 1-2ファイルの単純な修正
- typo修正、小さなバグ修正
- 軽微な変更（数行程度）

**特徴**:
- **haiku model**使用（高速・低コスト）
- **Agent Team不使用**（直接実行）
- 確認最小限

**実行フロー**:
1. 対象ファイル特定
2. 修正実行（Serena MCP使用）
3. verify（lint/type check）
4. commit提案

**使用例**:
```
/dev --quick typoを修正
/dev --quick この関数のバグを直して
```

**注意**: 複雑なタスクには不向き。3ファイル以上の変更や設計判断が必要な場合は通常の `/dev` または `/flow` を使用。

## 思考モード（重要）

**always ultrathink** - 複雑な実装では必ず深く思考してから実行。安易な実装を避け、設計意図を理解した上でコードを書く。

## Step 0: ガイドライン読み込み（条件付き）

**判断基準**:
- `--quick`モード → ガイドライン読み込みスキップ（トークン節約）
- 1-2ファイルの軽微な修正 → スキップ可（既知のパターンなら不要）
- 新機能実装・設計判断 → `load-guidelines` 実行（サマリーモード推奨）
- UI開発（Tailwind/React検出時） → `ui-skills` スキル推奨

```
/load-guidelines        # サマリーのみ（~2,500トークン）
/load-guidelines full   # 詳細ガイドライン込み（+~5,500トークン）
```

**推奨 Skill**: UI開発時は `ui-skills`、Backend開発時は `backend-dev`。詳細は `references/command-resource-map.md` を参照。

## /dev と /flow の使い分け

| 状況 | 使うコマンド |
|------|-------------|
| タスク内容が明確、1-5ファイル程度 | `/dev` |
| 複雑なタスク、Agent Teamが必要 | `/flow` |
| 1-2ファイルの軽微な修正 | `/dev --quick` |

**`/dev` はAgent Teamを使用しない。** Agent Team（PO→Manager→Developer）が必要な場合は `/flow` を使用すること。

## 実行フロー

1. ガイドライン読込
2. Serena MCP でコード分析
3. TaskCreate で計画
4. ユーザー確認
5. 実装
6. lint/test 実行

## 優先順位

1. **型安全性** - any/as 禁止
2. **ガイドライン準拠**
3. **アーキテクチャパターン**
4. **テスタビリティ**

## 実装後の自動品質チェック（必須）

実装完了後、以下を自動実行:

```bash
# 言語別の静的解析
# TypeScript
npm run lint && npx tsc --noEmit

# Go
golangci-lint run && go vet ./...

# Python
ruff check . && mypy .
```

**チェック結果の対応:**
- エラー 0件 → ユーザーに完了報告
- エラーあり → 自動修正を試行、修正不可なら報告

**PushNotification:** 実行開始から3分以上経過したタスクの完了時、PushNotification toolで通知する（`"[dev] {task概要} 完了"`）。短時間タスクでは通知しない。

## 次のアクション

```
/dev 完了
  → /lint-test（品質チェック）
  → /test（テスト作成・実行）
  → /review（コードレビュー）
  → /git-push（Git操作）
  → エラー時: /diagnose
```

## 関連コマンド

| コマンド | 関係 |
|---------|------|
| `/refactor` | 動作を変えずに構造改善。`/dev` の後に実行可能 |
| `/tdd` | テスト駆動開発モード。`/dev` のテスト優先版 |
| `/lint-test` | CI相当チェック。`/dev` 完了後に推奨 |

**実装前はユーザー確認必須。Serena MCP でコード操作。**
