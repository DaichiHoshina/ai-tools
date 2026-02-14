---
allowed-tools: Read, Glob, Grep, Bash, Skill, AskUserQuestion, mcp__serena__*
description: コードレビュー用コマンド（comprehensive-reviewスキルで5観点統合レビュー）
---

## /review - 包括的コードレビュー

> comprehensive-reviewスキルで設計・品質・可読性・セキュリティ・ドキュメント/テストを統合レビュー

## 実行方法

```bash
/review                # ローカル差分をレビュー（git diff）
/review <url>          # MR/PR URLの差分をレビュー（= /mr-review）
/review <number>       # 現在リポジトリのMR/PR番号でレビュー
/review --focus=security  # 観点を絞ってレビュー
```

### 引数ルーティング

| 引数 | 動作 |
|------|------|
| なし | `git diff` のローカル差分をレビュー |
| URL（http...） | `gh pr diff` / `glab mr diff` で差分取得→レビュー |
| 番号 | 現在リポジトリのMR/PR番号として差分取得→レビュー |
| `--focus=<観点>` | 指定観点のみレビュー |

**自動実行される内容**:

```
Skill("comprehensive-review")
```

comprehensive-reviewスキルが内部で以下を実行：

1. 静的解析ツール（lint/tsc/go vet等）
2. cleanup-enforcement（未使用コード検出）
3. 5観点の統合レビュー（`--focus`で絞り込み可能）：
   - `--focus=architecture`（設計 — CA/DDD/依存関係）
   - `--focus=quality`（品質 — 型安全性・パフォーマンス・古いパターン）
   - `--focus=readability`（可読性 — 命名・構造・認知的複雑度）
   - `--focus=security`（セキュリティ — OWASP Top 10・エラーハンドリング）
   - `--focus=docs`（ドキュメント・テスト — 該当時）
4. uiux-review（UI変更時、別スキル）

## レビュー観点

### 🏗️ 設計（--focus=architecture）

- レイヤー違反（Domain→Infrastructure参照）
- 依存方向の逆転不備（DI未使用）
- 貧血ドメインモデル（getter/setterのみ）
- 集約境界違反

### 🎯 品質（--focus=quality）

- 型安全性（any使用、無検証as）
- パフォーマンス（N+1問題、メモリリーク）
- 古いパターン（言語別ガイドラインの検出テーブル参照）
- コード臭（長い関数、マジックナンバー）

### 📖 可読性（--focus=readability）

- 誤解を招く命名（名前と振る舞いの不一致）
- 認知的複雑度（深いネスト、長い条件式）
- 関数の長さ・引数（50行超、4引数超）
- 構造の明瞭さ（ガード節未使用、否定条件の連鎖）

### 🛡️ セキュリティ（--focus=security）

- OWASP Top 10（SQLインジェクション、XSS等）
- 認証・認可不備
- エラー握りつぶし（空catch）
- 機密情報ログ出力

### 📝 ドキュメント・テスト（--focus=docs）

- 公開APIのドキュメント不足
- テストの意味（振る舞いテスト）
- 過剰なモック
- カバレッジ不足

## 出力形式

```markdown
## 包括的レビュー結果

### 実行した観点
- ✅ architecture（設計）
- ✅ quality（品質）
- ✅ readability（可読性）
- ✅ security（セキュリティ）
- ✅ docs（ドキュメント・テスト）

### 🔴 Critical（修正必須）
- [設計] Domain→Infrastructure参照（src/domain/user.ts:45）
- [セキュリティ] SQLインジェクション脆弱性（src/api/user.ts:120）
- [可読性] 関数名と振る舞いの不一致（src/services/user.ts:30）

### 🟡 Warning（要改善）
- [品質] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）
- [可読性] ネスト4階層（src/handlers/order.go:80）

Total: Critical 3件 / Warning 2件
```

## レビュー対象

### 含める

- 変更されたファイル（git diff）
- 新規追加ファイル

### 除外

- auto-generatedファイル
- vendor/node_modules
- lockファイル

## 注意事項

- **大量の差分**: 1ファイルずつレビュー
- **優先度**: Critical → Warning の順で報告
- **具体的な修正案**: 問題指摘だけでなく改善方法も提示
- **並列実行がデフォルト**: 全5観点を並列で実行
