---
paths:
  - "**/*.go"
---
# Golang ルール

## エラーハンドリング
- エラーは必ずハンドル（_ 禁止）
- errors.Wrap/Wrapf でコンテキスト追加
- センチネルエラーは errors.Is で比較

## 命名規則
- パッケージ名: 小文字単語
- 公開: PascalCase
- 非公開: camelCase
- 頭字語: 全て大文字（HTTP, ID, URL）

## 並行処理
- goroutineリーク防止（context使用）
- チャネルは作成者がclose
- sync.WaitGroup/errgroup でライフサイクル管理

## ログ出力
- ログは**エラー発生元で1回だけ**。errを返すならcaller側で重複させない
- ErrNotFoundはログ不要（正常系）。Repository層はそのまま返す
- NotFoundが異常かどうかはUseCase層が判断

## テスト
- table-driven tests推奨
- テストヘルパーは t.Helper() 呼び出し
- Flaky対策詳細: `guidelines/languages/go-test-stability.md`

## 詳細ガイドライン

設計パターン・ジェネリクス・アーキテクチャ構成等の詳細は `guidelines/languages/golang.md` 参照（`/load-guidelines full` で自動読込）。
