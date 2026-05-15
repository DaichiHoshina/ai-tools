# ドキュメント戦略 (種別・保存先・体系)

ドキュメント種別の役割分担・関係性・保存先・体系原則。`/docs` / `/design-doc` / `/prd` 等の保存先判断時に参照。

> 本ファイルは「**どこに何を書くか**」の判断ガイド。**どう書くか** (執筆原則) は [PRINCIPLES.md](PRINCIPLES.md) / [long-form-doc.md](long-form-doc.md) / [design-doc-protocol.md](design-doc-protocol.md) 参照。

## 6 種別の役割分担

| 種別 | 答える問い | 時制 | Owner |
|------|-----------|------|-------|
| **PRD** (Product Requirements) | 何を作るか / Why now | 着手前 | PdM |
| **ADR** (Architecture Decision Record) | なぜこの技術判断にしたか (構造・非機能・技術選定) | 判断時 | Tech Lead |
| **Design Doc** | どう実装するか | 実装前 | Developer |
| **Project Docs** | いつ誰がどう進めるか | 進行中 | PjM |
| **Product Spec** | 実際に何が作られたか | リリース後 | PdM |
| **Technical Spec** | 現在の技術仕様 | 継続更新 | Developer |

## どこに書くか判断フロー

```text
書きたい内容は...
├─ ビジネス価値・要件 → PRD (未リリース) or Product Spec (リリース済み)
├─ 技術選定の理由 → ADR (1 決定 = 1 ファイル、不可逆)
├─ 実装設計 → Design Doc (実装前、レビュー後 merge)
├─ 現行の仕様 → Technical Spec (実装変更に追従)
├─ 進行管理 → Project Docs (スコープ・スケジュール・リスク等)
├─ 繰り返す運用手順 → Runbook (Wiki/Notion)
└─ 開発 Tips・ハマりポイント → Tips (Wiki/Notion)
```

## ドキュメント間の関係性

```text
PRD (何を)
  ↓ 技術判断が必要
ADR (なぜ)
  ↓ 実装方針を決める
Design Doc (どう)
  ↓ 実装→リリース
Product Spec (実際に作られたもの)
Technical Spec (現時点の仕様スナップショット)
```

- **PRD と ADR は独立**: PRD は「何を作るか」、ADR は「技術判断の記録」。PRD 内で技術判断を書かない
- **Design Doc は PRD にリンク**: 必ず PRD/Issue リンクを貼る。Why が PRD 側にあるため
- **Product Spec はリリース後に PRD から派生**: PRD 時点の想定 vs 実装結果の差分を埋める

## 保存先

| 種別 | 保存先 | 理由 |
|------|--------|------|
| PRD / ADR / Design Doc / Product Spec / Technical Spec | GitHub (リポジトリ内) | コードと一緒にバージョン管理 |
| Runbook / 開発 Tips | Wiki / Notion | 検索・更新が容易 |

## Bounded Context による分割

DDD のドメイン境界でディレクトリを切る。混ぜると保守性が崩れる。

```text
docs/
├── <DocType>/
│   ├── general/          # プロジェクト横断・共通
│   └── <context_name>/   # 各ドメインコンテキスト
```

**判定**: このドキュメントは「1 つのドメイン内で完結するか」。
- Yes → `<context_name>/` 配下
- No (2+ ドメインにまたがる) → `general/` 配下

コンテキスト名が決まらない = ドメイン設計が未成熟のシグナル。先にドメイン整理。

## 命名規則

| 種別 | 形式 | 理由 |
|------|------|------|
| PRD | `YYYY-MM-DD-feature-[name].md` | 時系列で並ぶ、意思決定時点が明確 |
| ADR | `NNNN-[decision-title].md` (seq 番号) | 順序が履歴、後で挿入禁止 |
| Design Doc | `[feature-name].md` or `YYYY-MM-DD-[name].md` | Feature 単位で検索しやすい |
| Product Spec | `feature-[name].md` | PRD の日付と切り離す (仕様は継続更新) |

**原則**: ファイル名で **時系列性 or ID 性 or 検索性** のどれを重視するか決める。混在させない。

## テンプレート駆動

各種別ディレクトリに `template.md` を置き、新規作成時は必ずコピーして使う。

**Why**: 書く人によって構造がバラつくと、レビュワーが毎回読み方を学習し直す必要がある。テンプレ固定でレビュー観点が揃い、読み込みコストが下がる。

