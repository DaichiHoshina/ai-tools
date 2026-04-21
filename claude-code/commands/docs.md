---
allowed-tools: Read, Glob, Grep, Bash, mcp__serena__*, mcp__claude_ai_Notion__*
description: ナレッジ蓄積 - コード分析→Notionページ作成/更新
---

## /docs - ナレッジ蓄積コマンド

完了した作業の知識を Notion に蓄積する。プロジェクト非依存。

> **責務分離**: 設計段階の Design Doc は `/design-doc`（md、チーム共有用）。`/docs` は完了後の Notion ナレッジ蓄積。ADR / アーキテクチャ判断の設計フェーズ文書も `/design-doc` を使う。

**必読**: Notion投稿時は以下のガイドラインに従うこと:
- `guidelines/common/notion-writing.md` — 構成・見出し・文体・表記ルール（コア）
- `guidelines/common/user-voice.md` — ユーザー文体ガイド + 対話型チェック辞書
- `guidelines/common/notion-design.md` — デザインパターン
- `guidelines/common/notion-database.md` — DB設計・テンプレート
- `guidelines/common/notion-operations.md` — AI活用・権限・外部連携

## ドキュメントタイプと連携リソース

| タイプ | キーワード | 連携ガイドライン/スキル |
|--------|-----------|----------------------|
| API仕様 | api, endpoint | Skill(`api-design`) |
| 障害対応 | incident, 障害 | Skill(`incident-response`), Skill(`root-cause`) |
| レシピ | recipe, パターン, tips | `guidelines/common/documentation-strategy.md`（❌/✅形式必須） |
| 手順書 | runbook, 手順 | `guidelines/common/development-process.md` |
| 変更履歴 | changelog, 変更 | git log/diffから自動抽出 |
| 自由記述 | （上記以外） | ユーザー指示に従う |

> 設計判断（ADR）・アーキテクチャ設計は `/design-doc` で md 作成後、完了時にこのコマンドで Notion へ取り込む。

## フロー

### Step 1: 対象特定

- 引数あり → そのトピックで分析
- 引数なし → `git log --oneline -10` と `git diff --stat` から直近の変更を提示、ユーザーに選択させる
- `--from <md-path>` → 既存 md（`/design-doc` 出力等）を入力としてNotion化

### Step 2: ガイドライン読み込み

タイプに応じた連携ガイドライン/スキルを読み込む。

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

### Step 5.5: 対話型リライト（必須）

詳細・辞書・テンプレは `guidelines/common/user-voice.md` 参照。

- 事前読込: `~/.claude/projects/{project}/memory/user_vocabulary.md`（既知語スキップ）
- 3層（Intent / Understanding / Expression）を順に実行、合計9件以内
- Layer 2 のユーザー回答文は draft にそのまま織り込む（AI で言い換え禁止）
- 回答は `user_vocabulary.md` に追記

### Step 5.7: 出力前セルフチェック（必須）

`user-voice.md` 末尾の6項目を self-check。**5項目以上で合格、未達は書き直す**。

- TL;DR が冒頭1-3文にあるか（「本稿では〜」導入削除済み）
- 「必須」「推奨」「重要」に根拠1文が併記されているか
- 初出の専門用語に定義が併記されているか
- 抽象語（改善・最適化・効率化）の代わりに数字 or 事例があるか
- 読み手の次アクションが末尾に明示されているか
- 冒頭4問（読み手・ゴール・数字・なぜ）に答える内容か

### Step 6: URL出力

作成/更新したNotionページのURLを表示。

## オプション

| オプション | 説明 |
|-----------|------|
| `--parent <url>` | Notionの親ページURL指定 |
| `--update <url>` | 既存 Notion ページを更新（URL指定） |
| `--from <md-path>` | ローカル md（`/design-doc` 出力等）を入力としてNotion化 |
| `--dry` | Notion投稿せずプレビューのみ |

## 品質ガード

- **秘匿情報禁止**: APIキー、パスワード、実URLはプレースホルダーに置換（`guidelines/common/documentation-strategy.md` セキュリティ節準拠）
- **コード例**: 5行以内（documentation-strategy.md ルール）
- **投稿前確認**: ユーザーにプレビューを見せて承認を得る
- **Mermaid図**: Notionのコードブロック（mermaid指定）で記述

ARGUMENTS: $ARGUMENTS
