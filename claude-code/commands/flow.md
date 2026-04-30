---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> **使い分け**: `/flow`（推奨）、`/dev`（実装のみ）、`/groove`（YAML 定義型）
> `/groove` との詳細比較: `references/flow-vs-groove.md`

タスクを伝えるだけで、最適なワークフローを自動実行。

## タスクタイプ判定

**判定ルール**: 上から順にキーワードマッチし、**最初にヒットした優先度** を採用（数値が小さい行が優先）。複数の意図が混在する場合はユーザーに確認。

**凡例**: `*実装*` は PO 判定で展開される。Team経路の `/review` は `Task(reviewer-agent)` に置換される。

- **Team使用**: 親が `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` 並列 → `Task(manager-agent)` 再起動で統合 → `Task(reviewer-agent)` でレビュー → P0あれば再修正1ループ
- **直接実行**: `/dev`（レビューは `/review` コマンド経由 = comprehensive-review skill）

> sub-agent は sub-agent を spawn 不可。各層は親が順次起動。

| 優先度 | キーワード | タスクタイプ | ワークフロー |
|--------|-----------|------------|------------|
| 0 | 相談, ブレスト, brainstorm | **設計相談** | /brainstorm → /prd → /plan |
| 1 | 緊急, hotfix, 本番, critical | **緊急対応** | /diagnose → *実装* → /lint-test → /git-push --pr |
| 1.5 | インシデント, 障害, エラーログ貼付 | **インシデント** | Skill(incident-response) → /diagnose → *実装* → /lint-test → /git-push --pr |
| 2 | 根本原因, rca, 再発防止 | **バグ修正(RCA)** | /diagnose → Skill(root-cause) → *実装* → /lint-test → /git-push --pr |
| 3 | 修正, fix, バグ, bug, 不具合 | **バグ修正** | /diagnose → *実装* → /lint-test → /git-push --pr |
| 4 | リファクタ, refactor, 構造改善 | **リファクタ** | /plan → *実装* → /lint-test → /test → /review → /git-push --pr |
| 5 | ドキュメント, docs, README | **ドキュ** | /docs → /review → /git-push --pr |
| 6 | テスト作成, test追加, spec | **テスト** | /test → /review → /lint-test → /git-push --pr |
| 7 | 追加, 実装, 新規, 機能, add | **新機能** | /prd → /plan → *実装* → /test → /review → /lint-test → /git-push --pr |
| 8 | データ分析, analysis, SQL | **分析** | Skill(data-analysis) → /docs → /git-push --pr |
| 9 | インフラ, terraform, k8s, IaC | **インフラ** | /plan → Skill(terraform) → /lint-test → /git-push --pr |
| 10 | 調査のみ, 診断, troubleshoot | **調査（読み取り専用）** | /diagnose → /docs（実装しない） |
| 11 | その他 | **新機能**（デフォルト） | |

### 境界が曖昧な場合の判定指針

- 「**エラーログから修正して**」→ ログ貼付あり → 1.5 **インシデント** 採用（修正も含む）
- 「**バグの根本原因**」→ "根本" がヒット → 2 **バグ修正(RCA)** 採用
- 「**機能を改善**」→ 既存機能の動作変更 → 7 **新機能**、構造のみ変更なら 4 **リファクタ**
- 「**エラーを調査して修正**」→ 修正含む → 3 **バグ修正**（10 は読み取り専用に限定）

## オプション

```text
--skip-prd / --skip-test / --skip-review / --no-po / --interactive / --auto / --parallel
```

## --parallel フラグ仕様

`/flow --parallel` は Team 経路（PO → Manager → Developer×N）で worktree 並列を強制評価する。判定式・適用条件詳細は `references/PARALLEL-PATTERNS.md` 参照。

### `/flow --parallel` 3 軸

| 項目 | 動作 |
|---|---|
| 並列度評価 | 強制（Manager 配分計画で並列度算出を必須化） |
| worktree 提案 | 強制（PO が必ず worktree 提案を出す） |
| worktree 作成 | PO ユーザー確認必須 |

### `/flow --parallel --auto` 確認スキップ 4 条件

`--auto` 併用時、以下 4 条件すべて満たす場合のみ PO 確認をスキップ:

1. Team 判定式 PASS（`LPT_makespan + 180 + 21N < sum × 0.7`、`N=4 + T_task>147s` が第一候補）
2. clean worktree（git status 変更なし、stash も無し）
3. branch / worktree 名衝突なし
4. 作成失敗時の自動フォールバック（順次実行降格 + ユーザー通知）