**テンプレ必須セクション**:
- **PRD**: 背景 / ゴール / スコープ / 成功指標 / 非スコープ / オープン質問 — [long-form-doc.md PRD MoSCoW テンプレ](long-form-doc.md#prd-moscow-テンプレ-mustshouldcouldwont) 参照
- **ADR**: Context / Decision / Consequences / Alternatives — [long-form-doc.md ADR テンプレ](long-form-doc.md#adr-テンプレ-1-テーマ-1-decision) 参照
- **Design Doc**: 12 セクション or 軽量 5 節 — [design-doc-protocol.md テンプレ選択](design-doc-protocol.md#テンプレ選択) 参照

## レビュープロセス

設計系ドキュメント (PRD / ADR / Design Doc) は **観点を分けた複数レビュワー** を立てる。最低限「技術的妥当性」と「要件・UX との整合」の 2 観点。

**Why**: 設計は選択であり、1 人の視点だと見落としが出る。観点を分けることで死角を減らす。人数・役職は組織構成に合わせて調整してよい。

**Merge 条件** (組織で固定する例):

- 必要な観点のレビュワー全員の Approve
- オープン質問がクローズされているか、別 Issue 化されている
- テンプレ必須セクションが埋まっている (空欄なら理由明記)

## AI 対応ドキュメントルール (RAG 検索精度)

embedding 生成・AI 検索の品質に直結する構造化ルール。

### ページ構成

| ルール | 基準 |
|--------|------|
| 1 ナレッジ = 1 ドキュメント | 1 ページに「1 つの問い + 1 つの答え」のみ |
| 文量 | 800-1500 字 / ページ目安。2000 字超なら分割 |
| 見出し階層 | H1-H3 まで。H4 が必要なら内容が複雑すぎるため分割 |

### 文体・表現

(詳細は [PRINCIPLES.md](PRINCIPLES.md) + [long-form-doc.md NG 辞書](long-form-doc.md#ng-辞書-長文向け詳細版) 参照)

| ルール | 詳細 |
|--------|------|
| 主語明示 | 「担当者は〜」「ユーザーは〜」必ず記述 |
| 指示語禁止 | 「これ」「それ」「上記」「前述」→ 具体的な名称に |
| 略語禁止 | 初出時はフルスペルで記述 |
| 判断基準 | 「適宜」「状況に応じて」禁止 → IF-THEN 形式で明文化 |
| 日付 | YYYY-MM-DD |

### 視覚・構造

| ルール | 詳細 |
|--------|------|
| 画像 | テキストで完結するよう言語化 (AI は画像を読めない場合あり) |
| テーブル | セル結合禁止、空欄は「なし」と記入 |
| 色による識別 | 廃止。見出しで区分けする |
| 臨時運用 | タイトル先頭に【臨時運用】+ 有効期限 or 解除条件を冒頭記載 |

### 公開前チェックリスト

- [ ] すべての文に主語があるか
- [ ] 「これ」「上記」を具体的な言葉に書き換えたか
- [ ] 図の内容がすべてテキストで説明されているか
- [ ] 2000 字を超えていないか (超えていれば分割)
- [ ] 臨時運用なら解除条件が書いてあるか

## Notion 編集ルール (Notion 使用時)

| ルール | 詳細 |
|--------|------|
| 見出し | H2 = 大見出し、H3 = 小見出し (H1 は使わない) |
| 色使い | 2 色までに抑える |
| 赤字 | 絶対に忘れてはいけない操作のみ |
| トグル | 入れ子禁止。短い内容 (2-3 行) には使わない |
| フロー図 | Mermaid 記法推奨 |
| ページ作成先 | プライベートではなく Teamspace に公開 (透明性重視) |

Notion 詳細仕様は `guidelines/common/notion-writing.md` 参照。

## ドキュメント専用リポジトリ vs コード同居

| 採用条件 | 専用 Repo | コード同居 |
|---------|----------|-----------|
| ドキュメント間リンク多い | ✓ | |
| コード変更と常に連動 | | ✓ |
| 非エンジニアも編集 | ✓ | |
| Lint/CI 独立が必要 | ✓ | |

**判定軸**: 上表の ✓ が多い側を選ぶ。横断検索・非エンジニア参加・独立 Lint が必要なら専用 repo 寄り。コード変更と密結合で、変更の度に整合が問われるなら同居寄り。README や API docstring は常にコード同居。

## Markdown Lint

`markdownlint` 等の Lint ツールで強制し、CI で実行。書き手の揺れを機械的に吸収。

- H1 は 1 ファイル 1 つ
- 見出しレベル飛ばし禁止 (H2→H4 不可)
- コードブロックに言語指定必須
- 行長制限は設定次第 (日本語は無効化推奨)

## フォーマット優先順位 (本文構造)

1. **テーブル** — 比較・一覧に最適
2. **箇条書き** — 列挙・手順に最適
3. **コードブロック** — 5 行以内の例
4. **段落** — 最終手段 (1 行まで)

### 比較表の書き方

```markdown
| 避ける | 使う | 理由 |
|--------|------|------|
| 古い書き方 | 新しい書き方 | 1 行の理由 |
```

### セキュリティ (記載禁止)

| 記載禁止 | 代替 |
|----------|------|
| API キー | プレースホルダー `__API_KEY__` |
| パスワード | 例: `your-password` |
| 実 URL | 例: `https://example.com` |

## 関連

- [PRINCIPLES.md](PRINCIPLES.md) — 共通文章原則
- [long-form-doc.md](long-form-doc.md) — 長文 doc 執筆 + ADR/PRD/EARS テンプレ
- [design-doc-protocol.md](design-doc-protocol.md) — DD プロトコル
- `guidelines/common/notion-writing.md` — Notion 固有フォーマット
- `references/writing-patterns.md` — 詳細パターン (書き直し Phase / textlint)
