# Commands Guide - コマンド使い分けガイド

Claude Code 37 コマンドの使い分け。

## Core 3 コマンド（推奨）

**初心者はこの3つだけ覚えればOK**

| コマンド | 用途 | 使用頻度 |
|---------|------|---------|
| **`/flow`** | 万能（迷ったらこれ） | ⭐️⭐️⭐️⭐️⭐️ |
| **`/dev`** | 実装専用（やることが明確） | ⭐️⭐️⭐️⭐️ |
| **`/review`** | コードレビュー | ⭐️⭐️⭐️⭐️ |

**使い分け**:
- 不明確 / 大規模 → `/flow`
- 実装明確 / 1-2ファイル → `/dev`
- レビュー → `/review`

## Tier 2: よく使う（4 コマンド）

| コマンド | 用途 | タイミング |
|---------|------|-----------|
| `/git-push` | commit→push→PR/MR 一括 | 実装完了後 |
| `/plan` | 設計・計画のみ | 大規模実装前 |
| `/diagnose` | エラー解析・修正提案 | バグ発生時 |
| `/review-fix-push` | レビュー→修正→push 一括 | レビュー対応 |

## Tier 3: 専門コマンド

### 開発・テスト系

| コマンド | 用途 |
|---------|------|
| `/test` | テストコード作成 |
| `/test --tdd` | TDD（RED-GREEN-REFACTOR） |
| `/refactor` | リファクタリング |
| `/lint-test` | ローカルCI相当（build/lint/test/typecheck） |
| `/ui` | UI 実装・レビュー・監査統合 |

### 調査・分析系

| コマンド | 用途 |
|---------|------|
| `/explore` | 並列探索（複数観点） |
| `/analytics` | Claude Code 利用状況分析 |
| `/dashboard` | 利用状況ダッシュボード |
| `/retrospective` | セッション振り返り |

### ドキュメント系

| コマンド | 用途 |
|---------|------|
| `/docs` | ドキュメント作成（README、API仕様書等） |
| `/prd` | PRD作成（対話式要件整理） |
| `/brainstorm` | 対話的設計精緻化 |

### ユーティリティ系

| コマンド | 用途 |
|---------|------|
| `/reload` | 設定再読み込み（compaction後） |
| `/aliases` | コマンドエイリアス定義 |
| `/memory-save` | Serena memory 即時保存 |
| `/protection-mode` | 操作保護モード適用 |
| `/groove` | YAMLマルチエージェントオーケストレーター |
| `/claude-update-fix` | Claude Code 更新後の設定差分修正 |
| `/serena-refresh` | Serena データ最新化 |

## ベストプラクティス

### 1. 迷ったら `/flow`

タスクタイプ自動判定 → 最適ワークフロー自動実行。初心者最推奨。

### 2. やることが明確なら `/dev`

条件: 1-2ファイル / 実装内容具体的 / 設計済み

### 3. 複数ファイル・不明確なら `/flow`

条件: 3ファイル以上 / 複数機能 / 要件不明確

### 4. 専門コマンドは目的が明確な時のみ

`/test`（テストだけ） / `/docs`（ドキュメントだけ） / `/prd`（要件整理だけ）

## 非推奨パターン

### 過度な専門コマンド連鎖

```
NG: /prd → /plan → /dev → /test → /review → /git-push（個別）
OK: /flow ユーザー認証機能を追加して  ← 内部で全ステップ自動実行
```

### `/dev` を万能コマンド扱い

`/dev` は実装専用。設計・要件整理が必要なら `/flow`。

### 個別チェーンの代わりに統合コマンド

`/lint-test` + `/review` + `/git-push` 個別実行 → `/review-fix-push` で1コマンド。

## 関連

- [QUICKSTART.md](./QUICKSTART.md): 3つの基本コマンド詳細
- [commands/](./commands/): 各コマンドの詳細仕様
- [SKILLS-USAGE.md](./SKILLS-USAGE.md): スキル使い分けガイド
- [AGENTS.md](./agents/README.md): エージェント→コマンド対応
