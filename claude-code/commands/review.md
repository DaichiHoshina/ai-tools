---
allowed-tools: Read, Glob, Grep, Bash, Skill, AskUserQuestion, mcp__serena__*
description: コードレビュー用コマンド（comprehensive-reviewスキルで7観点統合レビュー）
---

## /review - 包括的コードレビュー

> comprehensive-reviewスキルで設計・品質・可読性・セキュリティ・ドキュメント/テスト・恒久対応・ログを統合レビュー

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

1. ガイドライン読み込み（load-guidelines）
2. 静的解析ツール（lint/tsc/go vet等）
3. cleanup-enforcement（未使用コード検出）
4. 7観点の統合レビュー（`--focus`で絞り込み可能）：
   - `--focus=architecture`（設計 — CA/DDD/依存関係）
   - `--focus=quality`（品質 — 型安全性・パフォーマンス・古いパターン）
   - `--focus=readability`（可読性 — 命名・構造・認知的複雑度）
   - `--focus=security`（セキュリティ — OWASP Top 10・エラーハンドリング）
   - `--focus=docs`（ドキュメント・テスト — 該当時）
   - `--focus=root-cause`（恒久対応 — 対症療法vs根本治療・パターン再発）
   - `--focus=logging`（ログ — レベル適切性・構造化・可観測性・機密保護）
5. uiux-review（UI変更時、別スキル）

> 各観点の詳細チェック項目は `comprehensive-review` スキル（`skills/comprehensive-review/SKILL.md`）を参照。

## 出力形式

```markdown
## 包括的レビュー結果

### 実行した観点
✅ architecture / ✅ quality / ✅ readability / ✅ security / ✅ docs / ✅ root-cause / ✅ logging

### 🔴 Critical（修正必須）
- [設計] Domain→Infrastructure参照（src/domain/user.ts:45）
- [セキュリティ] SQLインジェクション脆弱性（src/api/user.ts:120）

### 🟡 Warning（要改善）
- [品質] 古いパターン: sort.Slice → slices.Sort（pkg/sort.go:15）

Total: Critical 2件 / Warning 1件
```

## レビュー対象

含める: 変更ファイル（git diff）、新規追加ファイル
除外: auto-generated、vendor/node_modules、lockファイル

## 注意事項

- **大量の差分**: 1ファイルずつレビュー
- **優先度**: Critical → Warning の順で報告
- **具体的な修正案**: 問題指摘だけでなく改善方法も提示
- **並列実行がデフォルト**: 全7観点を並列で実行
