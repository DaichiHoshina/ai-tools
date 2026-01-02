# 共通ガイドライン（サマリー版）

## 📚 詳細仕様一覧（common/）

| ファイル | 内容 |
|---------|------|
| `claude-code-tips.md` | Claude Code実行環境特化ノウハウ |
| `code-quality-design.md` | SOLID原則、Clean Code、コードレビュー基準 |
| `development-process.md` | Git運用、ブランチ戦略、PR/コミット規約 |
| `document-management.md` | ドキュメント作成方針、Markdown規約 |
| `error-handling-patterns.md` | エラーハンドリング標準パターン |
| `testing-guidelines.md` | テスト戦略、AAA/Given-When-Then、カバレッジ基準 |
| `type-safety-principles.md` | 型安全性原則、any禁止、型ガード活用 |
| `unused-code-detection.md` | 未使用コード検出・削除ポリシー |

## 型安全性（最優先）

| 項目 | NG | OK |
|------|----|----|
| any型 | `data: any` | `data: T` (ジェネリクス) |
| 型アサーション | `data as string` | `typeof data === 'string'` (型ガード) |
| strict mode | 無効 | `tsconfig.json`で有効化 |

## アーキテクチャパターン

| パターン | 原則 |
|----------|------|
| **Clean Architecture** | レイヤー分離（UI/UseCase/Domain/Infrastructure） |
| **DDD** | ドメインモデル中心設計、集約・値オブジェクト活用 |
| **依存性注入** | 疎結合、テスタビリティ向上 |

## エラーハンドリング標準

| 言語 | 推奨パターン |
|------|-------------|
| TypeScript | `try-catch` + 具体的エラーメッセージ |
| Go | `if err != nil { return fmt.Errorf("context: %w", err) }` |
| 共通 | 境界値・null/undefinedチェック必須 |

## テスト基準

| 項目 | 基準 |
|------|------|
| **パターン** | AAA（Arrange/Act/Assert）または Given-When-Then |
| **カバレッジ** | 80%以上目標 |
| **独立性** | 各テストは独立実行可能 |
| **モック** | 外部依存は適切にモック化 |

## 未使用コード削除ポリシー

| 対象 | 削除基準 |
|------|----------|
| 後方互換残骸 | 旧バージョン対応コード（非推奨API等） |
| 未使用import/変数 | linterで検出 → 即削除 |
| デッドコード | 到達不能コード、未使用関数 |

## 開発プロセス

| 項目 | 標準 |
|------|------|
| **ブランチ戦略** | Git Flow または GitHub Flow |
| **コミットメッセージ** | `feat:`, `fix:`, `docs:` など接頭辞必須 |
| **PR** | レビュー必須、自動テスト通過後マージ |
