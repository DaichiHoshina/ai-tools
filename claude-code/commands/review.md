---
allowed-tools: Read, Glob, Grep, Bash, Skill
description: コードレビュー用コマンド（状況に応じて適切なSkillを動的選択）
---

## /review - 動的Skill選択型コードレビュー

> **重要**: ファイル種別・言語・変更内容に応じて適切なSkillを自動選択

## 1. レビュー手順

### Step 1: 変更ファイル取得
```bash
git diff --name-only
```

### Step 2: 静的解析ツール実行（必須）

レビュー前に静的解析を実行し、自動検出可能な問題を先に洗い出す:

```bash
# TypeScript
npm run lint 2>&1 | head -50
npx tsc --noEmit 2>&1 | head -50

# Go
golangci-lint run 2>&1 | head -50
go vet ./... 2>&1 | head -50

# Python
ruff check . 2>&1 | head -50
mypy . 2>&1 | head -50
```

**静的解析でエラーがある場合:**
- 先に修正を提案（Skill実行前）
- 軽微なものは自動修正可能: `npm run lint -- --fix`, `ruff check --fix`

### Step 3: cleanup-enforcement 確認

`cleanup-enforcement` Skill を適用し、以下を確認:
- 未使用の import/変数/関数
- 後方互換残骸（`_deprecated_*`, 旧名re-export）
- 進捗コメント（「実装した」「完了」等）

### Step 4: コンテキスト分析

変更ファイルから以下を判断：
- 言語（TypeScript/Go/その他）
- ファイル種別（テスト/API/インフラ/ドキュメント）
- 変更規模（小/中/大）

### Step 5: Skill 動的選択

#### 🔹 基本セット（必ず実行）
- **type-safety-review**: TypeScript/Go の場合
- **security-review**: 全ての場合
- **architecture-review**: 中〜大規模変更の場合

#### 🔹 ファイル種別による追加

| ファイル種別 | 追加Skill |
|-------------|----------|
| `*_test.{ts,go}`, `*.test.ts`, `*.spec.ts` | test-quality-review |
| `handler/*`, `controller/*`, `api/*` | error-handling-review |
| `README.md`, JSDoc/GoDoc 変更 | documentation-review |

#### 🔹 変更内容による追加

| 変更内容 | 追加Skill |
|---------|----------|
| 50行以上の関数追加・修正 | code-smell-review |
| DB クエリ追加・修正 | performance-review |
| ループ・アルゴリズム修正 | performance-review |
| リファクタリング | code-smell-review + performance-review |

### Step 6: ガイドライン自動読み込み

選択されたSkillの`requires-guidelines`を確認し、未読み込みのガイドラインがあれば読み込む：

| Skill | requires-guidelines |
|-------|---------------------|
| type-safety-review | typescript, common |
| security-review | common |
| architecture-review | common |
| performance-review | common |
| error-handling-review | common |
| test-quality-review | common |
| code-smell-review | common |
| documentation-review | common |

**読み込み処理**:
- セッション内で既読のガイドラインはスキップ
- 未読のガイドラインのみ読み込み（トークン節約）

### Step 7: Skill実行（並列）

選択されたSkillを**1メッセージで同時に**実行：

- 並列実行により大幅な時間短縮（4倍高速）
- 1つのSkillが失敗しても他の結果は取得可能
- エラー時は部分的成功として報告

**順次実行**: ユーザーが明示的に指定した場合のみ

### Step 8: 結果集約

実行されたSkillの結果をまとめて報告。成功/失敗の状態を明示：

```
## レビュー結果

### 実行したレビュー
- ✅ type-safety-review（成功）
- ✅ security-review（成功）
- ❌ architecture-review（エラー: タイムアウト）
- ✅ performance-review（成功）

### 🔒 型安全性
🔴 Critical: X件
🟡 Warning: Y件

### 🛡️ セキュリティ
🔴 Critical: X件
🟡 Warning: Y件

### 🏗️ アーキテクチャ
❌ レビュー失敗: [エラーメッセージ]
💡 再実行提案: `/review` を再度実行するか、個別に `architecture-review` Skillを実行してください

### 📊 パフォーマンス
🔴 Critical: X件
🟡 Warning: Y件

---
📊 Total: Critical X件 / Warning Y件（architecture-review除く）
⚠️ 1件のレビューが失敗しました
```

**部分的成功時の対応:**
- 成功したSkillの結果は通常通り表示
- 失敗したSkillについては理由を記載
- 再実行または個別Skill実行を提案

## 2. 選択ロジック例

### 例1: APIハンドラー修正（TypeScript）- 並列実行

```
変更ファイル: src/api/handlers/user.ts (100行)

選択されるSkill:
✅ type-safety-review（TypeScript）
✅ security-review（基本）
✅ architecture-review（中規模変更）
✅ error-handling-review（APIハンドラー）

実行方法: 4つのSkillを並列実行（同時呼び出し）
実行時間: 約30秒（順次実行なら約2分）
```

### 例2: テストファイル追加（Go）

```
変更ファイル: user_service_test.go (新規)

選択されるSkill:
✅ type-safety-review（Go）
✅ test-quality-review（テストファイル）
```

### 例3: 大規模リファクタリング

```
変更ファイル: 20ファイル、500行以上

選択されるSkill:
✅ type-safety-review
✅ security-review
✅ architecture-review
✅ performance-review
✅ code-smell-review
```

## 3. レビュー対象

### 含める
- 変更されたファイル（git diff）
- 新規追加ファイル

### 除外
- auto-generated ファイル
- vendor/node_modules
- lock ファイル

## 4. 注意事項

- **大量の差分**: 1ファイルずつレビュー
- **優先度**: Critical → Warning の順で報告
- **具体的な修正案**: 問題指摘だけでなく改善方法も提示
- **Skill選択理由**: どのSkillをなぜ選んだか説明
- **並列実行がデフォルト**: 順次実行が必要な場合のみユーザーが明示的に指定
