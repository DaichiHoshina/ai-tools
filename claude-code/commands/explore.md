---
allowed-tools: Read, Glob, Grep, Bash, Task, mcp__serena__*
description: 並列探索コマンド - 複数の観点から同時調査
---

## /explore - 並列探索モード

複数の観点から同時に調査し、効率的に情報を収集する。

## 観点一覧

| ID | 観点 | 調査内容 |
|----|------|---------|
| explore1 | アーキテクチャ全体像 | ディレクトリ構造、エントリーポイント、設定ファイル |
| explore2 | Backend/API層 | ハンドラー、ビジネスロジック、データモデル |
| explore3 | Frontend/UI層 | コンポーネント構造、ルーティング、状態管理 |
| explore4 | インフラ・テスト | CI/CD、テスト構成、ビルド設定 |

## 観点選択ガイド

| 探索目的 | 選択 |
|---------|------|
| プロジェクト全体理解 | explore1-4 全て |
| API機能調査 | explore1 + explore2 |
| UI機能調査 | explore1 + explore3 |
| テスト調査 | explore1 + explore4 |
| 依存関係分析 | explore1 + explore2 + explore3 |

## 実行手順

1. **ユーザー指示から判断**: 探索範囲、目的、重点領域を特定
2. **観点選択**: 上記ガイドで対象を決定
3. **並列起動（1メッセージで全Task）**: `subagent_type: "explore-agent"` で同時呼び出し
4. **結果集約**: 観点ごとの発見事項、統合サマリー、次アクション提案

## 結果報告形式

- 各explore: ✅/❌ 実行状態 + 主要な発見
- 統合サマリー（主要コンポーネント、技術スタック、注意点）
- 次アクション → `/dev`, `/plan`, `/review`, `/refactor`, `/test`, `/diagnose`, `/docs`

## 注意事項

- **Serena MCP優先**: ファイル探索は mcp__serena__* ツール使用
- **並列実行がデフォルト**: 探索時間を最小化
- 部分的成功でも取得できた結果は報告
