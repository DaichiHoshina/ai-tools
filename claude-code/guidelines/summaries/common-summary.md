# 共通ガイドライン（サマリー版）

## 詳細仕様（common/）

| ファイル | 内容 |
|---------|------|
| `code-quality-design.md` | SOLID原則、Clean Code |
| `testing-guidelines.md` | テスト戦略、AAA、カバレッジ基準 |
| `error-handling-patterns.md` | エラーハンドリング標準 |
| `type-safety-principles.md` | 型安全性原則、any禁止 |
| `token-management.md` | トークン予算ポリシー |
| `development-process.md` | Git運用、ブランチ戦略 |
| `unused-code-detection.md` | 未使用コード削除ポリシー |
| `claude-code-tips.md` | Claude Code実行環境ノウハウ |
| `document-management.md` | ドキュメント・Markdown規約 |

## 最重要ルール

| 項目 | NG | OK |
|------|----|----|
| any型 | `data: any` | `data: T`（ジェネリクス） |
| 型アサーション | `data as string` | `typeof data === 'string'`（型ガード） |
| テストパターン | - | AAA（Arrange/Act/Assert）、カバレッジ80%以上 |
| コミット | 接頭辞なし | `feat:`, `fix:`, `docs:` 等 |

## トークン管理

| 項目 | 制限 |
|------|------|
| コード例 | 5行以内 |
| ファイル読み込み | 500行以下 or limit指定 |
| 警告閾値 | 80%で警告、90%で/reload推奨 |
