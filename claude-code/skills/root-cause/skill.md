---
name: root-cause
description: Root Cause Analysis - 5つのなぜ分析で根本原因を特定し、構造的修正戦略を提案。バグの根本原因分析、再発防止、構造的修正が必要な時に使用。
allowed-tools: Read, Glob, Grep, Bash, Task, AskUserQuestion, mcp__serena__*
model: sonnet
requires-guidelines:
  - common
  - clean-architecture
parameters:
  depth:
    type: enum
    values: [quick, standard, deep]
    default: standard
  focus:
    type: enum
    values: [all, architecture, logic, data, integration, assumption, environment]
    default: all
---

# root-cause - Root Cause Analysis

バグやエラーの根本原因を体系的に分析し、構造的な修正戦略を提案する。

## 実行フロー

### Step 1: 症状の記録

ユーザーから収集: エラーメッセージ、再現手順、影響範囲、発生頻度

### Step 2: 5つのなぜ分析

各レベルで「なぜ?」を問い、証拠を収集する。

詳細テンプレート: [references/analysis-framework.md](references/analysis-framework.md)

### Step 3: 根本原因の分類

| カテゴリ | 説明 | 典型的な複雑度 |
|---------|------|--------------|
| **Architecture** | レイヤー違反、コンポーネント欠如 | High |
| **Logic** | アルゴリズムバグ、条件ミス | Medium |
| **Data** | スキーマ不一致、マイグレーション問題 | Medium-High |
| **Integration** | API契約違反、外部依存 | Medium |
| **Assumption** | 挙動の誤った仮定 | Low-Medium |
| **Environment** | 設定、インフラ | Low-Medium |

### Step 4: 修正戦略の提案

| 戦略 | 再発リスク | 推奨 |
|------|-----------|------|
| L1: 対症療法 | 高 | 緊急時のみ |
| L2: 部分的治療 | 中 | 時間制約時 |
| L3: 根本治療 | 低 | 推奨 |

詳細: [references/analysis-framework.md](references/analysis-framework.md)

### Step 5: 類似問題の検出

Serena MCPで同じパターンをコードベース全体から検索。

### Step 6: レポート生成

Serena Memoryに保存: `mcp__serena__write_memory("rca-{日付}-{要約}", レポート内容)`

## Serena MCP優先使用

- `mcp__serena__find_symbol` - シンボル検索
- `mcp__serena__find_referencing_symbols` - 使用箇所追跡
- `mcp__serena__search_for_pattern` - パターン検出
- `mcp__serena__get_symbols_overview` - ファイル構造把握

## 出力例

```text
## Root Cause Analysis: ユーザープロフィールのnullエラー

### 5つのなぜ
1. なぜnullエラー? → user.profileがnull
2. なぜprofileがnull? → API fetchが失敗してもデフォルト値がない
3. なぜデフォルト値がない? → fetchResultの型がany
4. なぜ型がany? → 境界に型検証がない
5. なぜ検証がない? → 入力検証層の設計が欠如（根本原因）

### 根本原因: Architecture - 入力検証層の欠如
確信度: 92%

### 推奨: L3 根本治療
Zod検証層を全APIエンドポイントに追加
影響箇所: 23エンドポイント
```

ARGUMENTS: $ARGUMENTS
