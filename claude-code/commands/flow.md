---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> 使い分け: `/flow`（推奨）/ `/dev`（実装のみ）/ `/groove`（YAML 定義型、比較は `references/flow-vs-groove.md`）

タスクを伝えるだけで最適なワークフローを自動実行。

## タスクタイプ判定

上から順にキーワードマッチ、**最初にヒットした優先度を採用**。混在時はユーザー確認。

凡例: `*実装*` は PO 判定で展開。Team 経路の `/review` は `Task(reviewer-agent)` 置換。

- **Team使用**: 親が `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` 並列 → manager 統合 → `Task(reviewer-agent)` → P0 あれば再修正1ループ
- **直接実行**: `/dev`（レビューは `/review` = comprehensive-review skill）
- sub-agent は spawn 不可、各層は親が順次起動

| # | キーワード | タスク | ワークフロー |
|---|-----------|--------|------------|
| 0 | 相談, ブレスト, brainstorm | 設計相談 | /brainstorm → /prd → /plan |
| 1 | 緊急, hotfix, 本番, critical | 緊急 | /diagnose → *実装* → /lint-test → /git-push --pr |
| 1.5 | インシデント, 障害, エラーログ貼付 | インシデント | Skill(incident-response) → /diagnose → *実装* → /lint-test → /git-push --pr |
| 2 | 根本原因, rca, 再発防止 | RCA | /diagnose → Skill(root-cause) → *実装* → /lint-test → /git-push --pr |
| 3 | 修正, fix, バグ, 不具合 | バグ修正 | /diagnose → *実装* → /lint-test → /git-push --pr |
| 4 | リファクタ, refactor, 構造改善 | リファクタ | /plan → *実装* → /lint-test → /test → /review → /git-push --pr |
| 5 | ドキュメント, docs, README | ドキュ | /docs → /review → /git-push --pr |
| 6 | テスト作成, test追加, spec | テスト | /test → /review → /lint-test → /git-push --pr |
| 7 | 追加, 実装, 新規, 機能, add | 新機能 | /prd → /plan → *実装* → /test → /review → /lint-test → /git-push --pr |
| 8 | データ分析, analysis, SQL | 分析 | Skill(data-analysis) → /docs → /git-push --pr |
| 9 | インフラ, terraform, k8s, IaC | インフラ | /plan → Skill(terraform) → /lint-test → /git-push --pr |
| 10 | 調査のみ, 診断, troubleshoot | 調査（読取専用） | /diagnose → /docs |
| 11 | その他 | 新機能（既定） | |

境界判定: 「エラーログから修正」=1.5 / 「バグの根本原因」=2 / 「機能改善」= 7（構造のみ=4）/ 「エラー調査して修正」=3。

## オプション

```text
--skip-prd / --skip-test / --skip-review / --no-po / --interactive / --auto / --parallel
```

## --parallel

Team 経路で worktree 並列を強制評価。判定式詳細は `references/PARALLEL-PATTERNS.md`。

| 項目 | 動作 |
|------|------|
| 並列度評価 | 強制（Manager 必須） |
| worktree 提案 | 強制（PO 必須） |
| worktree 作成 | PO ユーザー確認必須 |

### `--parallel --auto` 確認スキップ 4 条件

1. Team 判定式 PASS（`LPT_makespan + 180 + 21N < sum × 0.7`、第一候補 `N=4 + T_task>147s`）
2. clean worktree（git status / stash 共に無し）
3. branch/worktree 名衝突なし
4. 作成失敗時は順次実行降格＋通知

### worktree 後片付け

変更あり → ブランチ返却・親がマージ・worktree 削除 / 変更なし → 自動削除 / 衝突 → 順次降格・worktree 残置。

### `worktree.baseRef` 設定（高度ユースケース）

デフォルト `fresh`（`origin/<default>` ベース）採用済み = clean main で worktree 作成。`~/.claude/settings.local.json` で個別タスク単位に `"head"` 指定すると未 push commit を新 worktree に持ち込める（in-progress branch から派生したい時のみ）。常用非推奨（main 汚染リスク）。

## --auto 完全自律モード

| 判断 | 動作 |
|------|------|
| AskUserQuestion | 呼ばない、推奨自動採用 |
| Agent起動 | `mode: "bypassPermissions"` |
| push先 | 常に PR（main 直 push 禁止） |
| PO Agent | スキップ（`--no-po`相当） |
| 設計判断 | 推奨・シンプル優先 |
| lint-test 失敗 | 自動修正1回、2回失敗で停止・報告 |

フロー: 受領 → 判定 → 実行 → lint-test → review-fix → 秘匿チェック → /git-push → Serena memory → PushNotification。

review-fix ループ: 実装後 `/review` → 自動修正 を **Critical 0 + Warning 0** まで繰り返す（最大3回、超過分は報告して続行）。

## 実行ロジック

1. git status 確認: 変更あり → /dev から、なし → 最初から
2. **軽量タスク事前判定**（PO 起動 96s 回避、`--parallel`/`--no-po` 時 skip）: 変更 ≤2 AND 設計判断不要 AND 内容自明 → `/dev --quick` 委譲、それ以外は次へ
3. PO Agent 起動（`--no-po` 時 skip）
4. 実装分岐: Team 使用 → manager → developer×N → manager 統合 / 直接 → `/dev`
5. **Team レビュー**: `Task(reviewer-agent, --codex)` 固定（comprehensive + codex 並列、共通指摘優先）→ P0/P1 判定
   - P0 あり: manager 再配分 → developer×M 修正 → reviewer 再検証（**最大1ループ**）
   - 1ループ後も P0 残存 or P1: 報告して続行（`--auto` 時は停止）
   - codex 未導入時: comprehensive 単独フォールバック
6. 判定表の *実装* 以降を順次実行（Team の `/review` は Step 5 で完了 skip）

## バグ修正 複雑度

| Level | 例 | フロー |
|-------|-----|-------|
| Low | タイポ | /diagnose → *実装* → /lint-test → /review → /git-push --pr |
| Medium | ロジックバグ | /diagnose → Skill(root-cause) → *実装* → /lint-test → /review → /git-push --pr |
| High | 競合・セキュリティ | /diagnose → Task(root-cause-analyzer) → *実装* → /lint-test → /review → /git-push --pr |

## 統合ルール

- 必須: 実装 → /lint-test → /review → review-fix → /git-push
- 2回失敗ルール: 同アプローチで2回失敗 → `/clear` → 再整理

### 完了アクション

- Serena memory 保存（`work-context-YYYYMMDD-{topic}`）
- `--auto`: 秘匿チェック → /git-push --pr → PushNotification
- 通常: AskUserQuestion「pushしますか？」

### PushNotification（--auto）

- 成功: `[flow-auto] {topic} 完了 → PR作成済み`
- 失敗: `[flow-auto] {topic} 失敗: {理由}`
- lint-test 2回失敗: `[flow-auto] {topic} 停止: lint-test 2回失敗`

## 自動適用機能

| 機能 | 条件 | 動作 |
|------|------|------|
| worktree 分離 | `--parallel` または `--auto` 独立並列 | `isolation: "worktree"` 自動作成・cleanup |
| `/simplify` | 実装後 | バンドル高速実行 |
| 実装後検証 | `--auto` 完了時 | `/lint-test`（verify-app は明示時のみ） |

worktree 適用判定: `references/PARALLEL-PATTERNS.md#worktree 適用判定フロー`。

ARGUMENTS: $ARGUMENTS
