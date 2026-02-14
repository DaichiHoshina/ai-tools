---
name: root-cause
description: Root Cause Analysis - 5つのなぜ分析で根本原因を特定し、構造的修正戦略を提案
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

# /root-cause - Root Cause Analysis

バグやエラーの根本原因を体系的に分析し、構造的な修正戦略を提案する。

## 実行フロー

### Step 1: 症状の記録

ユーザーから以下を収集:
- エラーメッセージ / 症状の詳細
- 再現手順（わかる範囲）
- 影響範囲（どのユーザー / 機能に影響）
- 発生頻度（常時 / 間欠的 / 特定条件）

```
symptom:
  description: "{ユーザーからの報告}"
  error_message: "{エラーメッセージ}"
  frequency: "{常時|間欠|特定条件}"
  impact: "{影響範囲}"
```

### Step 2: 5つのなぜ分析

各レベルで「なぜ？」を問い、証拠を収集する。

```
Level 1: なぜ[症状]が発生する？ → [直接原因]
  証拠: [コード箇所、ログ、設定]
  確信度: {0-100}%

Level 2: なぜ[直接原因]が起きた？ → [中間原因]
  証拠: [コード箇所、ログ、設定]
  確信度: {0-100}%

Level 3: なぜ[中間原因]が起きた？ → [深層原因]
  証拠: [コード箇所、ログ、設定]
  確信度: {0-100}%

Level 4: なぜ[深層原因]が起きた？ → [構造的原因]
  証拠: [コード箇所、ログ、設定]
  確信度: {0-100}%

Level 5: なぜ[構造的原因]が起きた？ → [根本原因]
  証拠: [コード箇所、ログ、設定]
  確信度: {0-100}%
```

**depthパラメータによる調整**:
- `quick`: Level 1-3まで（単純なバグ向け）
- `standard`: Level 1-5まで（デフォルト）
- `deep`: Level 1-5 + 類似問題の網羅的検索

**確信度**: 85%以上で信頼できる結論とする。未満の場合は追加調査を実施。

### Step 3: 根本原因の分類

| カテゴリ | 説明 | 例 | 典型的な複雑度 |
|---------|------|---|--------------|
| **Architecture** | レイヤー違反、コンポーネント欠如 | 検証層がない、依存関係の逆転 | High |
| **Logic** | アルゴリズムバグ、条件ミス | off-by-one、境界値未処理 | Medium |
| **Data** | スキーマ不一致、マイグレーション問題 | 型不一致、NULL制約漏れ | Medium-High |
| **Integration** | API契約違反、外部依存 | レスポンス形式の変更、タイムアウト | Medium |
| **Assumption** | 挙動の誤った仮定 | 順序保証なし、冪等性の欠如 | Low-Medium |
| **Environment** | 設定、インフラ | 環境変数未設定、リソース不足 | Low-Medium |

> **複雑度との対応**: カテゴリはバグの性質を表し、複雑度（Low/Medium/High）はRCA適用の判断に使用する。上記の「典型的な複雑度」は目安であり、実際は `assessBugComplexity()` のキーワードマッチで判定される。

### Step 4: 修正戦略の提案（3段階）

#### L1: 対症療法（非推奨）

```
リスク: 低
再発リスク: 高
説明: 症状を直接抑える修正
例: Number()変換を追加、null checkを追加
推奨: ❌（緊急時のみ、TODO必須）
```

#### L2: 部分的治療

```
リスク: 中
再発リスク: 中
説明: 問題の直接原因を修正するが、類似問題は残る
例: このエンドポイントに検証を追加
推奨: ⚠️（時間制約がある場合）
```

#### L3: 根本治療（推奨）

```
リスク: 高（変更範囲が広い）
再発リスク: 低
説明: 構造的な原因を取り除く
例: Zod検証層を全エンドポイントに追加
推奨: ✅（可能な限りこちらを選択）
```

各戦略のpros/cons/effort/riskを提示し、AskUserQuestionでユーザーに選択を求める。

### Step 5: 類似問題の検出

Serena MCPで同じパターンをコードベース全体から検索:

```
mcp__serena__search_for_pattern: 根本原因と同じパターンを検索
mcp__serena__find_symbol: 関連シンボルを検索
mcp__serena__find_referencing_symbols: 影響を受ける箇所を検索
```

検出結果:
- 同一パターンの発生箇所リスト
- 各箇所の影響度（高/中/低）
- 修正の優先順位

### Step 6: レポート生成

以下のフォーマットでレポートを生成し、Serena Memoryに保存:

```markdown
# Root Cause Analysis Report

## 症状
{症状の詳細}

## 5つのなぜ分析
{各レベルの分析結果}

## 根本原因
- カテゴリ: {Architecture|Logic|Data|Integration|Assumption|Environment}
- 説明: {根本原因の説明}
- 確信度: {0-100}%

## 修正戦略
### L1: 対症療法
{内容、pros/cons}

### L2: 部分的治療
{内容、pros/cons}

### L3: 根本治療（推奨）
{内容、pros/cons}

## 類似問題
{検出された類似問題のリスト}

## 推奨アクション
{具体的な修正手順}
```

```
mcp__serena__write_memory("rca-{日付}-{要約}", レポート内容)
```

## Serena MCP優先使用

すべてのコード操作でSerena MCPツールを使用:
- `mcp__serena__find_symbol` - シンボル検索
- `mcp__serena__find_referencing_symbols` - 使用箇所追跡
- `mcp__serena__search_for_pattern` - パターン検出
- `mcp__serena__read_file` - ファイル読み取り
- `mcp__serena__get_symbols_overview` - ファイル構造把握

## 出力例

```
## Root Cause Analysis: ユーザープロフィールのnullエラー

### 5つのなぜ
1. なぜnullエラー？ → user.profileがnull
2. なぜprofileがnull？ → API fetchが失敗してもデフォルト値がない
3. なぜデフォルト値がない？ → fetchResultの型がany
4. なぜ型がany？ → 境界に型検証がない
5. なぜ検証がない？ → 入力検証層の設計が欠如（根本原因）

### 根本原因: Architecture - 入力検証層の欠如
確信度: 92%

### 推奨: L3 根本治療
Zod検証層を全APIエンドポイントに追加
影響箇所: 23エンドポイント
```

---

ARGUMENTS: $ARGUMENTS
