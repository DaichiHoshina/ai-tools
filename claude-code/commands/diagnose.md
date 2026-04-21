---
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, TaskCreate, TaskUpdate, TaskList, TaskGet, mcp__serena__*, mcp__context7__*
description: デバッグ支援 - エラーログ解析から原因特定・修正提案まで
---

## /diagnose - デバッグ支援

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
| パフォーマンス | ボトルネック、N+1、メモリリーク → 計測改善フローは `/performance-issue` |
| Docker関連 | `docker-troubleshoot` + `dockerfile-best-practices` |

## Docker関連エラー検出時

Dockerに関連するエラーの場合、以下のスキルを適用:

1. **docker-troubleshoot** - lima/Docker Desktop接続エラー、daemonの状態診断・修復
2. **dockerfile-best-practices** - Dockerfileの改善（マルチステージビルド、キャッシュ最適化、セキュリティ強化）

## 出力フォーマット

```
🐛 Error: [エラー概要]
📍 Location: [ファイル:行]
🔍 Root Cause: [根本原因]
🔧 Solution: [推奨修正案]
```

## 長文レポート出力時のヒト向け執筆ルール

調査レポートや RCA 報告を Notion / md に残すとき、`guidelines/common/user-voice.md` の原則を適用する:

- 冒頭1-3文で結論（「X が原因。Y の変更で解決済み / 解決案」）
- 「必須」「推奨」「重要」には根拠1文併記
- 抽象語（「大幅に改善」「最適化」）の代わりに数字（「5xx が 120件/日 → 8件/日」）
- 末尾にレビュワー or on-call の次アクションを明示

## 次のアクション

- 原因特定済 → `/dev` で修正
- 修正完了 → `/test` で確認
- 追加調査必要 → 調査項目を提示

Serena MCP でコード分析。修正前はユーザー許可必須。
