# PRD: CI設定追加 - デグレ防止自動化

## 目的

ai-toolsリポジトリにCI設定を追加し、PRごとの自動チェックでデグレを防止する。

## 背景

現状、以下の問題がある:
- install.sh/sync.sh を変更しても自動検証なし
- シェルスクリプトの構文エラーを検出できない
- マークダウンの形式崩れに気づかない
- PR作成時にデグレが混入するリスク

## 対象範囲

### 検証対象ファイル

**シェルスクリプト（22ファイル）**:
- claude-code/install.sh
- claude-code/sync.sh
- claude-code/hooks/*.sh（10ファイル）
- claude-code/scripts/*.sh（4ファイル）
- claude-code/lib/*.sh（6ファイル）

**マークダウン（134ファイル）**:
- claude-code/**/*.md（skills, commands, guidelines, agents等）
- README.md, CLAUDE.md, CANONICAL.md, AGENTS.md等

### 実装する検証項目

| 検証項目 | ツール | 対象ファイル | 検証内容 |
|----------|--------|------------|---------|
| **1. シェルチェック** | shellcheck | 全.shファイル | 構文エラー、ベストプラクティス違反 |
| **2. マークダウンlint** | markdownlint | 全.mdファイル | 形式エラー、リンク切れ |
| **3. install.shテスト** | 手動スクリプト | install.sh | インストール可否、エラー検出 |
| **4. sync.shテスト** | 手動スクリプト | sync.sh | 同期処理の動作確認 |

## 要件定義

### 機能要件

**FR-1: GitHub Actions Workflow**
- PR作成時とpushイベント時に自動実行
- mainブランチへのpushでも実行

**FR-2: shellcheck**
- 全.shファイルを検証
- SC2086, SC2155等の重要な警告を検出
- エラー発生時はCIを失敗させる

**FR-3: markdownlint**
- 全.mdファイルを検証
- MD013（行長制限）等のルールを適用
- 警告のみの場合はCI成功（strict modeは不採用）

**FR-4: install.shテスト**
- 一時ディレクトリでinstall.shを実行
- インストール完了を確認
- エラー発生時はCI失敗

**FR-5: sync.shテスト**
- to-local, from-local, diffの各モードをテスト
- エラー発生時はCI失敗

### 非機能要件

**NFR-1: 実行速度**
- CI全体の実行時間: 5分以内

**NFR-2: 保守性**
- GitHub Actions workflowはシンプルで読みやすい構成
- 各ステップは独立して実行可能

**NFR-3: 拡張性**
- 将来的にテストを追加しやすい構造

## 成功基準

1. PRごとにCIが自動実行される
2. shellcheck, markdownlintがすべてのファイルをチェックする
3. install.sh, sync.shのテストが通る
4. デグレが混入した場合、CIが失敗してマージをブロックする

## 技術スタック

- **CI環境**: GitHub Actions
- **shellcheck**: シェルスクリプト静的解析
- **markdownlint-cli**: マークダウンlint
- **Bash**: テストスクリプト

## スケジュール

| フェーズ | 内容 | 所要時間 |
|---------|------|---------|
| Phase 1 | PRD作成 | 完了 |
| Phase 2 | Plan（設計） | 10分 |
| Phase 3 | Dev（実装） | 20分 |
| Phase 4 | Simplify（簡素化） | 5分 |
| Phase 5 | Test（検証） | 10分 |
| Phase 6 | Review | 5分 |
| Phase 7 | Verify | 5分 |
| Phase 8 | PR作成 | 5分 |

## リスクと対策

| リスク | 影響度 | 対策 |
|-------|--------|------|
| shellcheckの誤検知 | 中 | .shellcheckrc でルール調整 |
| markdownlintのstrict | 中 | .markdownlintrc で緩和 |
| CI実行時間オーバー | 低 | 並列実行で最適化 |

## 付録: ファイル統計

- シェルスクリプト: 22ファイル
- マークダウン: 134ファイル
- 合計: 156ファイル
