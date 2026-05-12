---
name: DesignDoc粒度ガイド
description: DesignDocをどこまで書くかの指標。テンプレ選択・行数目安・運用ルール。
type: reference
---

# DesignDoc 粒度ガイド

DesignDoc をどこまで書くかの指標。書き方の実践は `design-doc-writing-guide.md` 参照。

## 前提: Design Doc と詳細設計書は別物

混同するとレビュー不能になる。**Design Doc を書く前に、それが Why か How かを判別する。**

| 項目 | Design Doc | 詳細設計書 |
|------|-----------|-----------|
| 主目的 | 設計判断の共有 | 実装仕様の定義 |
| 主な読者 | エンジニア全体・レビューア・SRE・PdM | 実装者 |
| フォーカス | **Why / Architecture** | **How / Implementation** |
| 粒度 | 大きい | 細かい |
| 内容 | 背景・課題・選定理由・トレードオフ・非機能要件 | テーブル定義・API・SQL・バリデーション・シーケンス |
| レビュー観点 | 設計として妥当か | 実装漏れがないか |
| 更新タイミング | 設計変更時 | 実装変更時 |
| 例 | 「なぜ SKIP LOCKED を使うか」 | 「SQL をどう書くか」 |

**アナロジー**: Design Doc = 「なぜ吊り橋にするか」/ 詳細設計書 = 「ボルト何本・鉄骨サイズいくつ」。

### 業界での比重

| 文化圏 | Design Doc | 詳細設計書 |
|--------|-----------|-----------|
| Web 系・Go マイクロサービス | 必須（+ ADR + PR + コード） | 最小限〜省略 |
| SIer・大規模受託・金融・官公庁 | 弱い | 必須 |

### DDD / マイクロサービス領域での優先度

**Design Doc 力 > 詳細設計力**。transaction / lock / idempotency / saga / retry / eventual consistency 領域は「実装」より「設計判断」が価値。「なぜその境界か」「なぜその整合性モデルか」が後続開発の土台。シニアになるほど Design Doc 力が問われる。

このガイドの粒度判定（軽量/フル/分割）は **Design Doc 側** を対象とする。詳細設計書は別ドキュメント（or PR / コード / 自動生成）で扱う。

## テンプレ / パターン選択

| パターン | 状況 | 行数目安 |
|---|---|---|
| **軽量・単ファイル** | 小〜中機能、AI 生成前提、レビュー負荷下げたい | ≤ 300 |
| **フル・単ファイル** | 大規模変更、セキュリティ影響、複数ドメイン跨ぐ、非機能要件あり | ≤ 800 |
| **分割型ディレクトリ** | 新サービス立ち上げ・大規模プロジェクト | 各 ≤ 400 |
| **自由形式** | マイグレーション計画・横断施策 | — |

**迷ったら軽量版から開始** → 行数超過や設計判断の複雑化でフル / 分割へ昇格。

## 軽量版テンプレ構成

5 節構成で素早く書ける版。

```text
# Design Doc: {タイトル}

## 1. Overview        # 何を実現するか / Issue・PRD リンク
## 2. Data Flow       # シーケンス図 / 主要フロー
## 3. Data Schema     # テーブル設計 5 列表
## 4. API Design      # エンドポイント表
## 5. Appendix        # 代替案 / 未決事項 / 関連リンク
```

## フル版テンプレ構成

12 セクション固定。`design-doc-template.md` 参照。重要セクション抜粋:

- Introduction / Context
- Goals / Non-Goals
- Proposed Design（High-Level / Detailed）
- Data Schema / API Design
- Logging / Monitoring
- System Integration
- Deployment / Rollout
- Testing Strategy
- Security Considerations
- Risks / Performance
- Appendix

## 分割型の構成

```text
DesignDocs/{context}/{project}/
├── summary.md       # エントリ。全体像・リンク集
├── architecture.md  # ソフトウェアアーキテクチャ
├── domain-model.md  # ドメインモデル
├── table.md         # テーブル設計
├── api.md           # API 設計
├── sequence.md      # シーケンス図
├── ui-web.md / ui-app.md
└── batch.md / worker.md
```

- `summary.md` を最初に書く（他ファイルへのリンクと全体像）
- 分割基準は「担当エンジニア」か「レビュー粒度」が別れる単位

## 運用ルール

| 項目 | 内容 |
|------|------|
| 保存先 | リポジトリ内の `docs/DesignDocs/` をデフォルトに（GitHub 等のバージョン管理下） |
| Status | `draft → proposed → approved → archived`（`proposed` は PR レビュー中） |
| 設計判断 | 各判断に **不採用案の理由** を明記 |
| セキュリティレビュー | 影響度に応じて専用レビュアー or 専用ツール（Gem 等）を併用 |

## 関連

- `design-doc-writing-guide.md` — 書き方の実践ノウハウ
- `design-doc-template.md` — 12 セクションのフルテンプレート
- `design-phase-flow.md` — brainstorm → prd → design-doc → plan → dev → docs の遷移
- `decision-quality-checklist.md` — 意思決定品質の 5 問チェック
