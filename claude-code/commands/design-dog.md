---
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion, mcp__serena__*, Write, Edit
description: チーム共有用の設計資料作成 - PRD→設計に落とす、md形式でローカル保存
---

# /design-dog - Design Doc作成コマンド

`/prd` で整理した要件を、実装者・レビュワー・PMに読ませるチーム共有用の技術設計書（md）に落とし込む。

**位置付け**: `/prd`=要件定義 → `/design-dog`=設計 → `/dev`=実装 → `/docs`=Notion蓄積（完了後）

## 設計思想（Design Docの本質）

> 良いDesign Docは「賢い設計」ではなく **「意思決定が伝わる設計」** になっているか。

| 原則 | 悪い例 | 良い例 |
|------|--------|--------|
| Why を書く | 新テーブル作る | O(1)抽選のため新テーブル作る |
| 比較とトレードオフ | 案Aで実装 | 案A/B比較、Bは負荷高く不採用 |
| 変更耐性 | 今動く | 口数制限変更・配送業者追加に対応可 |
| 責務境界 | 曖昧 | order-service: 注文 / shipping-service: 配送 |
| 失敗ケース | 成功パスのみ | 在庫不足・API失敗・二重実行・冪等性 |
| 移行戦略 | テーブル差し替え | Expand→Migrate→Contract 3段 |

**レベル高い書き方**: 数字で語る（O(n)→O(1)、100req/s→1000req/s）、図で説明（シーケンス/ER/アーキ）、制約を書く（MySQL 8.0、READ COMMITTED）。

## フロー

### Step 1: 入力特定

| 条件 | 動作 |
|------|------|
| `--prd <path>` | PRD md を読込、Section 1-8 を設計の前提とする |
| 引数あり | トピックを設計対象として解釈 |
| 引数なし | `git log --oneline -10` + `git diff --stat` → AskUserQuestion で確定 |

### Step 2: ガイドライン読込（必須）

- `~/.claude/guidelines/design/clean-architecture.md`
- `~/.claude/guidelines/design/domain-driven-design.md`
- `~/.claude/guidelines/common/documentation-strategy.md`（セキュリティ・秘匿情報）
- `~/.claude/guidelines/common/user-voice.md`（対話型リライト）
- `~/.claude/rules/markdown.md`（md構造）

### Step 3: コード分析

`mcp__serena__*` で既存シンボル・依存関係把握。新規機能なら関連モジュール、リファクタなら影響範囲を特定。

### Step 4: draft 生成（12セクションテンプレ）

下記テンプレに沿って md を生成。タイプ別に重点セクションを調整（後述）。

### Step 5: AskUserQuestion で設計判断点を確認

3-5問で以下を確定:

- 代替案（Section 6）の採否と理由
- 移行戦略（Section 9）の Expand/Migrate/Contract 境界
- 未解決事項（Section 12）の優先度と判断待ち先

### Step 6: 品質ガードチェック

下記「品質ガード」の全項目を検証、不足があれば補強質問。

### Step 7: 対話型リライト

`guidelines/common/user-voice.md` 準拠。3層（Intent/Understanding/Expression）で合計9件以内。Layer 2 のユーザー回答文は draft にそのまま織り込む（AI で言い換え禁止）。

### Step 8: ファイル書き出し

- 出力先優先順位: `--out <path>` > `docs/design/` > `design/` > カレント
- ファイル名: `YYYY-MM-DD_<slug>.md`
- `--dry` 指定時はプレビューのみ、ファイル書き出しなし
- 書き出し後、後続 Notion 投稿が必要なら `/docs --update <path>` を案内

## 出力テンプレ（12セクション）

```markdown
# Design Doc: [タイトル]

## 1. Overview
- 何を実現するか（1〜2行）
- PRDリンク / 参照

## 2. Goals / Non-Goals
### Goals
- 達成すること
### Non-Goals
- 今回やらないこと（スコープ境界を明示）

## 3. Background
- 現状の問題
- なぜ変更が必要か（Why、PRDとの接続）

## 4. High-Level Design
- 全体構成（Mermaid アーキ図）
- データフロー（Mermaid シーケンス図）
- 責務境界（service/module 間の役割）

## 5. Detailed Design
### 5.1 データモデル
- テーブル設計 / ER図（Mermaid）
- インデックス・制約
### 5.2 API / Interface
- エンドポイント / 関数シグネチャ
- 入出力（型定義）
### 5.3 処理フロー
- シーケンス / 擬似コード（5行以内）

## 6. Alternatives
- 検討した別案（案A/案B/…）
- なぜ採用しなかったか（具体的理由）

## 7. Trade-offs
- 得られるもの / 失うもの
- 数字で比較（性能・コスト・複雑性）

## 8. Failure Handling
- エラーケース列挙
- リトライ方針
- 冪等性保証

## 9. Migration Plan
- Expand: 新要素追加（既存互換維持）
- Migrate: データ移行 / デュアルライト
- Contract: 旧要素削除
（DB変更なしは「該当なし」と明記）

## 10. Rollback Strategy
- 失敗時に戻せるか
- どの段階までなら無停止ロールバック可

## 11. Observability
- ログ / メトリクス / アラート

## 12. Open Questions
- 未確定事項（誰の判断待ちか明記）
- 制約・前提（MySQL 8.0, TX isolation 等）
```

## 設計タイプ（粒度調整）

| タイプ | キーワード | 重点セクション | 省略可 |
|--------|-----------|---------------|--------|
| feature | feature, 機能 | 全12（デフォルト） | なし |
| refactor | refactor, 改善 | 3/5/6/7/9を厚く | 2 |
| arch | arch, 構成, 基盤 | 4/6/7/11を厚く | 5.1/5.3 |
| adr | adr, 決定 | 3/6/7を中心 | 5/9/11 |
| db-migration | migration, DB変更 | 5.1/9/10を厚く | 4 |

## オプション

| オプション | 説明 |
|-----------|------|
| `--prd <path>` | 既存PRD md を入力として設計を派生 |
| `--out <path>` | 出力先ディレクトリ指定 |
| `--type <feature\|refactor\|arch\|adr\|db-migration>` | テンプレ粒度調整 |
| `--update <path>` | 既存 md を更新 |
| `--dry` | ファイル書き出しせずプレビューのみ |

## 品質ガード（Design Doc必達）

| チェック | 判定 |
|---------|------|
| Why（PRDとの接続）が Section 3 にある | 無ければ失格 |
| Section 6 Alternatives に最低2案比較 | 1案のみは失格 |
| Section 7 Trade-offs に数字比較 | 定性のみは要補強 |
| Section 8 に失敗ケース3件以上 | 不足なら補強 |
| DB変更時 Section 9 が Expand/Migrate/Contract 3段 | 不足なら失格 |
| 図（Mermaid）が最低1つ | 文字のみは要補強 |
| Section 12 に前提技術スタック明記 | 無ければ補強 |

**共通ガード**:
- 秘匿情報禁止（`rules/enterprise-security.md`）
- コード例5行以内
- H1 は 1ファイル 1つ（`rules/markdown.md`）
- Mermaid は ```mermaid コードブロック

## ダメなDesign Docの特徴

- なんか賢そうだけど何がしたいかわからない
- Why がない / 比較がない / 移行がない / 失敗ケースがない

→ レビューできない設計は全部ダメ。

ARGUMENTS: $ARGUMENTS
