# ドキュメント体系原則

プロダクト開発におけるドキュメント種別の役割分担・関係性・保存構造の抽象原則。具体的な分類表は `documentation-strategy.md` を参照。

## 6種別の役割分担

| 種別 | 答える問い | 時制 | Owner |
|------|-----------|------|-------|
| PRD (Product Requirements) | **何を作るか** / Why now | 着手前 | PdM |
| ADR (Architecture Decision Record) | **なぜこの技術判断にしたか**（構造・非機能・技術選定） | 判断時 | Tech Lead |
| Design Doc | **どう実装するか** | 実装前 | Developer |
| Project Docs | **いつ誰がどう進めるか** | 進行中 | PjM |
| Product Spec | **実際に何が作られたか** | リリース後 | PdM |
| Technical Spec | **現在の技術仕様** | 継続更新 | Developer |

**判定フロー**:

```text
書きたい内容は...
├─ ビジネス価値・要件 → PRD（未リリース） or Product Spec（リリース済み）
├─ 技術選定の理由 → ADR（1決定=1ファイル、不可逆）
├─ 実装設計 → Design Doc（実装前、レビュー後 merge）
├─ 現行の仕様 → Technical Spec（実装変更に追従）
└─ 進行管理 → Project Docs（スコープ・スケジュール・リスク等）
```

## ドキュメント間の関係性

```text
PRD （何を）
  ↓ 技術判断が必要
ADR （なぜ）
  ↓ 実装方針を決める
Design Doc （どう）
  ↓ 実装→リリース
Product Spec （実際に作られたもの）
Technical Spec （現時点の仕様スナップショット）
```

- **PRD と ADR は独立**: PRD は「何を作るか」、ADR は「技術判断の記録」。PRD 内で技術判断を書かない
- **Design Doc は PRD にリンク**: 必ず PRD/Issue リンクを貼る。Why が PRD 側にあるため
- **Product Spec はリリース後に PRD から派生**: PRD 時点の想定 vs 実装結果の差分を埋める

## Bounded Context による分割

DDD のドメイン境界でディレクトリを切る。混ぜると保守性が崩れる。

```text
docs/
├── <DocType>/
│   ├── general/          # プロジェクト横断・共通
│   └── <context_name>/   # 各ドメインコンテキスト
```

**判定**: このドキュメントは「1つのドメイン内で完結するか」。
- Yes → `<context_name>/` 配下
- No（2+ドメインにまたがる） → `general/` 配下

コンテキスト名が決まらない = ドメイン設計が未成熟のシグナル。先にドメイン整理。

## 命名規則

| 種別 | 形式 | 理由 |
|------|------|------|
| PRD | `YYYY-MM-DD-feature-[name].md` | 時系列で並ぶ、意思決定時点が明確 |
| ADR | `NNNN-[decision-title].md` (seq番号) | 順序が履歴、後で挿入禁止 |
| Design Doc | `[feature-name].md` or `YYYY-MM-DD-[name].md` | Feature 単位で検索しやすい |
| Product Spec | `feature-[name].md` | PRD の日付と切り離す（仕様は継続更新） |

**原則**: ファイル名で **時系列性 or ID性 or 検索性** のどれを重視するか決める。混在させない。

## テンプレート駆動

各種別ディレクトリに `template.md` を置き、新規作成時は必ずコピーして使う。

**Why**: 書く人によって構造がバラつくと、レビュワーが毎回読み方を学習し直す必要がある。テンプレ固定でレビュー観点が揃い、読み込みコストが下がる。

**テンプレ必須セクション**:
- PRD: 背景 / ゴール / スコープ / 成功指標 / 非スコープ / オープン質問
- ADR: Context / Decision / Consequences / Alternatives（比較）
- Design Doc: Overview / Goals & Non-Goals / Background / High-Level Design / Detailed Design（データモデル・API・処理フロー）/ Alternatives / Trade-offs / Failure Handling / Migration Plan（Expand→Migrate→Contract）/ Rollback / Observability / Open Questions

## レビュープロセス

設計系ドキュメント（PRD / ADR / Design Doc）は **観点を分けた複数レビュワー** を立てる。最低限「技術的妥当性」と「要件・UX との整合」の2観点。

**Why**: 設計は選択であり、1人の視点だと見落としが出る。観点を分けることで死角を減らす。人数・役職は組織構成に合わせて調整してよい。

**Merge 条件**（組織で固定する例）:
- 必要な観点のレビュワー全員の Approve
- オープン質問がクローズされているか、別 Issue 化されている
- テンプレ必須セクションが埋まっている（空欄なら理由明記）

## ドキュメント専用リポジトリ vs コード同居

| 採用条件 | 専用 Repo | コード同居 |
|---------|----------|-----------|
| ドキュメント間リンク多い | ✓ | |
| コード変更と常に連動 | | ✓ |
| 非エンジニアも編集 | ✓ | |
| Lint/CI 独立が必要 | ✓ | |

**判定軸**: 上表の✓が多い側を選ぶ。横断検索・非エンジニア参加・独立 Lint が必要なら専用 repo 寄り。コード変更と密結合で、変更の度に整合が問われるなら同居寄り。README や API docstring は常にコード同居。

## Markdown Lint

`markdownlint` 等の Lint ツールで強制し、CI で実行。書き手の揺れを機械的に吸収。

- H1 は 1 ファイル 1 つ
- 見出しレベル飛ばし禁止（H2→H4 不可）
- コードブロックに言語指定必須
- 行長制限は設定次第（日本語は無効化推奨）
