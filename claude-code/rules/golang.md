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

## テスト
- table-driven tests推奨
- テストヘルパーは t.Helper() 呼び出し
