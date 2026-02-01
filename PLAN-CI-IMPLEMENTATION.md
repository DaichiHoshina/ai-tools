# 実装計画: CI設定追加

## アーキテクチャ概要

```
GitHub PR/Push
    ↓
GitHub Actions Workflow
    ↓
┌─────────────────────────────────┐
│ Job 1: shellcheck（並列）       │
│ Job 2: markdownlint（並列）     │
│ Job 3: install test（並列）     │
│ Job 4: sync test（並列）        │
└─────────────────────────────────┘
    ↓
全Job成功 → CI成功 ✓
いずれか失敗 → CI失敗 ✗
```

## ファイル構成

```
.github/
  workflows/
    ci.yml                    # メインCI workflow
.shellcheckrc                 # shellcheck設定
.markdownlintrc              # markdownlint設定
scripts/
  test-install.sh            # install.shテストスクリプト
  test-sync.sh               # sync.shテストスクリプト
```

## 実装詳細

### 1. .github/workflows/ci.yml

**トリガー**:
- pull_request（全ブランチ）
- push（mainブランチのみ）

**Job構成**:

#### Job 1: shellcheck
- Ubuntu最新版で実行
- shellcheckをインストール（apt-get）
- 全.shファイルを検証
- エラーコード: SC2086, SC2155等を検出

#### Job 2: markdownlint
- Ubuntu最新版で実行
- markdownlint-cliをインストール（npm）
- 全.mdファイルを検証
- .markdownlintrc設定適用

#### Job 3: install-test
- Ubuntu最新版で実行
- 一時ディレクトリで実行
- install.shの動作確認
- エラー検出

#### Job 4: sync-test
- Ubuntu最新版で実行
- sync.shの各モード（to-local, from-local, diff）をテスト
- エラー検出

### 2. .shellcheckrc

**除外ルール**:
- SC1090: source先が変数の場合（lib/i18n.sh等）
- SC1091: sourceファイルが見つからない場合（CI環境特有）

**有効化ルール**:
- SC2086: 変数のクォート忘れ
- SC2155: declare -r と代入の同時実行
- SC2164: cd失敗時の処理なし

### 3. .markdownlintrc

**緩和ルール**:
- MD013: 行長制限を緩和（200文字まで）
- MD033: HTMLタグ許可（テーブル等で使用）
- MD041: 先頭H1なくてもOK

**厳格ルール**:
- MD001: ヘッダーレベルの段階的増加
- MD003: ヘッダースタイル統一
- MD022: ヘッダー前後の空行

### 4. scripts/test-install.sh

**テストフロー**:
1. 一時ディレクトリ作成
2. install.shを--dry-runモードで実行（将来追加）
3. 現時点では構文チェックのみ
4. エラーがあれば終了コード1

**検証項目**:
- install.shが実行可能
- 基本的な構文エラーなし

### 5. scripts/test-sync.sh

**テストフロー**:
1. 一時ディレクトリ作成
2. sync.sh diffモードを実行
3. エラーがあれば終了コード1

**検証項目**:
- sync.shが実行可能
- diffモードが正常動作

## 並列実行戦略

**並列実行Job**:
- shellcheck（独立）
- markdownlint（独立）
- install-test（独立）
- sync-test（独立）

**メリット**:
- 4つのJobを同時実行 → 実行時間短縮（5分以内）
- 1つ失敗してもすべて実行 → 全エラーを一度に確認可能

## エラーハンドリング

**shellcheckエラー**:
- SC2086等の重要エラー → CI失敗
- SC1090等の情報 → 警告のみ

**markdownlintエラー**:
- MD001等の構造エラー → CI失敗
- MD013（行長）→ 警告のみ（緩和設定）

**テストエラー**:
- install.sh実行エラー → CI失敗
- sync.sh実行エラー → CI失敗

## 実装ステップ

### ステップ1: 設定ファイル作成
- .shellcheckrc
- .markdownlintrc

### ステップ2: テストスクリプト作成
- scripts/test-install.sh
- scripts/test-sync.sh

### ステップ3: GitHub Actions workflow作成
- .github/workflows/ci.yml

### ステップ4: ローカル検証
- shellcheck 実行
- markdownlint 実行
- テストスクリプト実行

## 検証計画

### Phase 1: ローカル検証
- shellcheck claude-code/install.sh
- markdownlint README.md
- bash scripts/test-install.sh
- bash scripts/test-sync.sh

### Phase 2: CI検証
- PR作成してCIトリガー
- 全Jobの成功確認
- エラー時のログ確認

## 期待される結果

**成功時**:
- 全4 Jobsが成功（緑チェックマーク）
- PRマージ可能

**失敗時**:
- 失敗したJobが明確に表示（赤X）
- エラーログで原因特定
- PRマージブロック

## セキュリティ考慮事項

- secrets不要（公開リポジトリ前提）
- 外部スクリプト実行なし
- パブリックなnpmパッケージのみ使用

## パフォーマンス目標

- shellcheck: 1分以内
- markdownlint: 2分以内
- install-test: 30秒以内
- sync-test: 30秒以内
- 合計: 5分以内（並列実行）
