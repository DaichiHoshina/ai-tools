# DesignDoc 作成プロトコル

DD = DesignDoc。レビュー指摘パターンを 4 Step + 10 パターンに圧縮した汎用手順。

## 4 Step

| Step | 概要 | 具体 |
|---|---|---|
| 1. 着手前リサーチ | 既存資産・前提の事前確認 | 5 観点 (既存ダッシュボード / フラグ / 識別子実在 / DB 前提 / 関連層影響) + PRD 見出し対応表 |
| 2. 初版必須要素 | テンプレ通りに埋めるべき項目 | テンプレコピー / 用語定義 / アクター matrix / 数値 4 点セット / Rollback / 未決事項 / 監視 1:1 / UTC-JST 併記 / 環境固有名詞 |
| 3. 完成前 3 段スキャン | 提出前セルフレビュー | 抽象 bullet / 数値根拠 / 用語 → lint 実行 (`make lint-md-fix` 等) |
| 4. レビュー対応 | コメント対応規約 | 1 コメ = 1 commit、返信に commit URL、textlint 単独 commit 禁止 |

### Step 1 詳細: 着手前 5 観点

| 観点 | 確認内容 |
|---|---|
| 既存ダッシュボード | 監視・SLO がすでにあるか |
| フラグ | feature flag / kill switch の有無 |
| 識別子実在 | 想定する ID・キー・enum が実在するか |
| DB 前提 | テーブル・index・制約・サイズ感 |
| 関連層影響 | API / Worker / Batch / 別 service への波及 |

### Step 2 詳細: 数値 4 点セット

「規模・頻度・遅延・コスト」を最低でも記載。記載できないなら「未測定 / 推定 / 仮定値」と明示。

### Step 3 詳細: 3 段スキャン

1. **抽象 bullet**: 「対応する」「整理する」等の動詞だけ bullet を発見 → 具体化
2. **数値**: 「多い」「速い」「遅い」を見つけ → 数値 or 範囲
3. **用語**: 初出の専門用語に定義があるか / コードフェンス羅列がないか

## 10 パターン (レビュー指摘の頻出形)

| ID | パターン | 予防 Step |
|---|---|---|
| P1 | AI 臭 (定型句・絵文字・冗長挨拶) | Step 2/3 |
| P2 | 既存資産見落とし (dashboard / flag / 監視) | Step 1 |
| P3 | 用語未定義 | Step 2/3 |
| P4 | 数値根拠不在 | Step 2/3 |
| P5 | 並行性 (race / lock / 順序) 言及なし | Step 1/2 |
| P6 | ロールバック手順なし | Step 2 |
| P7 | テンプレ逸脱 (section 抜け・順序ズレ) | Step 2 |
| P8 | 環境混同 (dev/stg/prd 区別曖昧) | Step 2 |
| P9 | 監視薄 (機能追加と監視追加が 1:1 でない) | Step 2 |
| P10 | textlint 単独 commit | Step 4 |

## レビュー対応 (Step 4) 詳細

- **1 コメント = 1 commit** で整理 (force-push 可)
- **返信に commit URL を必ず添付**
- **textlint / lint 修正単独 commit は禁止** — 対応 commit に合流
- 指摘の Resolve は **レビュワー**が行う (実装者は resolve しない)

## 関連

- [external-post.md](external-post.md) — 文章原則 (DD にも適用)
- [auto-knowledge-update.md](auto-knowledge-update.md) — レビュー指摘の学び自動追記
- `common/documentation-strategy.md` — ドキュメント戦略
