---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task, AskUserQuestion, Skill, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*
description: ワークフロー自動化 - タスクタイプを自動判定して最適なワークフローを実行
---

## /flow - 自動ワークフロー実行

> **使い分け**: `/flow`（推奨）、`/dev`（実装のみ）

タスクを伝えるだけで、最適なワークフローを自動実行。

## タスクタイプ判定

**凡例**: `*実装*` は PO 判定で展開される。

- **Team使用**: 親が `Task(po-agent)` → `Task(manager-agent)` → `Task(developer-agent)×N` 並列 → `Task(manager-agent)` 再起動で統合
- **直接実行**: `/dev`

> sub-agent は sub-agent を spawn 不可。各層は親が順次起動。

| 優先度 | キーワード | タスクタイプ | ワークフロー |
|--------|-----------|------------|------------|
| 0 | 相談, ブレスト, brainstorm | **設計相談** | /brainstorm → /prd → /plan |
| 1 | 緊急, hotfix, 本番, critical | **緊急対応** | /diagnose → *実装* → /lint-test → /git-push --pr |
| 1.5 | インシデント, 障害, エラーログ | **インシデント** | Skill(incident-response) → /diagnose → *実装* → /lint-test → /git-push --pr |
| 2 | 根本, 原因分析, rca | **バグ修正(RCA)** | /diagnose → Skill(root-cause) → *実装* → /lint-test → /git-push --pr |
| 3 | 修正, fix, バグ, bug | **バグ修正** | /diagnose → *実装* → /lint-test → /git-push --pr |
| 4 | リファクタ, 改善, refactor | **リファクタ** | /plan → *実装* → /lint-test → /test → /review → /git-push --pr |
| 5 | ドキュメント, docs | **ドキュ** | /docs → /review → /git-push --pr |
| 6 | テスト, test | **テスト** | /test → /review → /lint-test → /git-push --pr |
| 7 | 追加, 実装, 新規, add | **新機能** | /prd → /plan → *実装* → /test → /review → /lint-test → /git-push --pr |
| 8 | データ分析, analysis | **分析** | Skill(data-analysis) → /docs → /git-push --pr |
| 9 | インフラ, terraform, k8s | **インフラ** | /plan → Skill(terraform) → /lint-test → /git-push --pr |
| 10 | 調査, 診断, troubleshoot | **調査** | /diagnose → *実装* → /docs |
| 11 | その他 | **新機能**（デフォルト） | |

## オプション

```text
--skip-prd / --skip-test / --skip-review / --no-po / --interactive / --auto
```

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
2. **PO Agent 起動**: 親が `Task(po-agent)` 起動、返却で分岐。`--no-po` 時スキップ
3. **実装分岐**:
   - Team使用 → 親が manager → developer×N 並列 → manager 統合
   - 直接 → `/dev`
4. **後続**: 判定表の *実装* 以降を順次実行

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
| worktree分離 | `--auto`独立並列 | `isolation: "worktree"` 自動作成・クリーンアップ |
| `/simplify` | 実装後 | バンドル高速実行 |
| background agents | `--auto` verify-app | 非同期検証 |

### worktree並列実行

独立タスクを `Agent(isolation: "worktree", mode: "bypassPermissions", prompt: ...)` で並列起動。

- 各worktree独立、前ステップ変更は見えない
- 変更ありはブランチ返却→親がマージ、変更なしは自動クリーンアップ
- 逐次依存タスクには使わない

ARGUMENTS: $ARGUMENTS
