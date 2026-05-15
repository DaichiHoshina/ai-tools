---
name: 文章執筆パターン集 (補足)
description: 共通原則は guidelines/writing/PRINCIPLES.md。本ファイルは補足パターン (書き直し Phase / レビュー3段 / textlint / フェーズ境界 / skill 連携) のみ。
type: reference
---

# 文章執筆パターン集 (補足)

共通原則と適用先別ガイドは `guidelines/writing/` 参照。本ファイルは詳細パターン集 (長文 doc 書き直しフロー / textlint 規約 / フェーズ境界)。

- [`guidelines/writing/PRINCIPLES.md`](../guidelines/writing/PRINCIPLES.md) — 共通原則 (4 問 / 7 指針 / 3 変換 / 媒体別構造 / セルフチェック 6)
- [`guidelines/writing/design-doc-protocol.md`](../guidelines/writing/design-doc-protocol.md) — DD 4 Step + 10 パターン + アンチパターン + セルフチェック 18
- [`guidelines/writing/long-form-doc.md`](../guidelines/writing/long-form-doc.md) — 長文 doc (DD/PRD/RCA) + ADR/PRD/EARS テンプレ
- [`guidelines/writing/external-post.md`](../guidelines/writing/external-post.md) — 短文 (PR コメント/Slack/Issue) + 5 軸採点

## 書き直し Phase 1-8 (長期レビューを経た DD/PRD の典型フェーズ)

| Phase | 内容 |
|-------|------|
| 1 方針決定・ドラフト | PRD / 過去議論 / 朝会ログを全読してから着手 |
| 2 全面清書 | テンプレ準拠、経緯記述 / 案 A・B 造語 / 網羅志向を排除 |
| 3 自レビュー補強 | Security / API Design / Risks / Performance / Logging / Mermaid 図 / 数値根拠の出典追加 |
| 4 コードベース突合 | migration 番号・カラム配置・型・API パス・前提条件を実装と一致 |
| 5 レビュー反映削除 | テンプレ外 / 冗長 / 言い換え反復 / 自己参照 / PR 単語を削る |
| 6 削りすぎ復元 | 文脈通らない箇所を再注入、削減と保持を交渉 |
| 7 文体統一・lint | 体言止め / 敬体常体 / 単位 (万・億・ms・MB) / textlint |
| 8 大方向転換 | 旧記述を残さず一気に新方針へ、変更履歴・経緯セクションも一掃 |

**回数見積もり**: 軽量テンプレ準拠ドラフト 3-5 commits / フルテンプレ 5-10 / 自由形式 20+ / 方針未確定でフル着手 50+。初稿でテンプレ準拠すると往復激減。

### レビュー応答の対応表

| 指摘 | 対応 | Phase |
|------|------|-------|
| 「いらない」「これは何？」 | 即削除 | 5 |
| 「もっと詳しく」「分かりにくい」 | 段落で補強 | 3 |
| 「実装と違う」 | コード再確認 | 4 |
| 「方針が違う」 | 過去議論を辿って合意案に戻す | 4 |
| 「テンプレに無い」 | 該当セクション削除 | 5 |
| 「文体混在」「単位揃ってない」 | 一括置換 | 7 |

## レビューは内容→文→構造の 3 段で別ループ

1 回で全部見ると観点が混ざる。**内容→文→構造の順で抽象度が変わる**ので段 1→2→3 が効率的。

| 段 | 観点 | 対象 |
|----|------|------|
| 1 内容整合性 | ファイルパス / 構造体フィールド / DB NOT NULL / PRD 受け入れ条件の対応抜け / Phase 計画の依存 / Why-not 妥当性 | 既存コード grep |
| 2 文章規定 | 評価語の根拠 / 助詞重複 / だ・である調 / AI listing pattern / 抽象語 / 読後アクション末尾明示 | NG 辞書 + textlint |
| 3 読みやすさ | 情報密度 / 表 vs 段落バランス / 優先度 / 図解統一 / forward reference のアンカー化 / 新規読者目線 | AI 目視 |

タイミング: 段 1 は `/design-doc` 出力後 PR 起票前、段 2 は PR 起票後 CI 通過後、段 3 は最後に「初見読者が読めるか」確認。

## textlint で文体崩れを機械検出する

人間目視で見逃しやすい文体崩れは textlint (`@textlint-ja/ai-writing` + `textlint-rule-preset-ja-technical-writing`) で機械検出。CI conclusion が success でも annotation が付くため、PR 作成前にローカル実行。

### 頻出 NG パターン

| 違反 | NG 例 | OK 例 |
|------|-------|-------|
| 文末「。」なし (見出し的に名詞句で終わる) | `含むもの` | `本設計では以下を扱う。` |
| 絶対表現 | `完全に保証する` / `絶対に〜` / `必ず〜される` | `確実に届ける` / `〜される` |
| 助詞重複 (一文に同じ助詞 2 回以上) | `処理が決済を含むため整合性が壊れる` (「が」「が」) | 文を分ける or 一方を「は」へ |
| だ・である調混入 (常体ベースに「である」混在) | `〜は大きいからである。` | `〜は大きい。` / `〜のためだ。` |
| AI listing pattern (リスト全項目が「**強調**: 説明」形式) | `- **高**: 設計を確定する前に〜`<br>`- **中**: 設計は変わらないが〜` | 表に変換 or 地の文に展開 |

**事実宣言の絶対表現は OK**: 「最終的に必ず 1 対 1 にマッピングされる」のような数学的事実宣言。禁止対象は「主観的に必ず守られる」のような根拠なき言い切り。

### ローカル実行

```sh
npx textlint -f pretty-error <path>.md
npx markdownlint-cli2 <path>.md
```

### CI annotation 確認 (GitHub)

```sh
gh api repos/{owner}/{repo}/commits/<SHA>/check-runs \
  --jq '.check_runs[] | {name, conclusion, count: .output.annotations_count}'
gh api repos/{owner}/{repo}/check-runs/<ID>/annotations
```

`.github/workflows/` パスへの annotation は CI infra 由来で本文無関係なら無視可。

## 設計 / 計画 / 実行のフェーズ境界を越境しない

ドキュメント駆動開発の典型事故ポイント。

| フェーズ | 許可 | 禁止 | よくある違反 |
|---------|------|------|--------------|
| 設計 (DD / ADR) | 要件分析・代替案比較・設計判断 | 実装・テスト作成・タスク分解 | 設計中にコードを書き始める |
| 計画 (タスク分解 / ProjectDocs) | タスク定義・依存整理・リスク評価 | 実装・設計変更・新機能追加 | 計画書を書きながら実装に手を出す |
| 実行 (実装 / テスト) | 実装・テスト・ファイル操作 | 設計変更・スコープ拡大・新仕様追加 | 実装中に「ついでに」リファクタやスコープ追加 |

**越境を検出する質問**: 「いま書いているのは、このフェーズの成果物か？」「これは次フェーズで書くべきものでないか？」答えに迷う時点で越境している。

## 技術ドキュメント執筆時の skill 連携

技術系ドキュメント (API 設計・バックエンド設計) を書くときは関連 skill を併用、用語と構造のブレが減る。

| 書く対象 | 併用する skill |
|----------|--------------|
| REST/gRPC API 設計、エンドポイント仕様 | `/api-design` |
| サービス層・データアクセス層・ジョブ設計 | `/backend-dev` |
| マイクロサービス間連携・モノレポ構成 | `/microservices-monorepo` |
| アーキテクチャ判断・DDD | `/clean-architecture-ddd` |
