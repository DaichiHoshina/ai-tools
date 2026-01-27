---
paths: "**/*.{ts,tsx}"
---
# TypeScript ルール

## 型安全
- any型禁止
- as型キャスト控える
- unknown + 型ガード推奨
- strictNullChecks前提

## 命名規則
- 変数: camelCase
- 定数: UPPER_SNAKE_CASE
- クラス/型: PascalCase

## インポート
- 相対パス: 同ディレクトリのみ
- それ以外: エイリアス使用（@/）

## エラーハンドリング
- Result型推奨（neverthrow等）
- try-catchはシステム境界のみ
