# ドキュメント戦略 (種別・保存先・体系)

ドキュメント種別の役割分担・関係性・保存先・体系原則。`/docs` / `/design-doc` / `/prd` 等の保存先判断時に参照。

> **どう書くか** (執筆原則) は [PRINCIPLES.md](PRINCIPLES.md) / [long-form-doc.md](long-form-doc.md) / [design-doc-protocol.md](design-doc-protocol.md) 参照。

## 6種別の役割分担

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

- **PRDとADRは独立**: PRDは「何を作るか」、ADRは「技術判断の記録」。PRD内で技術判断を書かない
- **Design DocはPRDにリンク**: 必ずPRD/Issueリンクを貼る。WhyがPRD側にあるため
- **Product Specはリリース後にPRDから派生**: PRD時点の想定vs実装結果の差分を埋める
- **改定時の追従 (orphan 防止)**: PRD / ADR を改定したら、参照する Design Doc / Technical Spec / runbook のリンク・前提条件を確認し、乖離があれば即座に追従させる。古い設計が残ると新メンバーが混乱する。突合観点: [long-form-doc.md](long-form-doc.md) 参照

## 保存先

| 種別 | 保存先 | 理由 |
|------|--------|------|
| PRD / ADR / Design Doc / Product Spec / Technical Spec | GitHub (リポジトリ内) | コードと一緒にバージョン管理 |
| Runbook / 開発Tips | Wiki / Notion | 検索・更新が容易 |

## Bounded Contextによる分割

DDDのドメイン境界でディレクトリを切る。混ぜると保守性が崩れる。

```text
docs/
├── <DocType>/
│   ├── general/          # プロジェクト横断・共通
│   └── <context_name>/   # 各ドメインコンテキスト
```

**判定**: このドキュメントは「1つのドメイン内で完結するか」。
- Yes → `<context_name>/` 配下
- No (2+ ドメインにまたがる) → `general/` 配下

コンテキスト名が決まらない = ドメイン設計が未成熟のシグナル。先にドメイン整理。

## 命名規則

| 種別 | 形式 | 理由 |
|------|------|------|
| PRD | `YYYY-MM-DD-feature-[name].md` | 時系列で並ぶ、意思決定時点が明確 |
| ADR | `NNNN-[decision-title].md` (seq番号) | 順序が履歴、後で挿入禁止 |
| Design Doc | `[feature-name].md` or `YYYY-MM-DD-[name].md` | Feature単位で検索しやすい |
| Product Spec | `feature-[name].md` | PRDの日付と切り離す (仕様は継続更新) |

**原則**: ファイル名で **時系列性or ID性or検索性** のどれを重視するか決める。混在させない。

## テンプレート駆動

各種別ディレクトリに `template.md` を置き、新規作成時は必ずコピーして使う。

**Why**: 書く人によって構造がバラつくと、レビュワーが毎回読み方を学習し直す必要がある。テンプレ固定でレビュー観点が揃い、読み込みコストが下がる。

**テンプレ必須セクション**:
- **PRD**: 背景 / ゴール / スコープ / 成功指標 / 非スコープ / オープン質問 — [long-form-doc.md PRD MoSCoWテンプレ](long-form-doc.md#prd-moscowテンプレ-mustshouldcouldwont) 参照
- **ADR**: Context / Decision / Consequences / Alternatives — [long-form-doc.md ADRテンプレ](long-form-doc.md#adrテンプレ-1テーマ1-decision) 参照
- **Design Doc**: 12セクションor軽量5節 — [design-doc-protocol.mdテンプレ選択](design-doc-protocol.md#テンプレ選択) 参照

## レビュープロセス

設計系ドキュメント (PRD / ADR / Design Doc) は **観点を分けた複数レビュワー** を立てる。最低限「技術的妥当性」と「要件・UXとの整合」の2観点。

**Why**: 設計は選択であり、1人の視点だと見落としが出る。観点を分けることで死角を減らす。人数・役職は組織構成に合わせて調整してよい。

**Merge条件** (組織で固定する例):

- 必要な観点のレビュワー全員のApprove
- オープン質問がクローズされているか、別Issue化されている
- テンプレ必須セクションが埋まっている (空欄なら理由明記)

## AI対応ルール (RAG精度)

- 1ナレッジ=1ドキュメント、800-1500字目安 (2000字超は分割)、見出し H1-H3 まで
- 文体: 主語明示 / 指示語禁止 (「これ」「上記」→具体名) / 略語初出フル / 「適宜」禁止 (IF-THEN明文化) / 日付 YYYY-MM-DD
- 構造: 画像はテキスト併記、テーブルはセル結合禁止 (空欄=「なし」)、色識別禁止、臨時運用は【臨時運用】+解除条件冒頭
- 詳細文体ルール: [PRINCIPLES.md](PRINCIPLES.md) + [long-form-doc.md](long-form-doc.md)、Notion固有: `guidelines/common/notion-writing.md`

## ドキュメント専用リポジトリvsコード同居

| 採用条件 | 専用Repo | コード同居 |
|---------|----------|-----------|
| ドキュメント間リンク多い | ✓ | |
| コード変更と常に連動 | | ✓ |
| 非エンジニアも編集 | ✓ | |
| Lint/CI独立が必要 | ✓ | |

**判定軸**: 上表の ✓ が多い側を選ぶ。横断検索・非エンジニア参加・独立Lintが必要なら専用repo寄り。コード変更と密結合で、変更の度に整合が問われるなら同居寄り。READMEやAPI docstringは常にコード同居。

## Markdown Lint

`markdownlint` で CI 強制。詳細ルールは `rules/markdown.md` 参照。

## フォーマット優先順位 (本文構造)

1. **テーブル** — 比較・一覧に最適
2. **箇条書き** — 列挙・手順に最適
3. **コードブロック** — 5行以内の例
4. **段落** — 最終手段 (1行まで)

### 比較表の書き方

```markdown
| 避ける | 使う | 理由 |
|--------|------|------|
| 古い書き方 | 新しい書き方 | 1 行の理由 |
```

### セキュリティ (記載禁止)

| 記載禁止 | 代替 |
|----------|------|
| APIキー | プレースホルダー `__API_KEY__` |
| パスワード | 例: `your-password` |
| 実URL | 例: `https://example.com` |

## 関連

- [PRINCIPLES.md](PRINCIPLES.md) — 共通文章原則
- [long-form-doc.md](long-form-doc.md) — 長文doc執筆 + ADR/PRD/EARSテンプレ
- [design-doc-protocol.md](design-doc-protocol.md) — DDプロトコル
- `guidelines/common/notion-writing.md` — Notion固有フォーマット
- `references/writing-patterns.md` — 詳細パターン (書き直しPhase / textlint)
- [prompt-engineering.md](prompt-engineering.md) — AI 向け prompt / instruction (ヒト向け文書とは別軸)
