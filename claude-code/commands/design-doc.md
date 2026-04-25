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

## 入力解釈（ARGUMENTS から自動分岐）

明示オプション（`--prd` `--update` `--out` `--type` `--dry` `--scope`）の他、自然言語からモードを推定。

| 検出 | 条件 | 効果 |
|------|------|------|
| update モード | 「修正/直して/更新/アップデート/書き直し/リライト/変更」+ `.md` パス | `--update <path>` 相当 |
| scope 限定 | scope キーワード辞書（下表）を ARGUMENTS から検索 | 該当 Q のみ Step 4・6 で再評価 |
| 派生モード | 「PRD 〜から」「〜を踏まえて」+ PRD `.md` パス | `--prd <path>` 相当 |
| 新規モード | 上記なし | 通常フロー（Step 1 から） |

**scope キーワード辞書**（`/prd` と共通）: Q1=目的/Why, Q2=やらない/Null, Q3=代替/比較, Q4=失敗/プレモータム, Q5=前提/崩れる/もし

**曖昧時**:
- 修正キーワードあり・パスなし → `Glob "**/design/*.md"` `**/docs/design/*.md"` で候補提示し AskUserQuestion
- パスあり・修正キーワードなし → AskUserQuestion で「PRD として参照（`--prd`） / Design Doc 修正（`--update`） / 新規」確認

update モード時の Step 4 は **既存 Q1-Q5 セクションを Read → 差分のみ Edit**。`--scope` 指定時は該当 Q のみ書き直し loop。

## Q1-Q5 継承ルール（`/prd` との重複回避）

`/prd` で既に Q1-Q5 が確定している場合、Design Doc は **再評価せず継承** する。

| 起動パターン | Q1-Q5 の扱い |
|------------|------------|
| `/design-doc --prd <path>` | PRD の「1.5 意思決定根拠」を Read → **転記し、再評価スキップ**。設計起因で前提が変わる場合のみ追記 |
| `/design-doc`（PRD なし、新規） | Q1-Q5 を Step 4 で実施（必須セクション化） |
| `/design-doc --update <path>` | 既存 doc の Q1-Q5 を読込 → 差分のみ Edit |
| `--scope Q1,Q3` 明示時 | 上記いずれでも該当 Q のみ再評価（継承を上書き） |

**継承時の注記**: Design Doc の「1.5 意思決定根拠」セクションには `Source: <PRD path>` を明記し、再評価が必要な Q のみインライン追記する。Step 6 の品質ガードは継承元の充足を信頼し、転記済かのみ確認する。

## フロー

| Step | 動作 |
|------|------|
| 1. 入力特定 | `--prd <path>` 優先 / 引数あり→トピック / なし→`git log/diff` + AskUserQuestion |
| 2. ガイドライン読込 | `guidelines/design/clean-architecture.md`, `domain-driven-design.md`, `references/design-doc-template.md`, `references/decision-quality-checklist.md`, `guidelines/common/user-voice.md` |
| 3. コード分析 | `mcp__serena__*` で既存シンボル・依存関係把握 |
| 4. draft 生成 | テンプレ12セクション（タイプ別調整、`references/design-doc-template.md` 準拠）。`guidelines/common/user-voice.md` の4問・原則5点を**生成時に参照**し織り込む。**Q1-Q5 の取扱は下記「Q1-Q5 継承ルール」参照** |
| 5. 設計判断確認 | AskUserQuestion で代替案採否・移行境界・未解決事項（3-5問） |
| 6. 品質ガード | タイプ別必須項目チェック、**Q1-Q5 充足検査**（継承時は転記済か確認、再評価時は NG パターン該当を Critical）、不足は補強質問 or `Edit` で書き直し（最大2 loop） |
| 7. 対話型リライト | `guidelines/common/user-voice.md` 準拠（合計9件以内、Layer 2 回答はそのまま織込） |
| 8. ファイル書き出し | `--out` > `docs/design/` > `design/` > カレント、`YYYY-MM-DD_<slug>.md`。`--dry` 時は書き出さず次ステップで stdin として扱う |
| 8.5. **writing 検査（ファイル対象）** | 書き出した md を `Read` して内容を取得。`guidelines/common/user-voice.md` の NG 辞書と `skills/comprehensive-review/SKILL.md` の writing 観点 NG 表で違反を数える。Critical 1件以上 or Warning 4件以上 → `Edit` で書き直し、最大2 loop。最終結果をユーザーに出力 |
| 9. Notion 取り込み案内 | 完了後、必要なら `/docs --from <path>` を案内 |

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
| `--update <path>` | 既存 md を更新（既存 Q1-Q5 を Read→差分のみ Edit） |
| `--scope Q1,Q3` | Q1-Q5 のうち指定 Q のみ再評価（部分修正用、自然語からも自動推定） |
| `--dry` | ファイル書き出しせずプレビューのみ |

## 文章品質の担保（ガイドライン参照 + 書き出し後レビュー）

Draft 生成時は `guidelines/common/user-voice.md` の原則（4問・結論先行・根拠併記・難語定義・抽象語排除・プロサ繋ぎ）を参照して書く。

**書き出し後のレビュー（Step 8.5）**: ファイルに書き出した後、`Read` で内容を取り、`skills/comprehensive-review/SKILL.md` の writing 観点 NG 表（根拠なき評価語・抽象語放置・難語未定義 等）と `guidelines/common/user-voice.md` の NG 辞書でヒット件数を数える。`/review --focus=writing` は git diff ベースなので、書き出し直後の新規ファイルを安定して検査するため、ここでは **Read + AI 自身による NG 判定** を使う。

- Critical 1件以上、または Warning 4件以上 → `Edit` で書き直し、再検査（最大2 loop）
- `--dry` モードでは書き出さず、生成した draft text を直接対象にして同じ検査を行う

思考補助として冒頭に Writing Context コメントブロックを書くのは任意（強制しない）。

## 共通ガード

- 秘匿情報禁止（`rules/enterprise-security.md`）
- コード例5行以内
- H1 は 1ファイル 1つ（`rules/markdown.md`）
- Mermaid は ```mermaid コードブロック

## ダメなDesign Doc

賢そうだが何がしたいか不明 / Why なし / 比較なし / 移行なし / 失敗ケースなし → レビュー不能で全部ダメ。

ARGUMENTS: $ARGUMENTS
