---
allowed-tools: Read, Glob, Grep, Bash, mcp__serena__*, mcp__claude_ai_Notion__*
description: ナレッジ蓄積 - コード分析→Notionページ作成/更新
---

## /docs - ナレッジ蓄積コマンド

コードベースから知識を抽出し、Notionに蓄積する。プロジェクト非依存。

**必読**: Notion投稿時は以下のガイドラインに従うこと:
- `guidelines/common/notion-writing.md` — 構成・見出し・文体・表記ルール（コア）
- `guidelines/common/notion-design.md` — デザインパターン
- `guidelines/common/notion-database.md` — DB設計・テンプレート
- `guidelines/common/notion-operations.md` — AI活用・権限・外部連携

## ドキュメントタイプと連携リソース

| タイプ | キーワード | 連携ガイドライン/スキル |
|--------|-----------|----------------------|
| 設計判断 | adr, 設計, why | `guidelines/design/clean-architecture.md`, `guidelines/design/domain-driven-design.md` |
| API仕様 | api, endpoint | Skill(`api-design`) |
| アーキテクチャ | arch, 構成 | Skill(`clean-architecture-ddd`), `guidelines/common/code-quality-design.md` |
| 障害対応 | incident, 障害 | Skill(`incident-response`), Skill(`root-cause`) |
| レシピ | recipe, パターン, tips | `guidelines/common/documentation-strategy.md`（❌/✅形式必須） |
| 手順書 | runbook, 手順 | `guidelines/common/development-process.md` |
| 変更履歴 | changelog, 変更 | git log/diffから自動抽出 |
| 自由記述 | （上記以外） | ユーザー指示に従う |

## フロー

### Step 1: 対象特定

- 引数あり → そのトピックで分析
- 引数なし → `git log --oneline -10` と `git diff --stat` から直近の変更を提示、ユーザーに選択させる

### Step 2: ガイドライン読み込み

タイプに応じた連携ガイドライン/スキルを読み込む。

- **設計判断**: clean-architecture.md, domain-driven-design.md を読み、設計原則に照らして判断理由を記述
- **障害対応**: incident-responseスキルのフォーマット（分類→影響範囲→原因→再発防止）に準拠
- **レシピ**: documentation-strategy.md の❌/✅形式を**必ず**使用。コード例5行以内、テーブル優先
- **API仕様**: api-designスキルのエンドポイント記述規約に準拠

### Step 3: コード分析

```
git log / git diff → 変更内容把握
Grep / Read → 関連コード読解
```

抽出する情報:
- **What**: 何が変わったか（差分サマリー）
- **Why**: なぜ変えたか（コミットメッセージ、PR説明）
- **How**: どう実装したか（主要ロジック）
- **Impact**: 影響範囲（依存先、利用箇所）
- **Caveat**: 注意点・既知の制約

### Step 4: Notion検索

`notion-search` で既存の関連ページを検索。

- 関連ページあり → 更新するか新規作成か確認
- なし → 新規作成

### Step 5: Notionページ作成/更新

`notion-create-pages` または `notion-update-page` で投稿。

タイプ別テンプレート:

**設計判断（ADR）**:
```
## ステータス: 承認済み
## コンテキスト: 何が問題だったか
## 決定: 何を選んだか
## 代替案: 他に何を検討したか
## 結果: この決定による影響
```

**障害対応**:
```
## 概要: 1行サマリー
## タイムライン: 発生→検知→対応→復旧
## 根本原因: 5 Whys分析
## 影響範囲: ユーザー/システムへの影響
## 再発防止: 具体的アクション
```

**レシピ**:
```
## パターン名
| ❌ 避ける | ✅ 使う | 理由 |
|----------|---------|------|
| 悪い例 | 良い例 | 1行 |
**Why**: 背景説明（1行）
```

**共通フッター**（全タイプ）:
```
## 参考
- リポジトリ: {repo}
- コミット: {hash}
- PR: {url}（あれば）
- 作成日: {date}
```

### Step 6: URL出力

作成/更新したNotionページのURLを表示。

## オプション

| オプション | 説明 |
|-----------|------|
| `--parent <url>` | Notionの親ページURL指定 |
| `--update <url>` | 既存ページを更新 |
| `--dry` | Notion投稿せずプレビューのみ |

## 品質ガード

- **秘匿情報禁止**: APIキー、パスワード、実URLはプレースホルダーに置換（`guidelines/common/documentation-strategy.md` セキュリティ節準拠）
- **コード例**: 5行以内（documentation-strategy.md ルール）
- **投稿前確認**: ユーザーにプレビューを見せて承認を得る
- **Mermaid図**: Notionのコードブロック（mermaid指定）で記述

ARGUMENTS: $ARGUMENTS
