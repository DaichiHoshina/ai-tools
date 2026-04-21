---
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, AskUserQuestion, mcp__serena__*
description: チーム共有用の設計資料作成 - PRD→設計に落とす、md形式でローカル保存
---

# /design-doc - チーム共有用の設計資料作成

`/prd` で整理した要件を、実装者・レビュワー・PMに読ませるチーム共有用の技術設計書（md）に落とし込む。

**位置付け**: `/prd`=要件定義 → `/design-doc`=設計 → `/dev`=実装 → `/docs`=Notion蓄積（完了後）

## 設計思想

> 良いDesign Docは「賢い設計」ではなく **「意思決定が伝わる設計」** になっているか。

詳細原則・テンプレ・タイプ別適用は `references/design-doc-template.md` 参照。要点:

- **Why必須**: PRDとの接続を明記
- **比較とトレードオフ**: 設計は正解でなく選択。最低2案比較
- **変更耐性**: 「今動く」でなく「変更しやすいか」
- **責務境界**: service/module 間の役割を明確化
- **失敗ケース**: 成功パスだけでなく本番で死ぬポイント列挙
- **移行戦略**: DB変更は Expand → Migrate → Contract 3段

レベル高い書き方: 数字で語る（O(n)→O(1)）、図で説明（Mermaid）、制約を書く（MySQL 8.0等）。

## フロー

| Step | 動作 |
|------|------|
| 1. 入力特定 | `--prd <path>` 優先 / 引数あり→トピック / なし→`git log/diff` + AskUserQuestion |
| 2. ガイドライン読込 | `guidelines/design/clean-architecture.md`, `domain-driven-design.md`, `references/design-doc-template.md`, `guidelines/common/user-voice.md` |
| 3. コード分析 | `mcp__serena__*` で既存シンボル・依存関係把握 |
| 4. draft 生成 | テンプレ12セクション（タイプ別調整、`references/design-doc-template.md` 準拠）。`guidelines/common/user-voice.md` の4問・原則5点を**生成時に参照**し織り込む |
| 5. 設計判断確認 | AskUserQuestion で代替案採否・移行境界・未解決事項（3-5問） |
| 6. 品質ガード | タイプ別必須項目チェック、不足は補強質問 |
| 7. 対話型リライト | `guidelines/common/user-voice.md` 準拠（合計9件以内、Layer 2 回答はそのまま織込） |
| 7.5. **writing レビュー自動実行** | `/review --focus=writing` で文章品質を検査。Critical 1件以上 or Warning 4件以上 → 指摘を修正し再レビュー（最大2 loop）|
| 8. ファイル書き出し | `--out` > `docs/design/` > `design/` > カレント、`YYYY-MM-DD_<slug>.md`。完了後のNotion取り込みは `/docs --from <path>` を案内 |

## 設計タイプ

| タイプ | キーワード | 重点 |
|--------|-----------|------|
| feature（デフォルト） | feature, 機能 | 全12セクション |
| refactor | refactor, 改善 | 3/5/6/7/9を厚く |
| arch | arch, 構成, 基盤 | 4/6/7/11を厚く |
| adr | adr, 決定 | 3/6/7中心、5/9/11省略可 |
| db-migration | migration, DB変更 | 5.1/9/10を厚く |

各タイプの詳細セクション・品質ガード適用条件は `references/design-doc-template.md`。

## オプション

| オプション | 説明 |
|-----------|------|
| `--prd <path>` | 既存PRD md を入力として設計を派生 |
| `--out <path>` | 出力先ディレクトリ指定 |
| `--type <feature\|refactor\|arch\|adr\|db-migration>` | テンプレ粒度調整 |
| `--update <path>` | 既存 md を更新 |
| `--dry` | ファイル書き出しせずプレビューのみ |

## 文章品質の担保（ガイドライン参照 + レビュー）

Draft 生成時は `guidelines/common/user-voice.md` の原則（4問・結論先行・根拠併記・難語定義・抽象語排除・プロサ繋ぎ）を参照して書く。書き終えた後、Step 7.5 で `/review --focus=writing` が自動実行され、文体違反を検出する。

検出基準と閾値は comprehensive-review の writing 観点に定義済み。Critical 1件以上、または Warning 4件以上で書き直し必須（最大2 loop）。

思考補助として冒頭に Writing Context コメントブロックを書くのは任意（強制しない）。

## 共通ガード

- 秘匿情報禁止（`rules/enterprise-security.md`）
- コード例5行以内
- H1 は 1ファイル 1つ（`rules/markdown.md`）
- Mermaid は ```mermaid コードブロック

## ダメなDesign Doc

賢そうだが何がしたいか不明 / Why なし / 比較なし / 移行なし / 失敗ケースなし → レビュー不能で全部ダメ。

ARGUMENTS: $ARGUMENTS
