---
allowed-tools: Read, Glob, Grep, Bash, Skill
description: コードレビュー用コマンド（状況に応じて適切なSkillを動的選択）
---

## /review - 包括的コードレビュー

> **新**: `comprehensive-review` スキルで品質・セキュリティ・ドキュメント/テストを統合レビュー

## 実行方法

```
/review
```

**自動実行される内容**:
```
Skill("comprehensive-review")
```

comprehensive-reviewスキルが内部で以下を実行：
1. 静的解析ツール（lint/tsc/go vet等）
2. cleanup-enforcement（未使用コード検出）
3. 専門スキル並列実行（パラメータ化対応、Phase 2-5統合）：
   - `--focus=quality`（品質全般、旧 code-quality-review）
   - `--focus=security`（セキュリティ、旧 security-error-review）
   - `--focus=docs`（ドキュメント・テスト、該当時、旧 docs-test-review）
   - uiux-review（UI変更時）

## レビュー観点

### 🎯 品質（--focus=quality）
- アーキテクチャ（依存逆転、ロジック配置）
- コード臭（長い関数、マジックナンバー）
- パフォーマンス（N+1問題、メモリリーク）
- 型安全性（any使用、無検証as）

### 🛡️ セキュリティ（--focus=security）
- OWASP Top 10（SQLインジェクション、XSS等）
- 認証・認可不備
- エラーハンドリング（エラー握りつぶし）
- 機密情報ログ

### 📝 ドキュメント・テスト（--focus=docs）
- コメント品質（公開API説明）
- テストの意味（振る舞いテスト）
- モック適切性
- カバレッジ

## 出力形式

```markdown
## 📊 包括的レビュー結果

### 実行したレビュー
- ✅ code-quality-review（品質）
- ✅ security-error-review（セキュリティ）
- ✅ docs-test-review（ドキュメント・テスト）

### 🔴 Critical（修正必須）
- [品質] Domain→Infrastructure参照
- [セキュリティ] SQLインジェクション脆弱性

### 🟡 Warning（要改善）
- [品質] 長い関数（150行）
- [セキュリティ] レート制限なし

---
📊 Total: Critical 2件 / Warning 2件
```

## 2. 選択ロジック例

### 例1: APIハンドラー修正（TypeScript）

```
変更ファイル: src/api/handlers/user.ts (100行)

選択されるSkill:
✅ code-quality-review（型安全性・アーキテクチャ・パフォーマンス統合）
✅ security-error-review（セキュリティ・エラーハンドリング統合）

実行方法: 2つのSkillを並列実行
```

### 例2: テストファイル追加（Go）

```
変更ファイル: user_service_test.go (新規)

選択されるSkill:
✅ code-quality-review（型安全性）
✅ docs-test-review（テスト品質）
```

### 例3: 大規模リファクタリング

```
変更ファイル: 20ファイル、500行以上

選択されるSkill:
✅ code-quality-review（全観点）
✅ security-error-review
✅ docs-test-review（テストがある場合）
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