### worktree 後片付け方針

- 変更あり: ブランチ返却 → 親がマージ → worktree 削除
- 変更なし: 自動削除
- マージ衝突: 順次実行降格、worktree 残置してユーザー引き継ぎ

## --auto 完全自律モード

| 判断ポイント | 動作 |
|-------------|------|
| AskUserQuestion | 呼ばない。推奨を自動採用 |
| Agent起動 | `mode: "bypassPermissions"`（承認スキップ、実行リスク自己責任） |
| push先 | 常にPR（main直push禁止） |
| PO Agent | スキップ（`--no-po`相当） |
| 設計判断 | 推奨パターン。迷ったらシンプルな方 |
| lint-test失敗 | 自動修正1回、2回失敗で停止・報告 |

フロー: タスク受領 → 判定 → 実行 → lint-test → review-fix ループ → 秘匿チェック → /git-push → Serena memory保存 → PushNotification

### review-fix ループ

`--auto` 実装完了後、`/review` → 自動修正を **Critical 0 + Warning 0** まで繰り返す（最大3回）。超過分はユーザーに報告して続行。

## 実行ロジック

1. **git status 確認**: 変更あり → /dev から、なし → 最初から
2. **軽量タスク事前判定**（PO 起動コスト 96s 回避、`--parallel` / `--no-po` 指定時はスキップ）:
   - 変更ファイル ≤ 2 AND 設計判断不要 AND 内容自明（typo・設定値・import 修正等）
   - 該当 → `/dev --quick` へ委譲（PO Agent 起動せず終了）
   - 非該当 → 次ステップへ
3. **PO Agent 起動**: 親が `Task(po-agent)` 起動、返却で分岐。`--no-po` 時スキップ
4. **実装分岐**:
   - Team使用 → 親が manager → developer×N 並列 → manager 統合
   - 直接 → `/dev`
5. **Team経路レビュー**（Team使用時のみ）: 親が `Task(reviewer-agent)` 起動（**`--codex` モード固定**、comprehensive-review + codex review 並列、両者共通指摘を優先）→ P0/P1 判定
   - **P0 あり**: 親が `Task(manager-agent)` で再配分計画 → `Task(developer-agent)×M` で修正 → `Task(reviewer-agent, --codex)` 再検証（**最大1ループ**）
   - **1ループ後も P0 残存 or P1 あり**: ユーザーに報告して続行判断（`--auto` 時は停止）
   - **codex 未インストール時**: comprehensive-review 単独にフォールバック
6. **後続**: 判定表の *実装* 以降を順次実行（Team経路の `/review` は Step 5 で完了済なので skip）

## バグ修正: 複雑度分岐

| Level | 例 | フロー |
|-------|-----|-------|
| Low | タイポ | /diagnose → *実装* → /lint-test → /review → /git-push --pr |
| Medium | ロジックバグ | /diagnose → Skill(root-cause) → *実装* → /lint-test → /review → /git-push --pr |
| High | 競合, セキュリティ | /diagnose → Task(root-cause-analyzer) → *実装* → /lint-test → /review → /git-push --pr |

## 統合ルール

- 必須: 実装 → /lint-test → /review → review-fix → /git-push
- 2回失敗ルール: 同アプローチで 2 回失敗 → `/clear` → 再整理

### 完了アクション

- Serena memory保存（`work-context-YYYYMMDD-{topic}`）
- `--auto`: 秘匿チェック → /git-push --pr → PushNotification
- 通常: AskUserQuestion「pushしますか？」

### PushNotification（--auto時）

- 成功: `"[flow-auto] {topic} 完了 → PR作成済み"`
- 失敗: `"[flow-auto] {topic} 失敗: {理由}"`
- lint-test 2回失敗: `"[flow-auto] {topic} 停止: lint-test 2回失敗"`

## 自動適用機能（v2.1.50+）

| 機能 | 条件 | 動作 |
|------|------|------|
| worktree分離 | `--parallel` または `--auto`独立並列 | `isolation: "worktree"` 自動作成・クリーンアップ |
| `/simplify` | 実装後 | バンドル高速実行 |
| background agents | `--auto` 明示要求時のみ verify-app | 通常は `/lint-test` を使用（自動起動しない） |

worktree 並列実行・適用判定詳細: `references/PARALLEL-PATTERNS.md#worktree 適用判定フロー` 参照。

ARGUMENTS: $ARGUMENTS
