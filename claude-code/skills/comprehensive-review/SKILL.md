---
name: comprehensive-review
description: 包括的コードレビュー - 品質・セキュリティ・ドキュメント/テストを統合評価（wrapper型）
requires-guidelines:
  - common
  - typescript
---

# Comprehensive Review - 包括的コードレビュー

## 概要

3つの専門レビュースキルを統合した包括的レビューを提供します：

1. **code-quality-review** - アーキテクチャ、コード臭、パフォーマンス、型安全性
2. **security-error-review** - OWASP Top 10、エラーハンドリング、ログ管理
3. **docs-test-review** - ドキュメント品質、テスト品質、カバレッジ

## 使用タイミング

- `/review` コマンド実行時（自動選択）
- 包括的なコードレビューが必要な時

---

## 実行ロジック

### Step 1: 変更ファイル分析

```bash
git diff --name-only
```

変更内容から以下を判断：
- 言語（TypeScript/Go/その他）
- ファイル種別（テスト/API/UI/ドキュメント）
- 変更規模

### Step 2: 静的解析ツール実行（必須）

レビュー前に自動検出可能な問題を洗い出す：

```bash
# TypeScript
npm run lint 2>&1 | head -50
npx tsc --noEmit 2>&1 | head -50

# Go
golangci-lint run 2>&1 | head -50
go vet ./... 2>&1 | head -50
```

### Step 3: cleanup-enforcement 確認

`cleanup-enforcement` スキルで以下を確認：
- 未使用の import/変数/関数
- 後方互換残骸（`_deprecated_*`、旧名re-export）
- 進捗コメント（「実装した」「完了」等）

### Step 4: 専門スキル実行（並列）

**基本セット（必ず実行）**:
```
Skill("code-quality-review")    # 品質全般
Skill("security-error-review")  # セキュリティ
```

**ファイル種別による追加**:

| 条件 | 追加スキル |
|------|-----------|
| テストファイル（`*_test.*`, `*.spec.*`） | `docs-test-review` |
| ドキュメント（`README.md`, JSDoc/GoDoc変更） | `docs-test-review` |
| UIファイル（`components/*`, `*.tsx`） | `uiux-review` |

**実行方法**:
- 選択されたスキルを1メッセージで並列実行
- 4倍高速化（順次実行との比較）
- 1つが失敗しても他の結果は取得可能

### Step 5: 結果集約

```markdown
## 📊 包括的レビュー結果

### 実行したレビュー
- ✅ code-quality-review（品質）
- ✅ security-error-review（セキュリティ）
- ✅ docs-test-review（ドキュメント・テスト）

### 🔴 Critical（修正必須）
- [品質] Domain→Infrastructure参照（src/domain/user.ts:45）
- [セキュリティ] SQLインジェクション脆弱性（src/api/user.ts:120）
- [ドキュメント] 公開APIに説明なし（src/api/types.ts:30）

### 🟡 Warning（要改善）
- [品質] 長い関数（150行）（src/services/user.ts:50）
- [セキュリティ] レート制限なし（src/api/auth.ts:10）
- [テスト] 意味のないテスト（tests/user.spec.ts:25）

---
📊 **Total**: Critical 3件 / Warning 3件
```

---

## レビュー観点

### 🎯 code-quality-review（品質）

#### 🔴 Critical
- **アーキテクチャ**: 依存逆転、ロジック配置、Fat Service
- **コード臭**: 長い関数（100行超）、マジックナンバー
- **パフォーマンス**: N+1問題、メモリリーク
- **型安全性**: any使用、無検証as

#### 🟡 Warning
- 深いネスト（3階層以上）
- 非効率アルゴリズム（O(n²)）
- 冗長な型注釈

### 🛡️ security-error-review（セキュリティ）

#### 🔴 Critical
- SQLインジェクション（文字列結合）
- XSS（innerHTML直接代入）
- 認証不備（パスワード平文）
- セッション漏洩（URLにセッションID）
- エラー握りつぶし（空catch）
- 機密情報ログ（password/token出力）

#### 🟡 Warning
- セキュリティヘッダー不足（CSP/HSTS）
- レート制限なし
- リトライなし

### 📝 docs-test-review（ドキュメント・テスト）

#### 🔴 Critical
- 公開API・型に説明なし
- 嘘のコメント（実装と不一致）
- 意味のないテスト（`expect(user).toBeDefined()`のみ）
- 過剰なモック（全モックで実際の動作なし）

#### 🟡 Warning
- 自明なコメント
- テスト独立性欠如（共有状態）
- カバレッジ不足

---

## 使用例

### 例1: API実装レビュー

```
変更: src/api/handlers/user.ts (100行)

自動実行:
1. npm run lint（静的解析）
2. cleanup-enforcement（未使用コード）
3. code-quality-review（品質）
4. security-error-review（セキュリティ）

結果: Critical 2件 / Warning 5件
```

### 例2: テストファイルレビュー

```
変更: user_service_test.go（新規）

自動実行:
1. go vet（静的解析）
2. code-quality-review（型安全性）
3. docs-test-review（テスト品質）

結果: Critical 0件 / Warning 3件
```

---

## 注意事項

### 大量の差分
- 1ファイルずつレビュー
- 優先度順（Critical → Warning）

### 具体的な修正案
- 問題指摘だけでなく改善方法も提示
- コード例を含める

### 並列実行
- デフォルトで並列実行（4倍高速）
- 順次実行が必要な場合のみユーザーが明示

---

## 参照

- [code-quality-review](../code-quality-review/SKILL.md): 品質詳細
- [security-error-review](../security-error-review/SKILL.md): セキュリティ詳細
- [docs-test-review](../docs-test-review/SKILL.md): ドキュメント・テスト詳細
- [/review コマンド](../../commands/review.md): コマンド仕様
