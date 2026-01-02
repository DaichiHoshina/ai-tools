---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, TodoWrite, mcp__serena__check_onboarding_performed, mcp__serena__find_file, mcp__serena__find_referencing_symbols, mcp__serena__find_symbol, mcp__serena__get_symbols_overview, mcp__serena__list_dir, mcp__serena__read_memory, mcp__serena__search_for_pattern, mcp__serena__write_memory, mcp__serena__execute_shell_command, mcp__serena__insert_after_symbol, mcp__serena__insert_before_symbol, mcp__serena__replace_regex, mcp__serena__replace_symbol_body, mcp__context7__resolve-library-id, mcp__context7__get-library-docs
description: デバッグ支援 - エラーログ解析から原因特定・修正提案まで
---

## /debug - デバッグ支援

## フロー

1. **情報収集** - エラーログ、スタックトレース、再現手順
2. **Serena分析** - エラー箇所特定、依存関係追跡、データフロー分析
3. **根本原因特定** - 表面的でなく根本原因を見つける
4. **修正提案** - 複数案を優先順位付きで提示
5. **実装**（許可後）- 修正実装、テスト確認

## エラー種別アプローチ

| 種別 | 確認ポイント |
|------|-------------|
| 型エラー | 型定義、any/as使用箇所、型ガード |
| ランタイム | null/undefined、境界値、データ検証 |
| ロジック | 条件分岐、データフロー、期待値比較 |
| パフォーマンス | ボトルネック、N+1、メモリリーク |

## 出力フォーマット

```
🐛 Error: [エラー概要]
📍 Location: [ファイル:行]
🔍 Root Cause: [根本原因]
🔧 Solution: [推奨修正案]
```

## 次のアクション

- 原因特定済 → `/dev` で修正
- 修正完了 → `/test` で確認
- 追加調査必要 → 調査項目を提示

Serena MCP でコード分析。修正前はユーザー許可必須。
