# writing/ — チーム外向け文章ガイドライン

PR・Issueコメント・Slack・Notion・DesignDoc等、**他者が読む文章** を書くときの汎用原則を集約。プロジェクト固有のテンプレ・宛先・添字規約は各プロジェクトの `CLAUDE.md` に残す。

## 責務マップ — 「どこに何を書くか」

| 層 | 責務 | 文体 | 行数目安 |
|---|---|---|---|
| `rules/` | **強制ルール** (機械可読、grep高速) | 短文・表中心 | < 30 |
| `guidelines/writing/` | **原則・手順** (中粒度、汎用化済) | 表 + 箇条書き | 30-300 |
| `references/` | **補足事例・パターン詳細** (必要時のみload) | 段落 + 詳細例 | 100-600 |

迷ったとき: rulesで禁止リスト確認 → guidelines/writing/ で原則と適用先確認 → references/ で詳細パターン参照。

## ファイル一覧

### 共通

| ファイル | 用途 | 適用タイミング |
|---|---|---|
| [PRINCIPLES.md](PRINCIPLES.md) | 共通文章原則 (4問 / 7指針 / 3変換 / 媒体別構造 / セルフチェック6) | 全ヒト向けdoc着手前 |
| [auto-knowledge-update.md](auto-knowledge-update.md) | 指摘・指示の自動追記ワークフロー | セッション中の気づき検出時 |

### 適用先別

| ファイル | 用途 | 適用タイミング |
|---|---|---|
| [commit-message.md](commit-message.md) | コミットメッセージ (抽象化 / NG/OK例) | `git commit` 前 |
| [pr-description.md](pr-description.md) | PR本文 + レビュー応答 (must/imo/nits/q) | PR作成・修正対応時 |
| [external-post.md](external-post.md) | 短文 (PRコメント / Slack / Issue / Notion) + 5軸採点 | 外部向け投稿前 |
| [long-form-doc.md](long-form-doc.md) | 長文doc (DD / PRD / RCA / Notionページ) + ADR/PRD/EARSテンプレ | 長文doc執筆時 |
| [design-doc-protocol.md](design-doc-protocol.md) | DesignDoc 4 Step + 10パターン + アンチパターン + セルフチェック18 | DD着手・レビュー対応時 |
| [strategy.md](strategy.md) | ドキュメント戦略 (6種別役割分担 / 保存先 / 命名規則 / Bounded Context) | 「どこに何を書くか」判断時 |
| [code-comment.md](code-comment.md) | コード内コメント規約 (WHY / 重要 memo / godoc / 削除 7 カテゴリ) | コメント追加・レビュー時 |
| [prompt-engineering.md](prompt-engineering.md) | AI / LLM 向け prompt writing (ヒト向けと目的逆) | Claude / GPT 等への instruction 作成時 |

### 関連 (他層)

| 場所 | ファイル | 用途 |
|---|---|---|
| `rules/` | `ai-output.md` | AI出力強制ルール (禁止リスト、超短い) |
| `rules/` | `markdown.md` | markdown構造ルール |
| `guidelines/common/` | `notion-writing.md` | Notion固有フォーマット仕様 |
| `references/` | `writing-patterns.md` | 詳細パターン (書き直しPhase 1-8 / レビュー3段 / textlint / フェーズ境界) |
| `references/` | `document-iteration-patterns.md` | 書き直しの動的パターン |
| `references/` | `review-patterns-universal.md` | 汎用レビュー指摘パターン |

## 共通原則 (要約、詳細はPRINCIPLES.md)

- **箇条書きファースト**: 散文を避け、scanできる構造に
- **構造 (場所) で束ねる**: ファイル / モジュール / レイヤー単位。抽象観点 (what/why/how) でsectionを割らない
- **section重複を排除**: 同じ事実は1ヶ所のみ
- **長さは内容に従う**: 自明は数行、設計判断含む変更は原因や代替案も
- **AI臭の禁止**: 「Generated with X」「AIが生成」等の内部用語、過剰絵文字、定型フッターを残さない

## 媒体別quick reference

| 書く対象 | 主参照 | 補足 |
|---|---|---|
| commit message | commit-message.md | PRINCIPLES.md (AI臭3変換) |
| PR本文 | pr-description.md | PRINCIPLES.md (媒体別構造 / PR description 4セクション) |
| PRコメント / Slack / Issue | external-post.md | PRINCIPLES.md (媒体別構造 / 短文PREP) |
| Design Doc | design-doc-protocol.md | long-form-doc.md (テンプレ) / PRINCIPLES.md |
| PRD | long-form-doc.md (PRD MoSCoWテンプレ) | strategy.md (保存先) |
| ADR | long-form-doc.md (ADRテンプレ) | strategy.md (命名規則) |
| RCA / Notionページ | long-form-doc.md | `common/notion-writing.md` (Notion固有) |
| 受け入れ基準 | long-form-doc.md (EARS) | PRINCIPLES.md |

## 衝突時優先順位

Notion固有仕様 > 長文doc原則 > 短文向け原則 > 共通PRINCIPLES。
プロジェクト固有CLAUDE.md > global guidelines/writing/。
