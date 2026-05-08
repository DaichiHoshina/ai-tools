---
allowed-tools: Read, Glob, Grep, Edit, MultiEdit, Write, Bash, Task, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: 直接実装コマンド - Agent不使用で直接実行。--quickオプションでhaiku高速実行。Agent Teamが必要なら /flow を使用。
---

## /dev - 実装モード

> 使い分け: `/dev` は実装フェーズのみ・Agent Team 不使用 / `/flow` はタスク自動判定 + PO→Manager→Developer×N 階層。迷ったら `/flow`。
> Agent Team は **`/flow` からのみ** 起動。`/dev` 直叩きでは Team 階層なし。

## オプション

```bash
/dev --quick <task>      # 高速モード（haiku、1-2ファイル）
/dev --parallel <task>   # 直接実行 worktree 並列（PO/Manager 経由なし）
/dev <task>              # 通常（sonnet、直接実行）
# Team 階層 + 並列が必要なら /flow --parallel
```

## --parallel 仕様

PO/Manager 経由なしで Developer×N を worktree 並列起動。判定式詳細は `references/PARALLEL-PATTERNS.md`。

| 項目 | 動作 |
|------|------|
| 並列度評価 | 強制 |
| worktree 提案 | 強制 |
| worktree 作成 | ユーザー確認必須 |

### `--parallel --auto` 確認スキップ 3 条件

1. 直接実行判定式 PASS（`LPT_makespan + 21N + 20 < sum × 0.7`、第一候補 `N=4 + T_task>58s` + 独立2件 + 完全分離）
2. clean worktree
3. branch/worktree 名衝突なし

worktree 作成失敗 → 順次実行（`N=1`、現ブランチ）に降格、`--auto` でも通知必須（`> [WARN] worktree 作成失敗 → 順次実行降格`）。

### worktree 後片付け

変更あり → ブランチ返却・親マージ・削除 / 変更なし → 自動削除 / 衝突 → 順次降格・残置。

## --quick（旧 /quick-fix）

用途: 1-2 ファイルの typo / 小バグ / 数行変更。**haiku 使用、Agent Team 不使用、確認最小限**。

フロー: ファイル特定 → 修正（Serena MCP）→ verify（lint/type）→ commit 提案。

3 ファイル以上 / 設計判断必要 → 通常 `/dev` または `/flow`。

## 思考モード

**always ultrathink** - 複雑実装は深く思考してから実行。安易な実装回避、設計意図を理解した上でコード化。

## Step 0: ガイドライン読込（条件付き）

| 状況 | 動作 |
|------|------|
| `--quick` | skip（トークン節約） |
| 1-2 ファイル軽微 | skip 可（既知パターンなら不要） |
| 新機能・設計判断 | `load-guidelines`（サマリ推奨） |
| UI 開発 | `ui-skills` 推奨 |
| Backend | `backend-dev` 推奨 |

```
/load-guidelines        # サマリのみ（~2,500 トークン）
/load-guidelines full   # 詳細込み（+~5,500 トークン）
```

詳細マッピング: `references/command-resource-map.md`。

## 実行フロー

1. ガイドライン読込
2. Serena MCP でコード分析
3. TaskCreate で計画
4. ユーザー確認
5. 実装
6. lint/test 実行

## 優先順位

1. 型安全性（any/as 禁止）
2. ガイドライン準拠
3. アーキテクチャパターン
4. テスタビリティ

## 実装後の品質チェック（必須）

完了後 `/lint-test` で言語自動判定 + 一括検証（lint/typecheck/test/build）。エラー 0 → 完了報告、あり → 自動修正試行。

| 状況 | 動作 |
|------|------|
| 同アプローチ 2 回連続失敗 | `/clear` 提案して停止、方針再整理要求 |
| `--quick` で haiku 利用不可 | sonnet フォールバック、軽微修正続行 |
| Serena MCP 失敗 | grep/Read 直接アクセスに降格、warning |

PushNotification: 3 分超タスク完了のみ通知（`[dev] {task概要} 完了`）。

## 次アクション

```
/dev 完了
  → /lint-test → /test → /review → /git-push
  → エラー時: /diagnose
```

## 関連コマンド

| コマンド | 関係 |
|---------|------|
| `/refactor` | 動作不変の構造改善。`/dev` 後に実行可 |
| `/tdd` | テスト駆動。`/dev` のテスト優先版 |
| `/lint-test` | CI 相当チェック。`/dev` 後推奨 |

**実装前はユーザー確認必須。Serena MCP でコード操作。**
