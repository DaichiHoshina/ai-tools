# 長文ドキュメント執筆 (DesignDoc / PRD / RCA / Notionページ)

長文ドキュメント (DesignDoc / PRD / RCA / Notionページ) の追加ルール。共通原則は [PRINCIPLES.md](PRINCIPLES.md) 参照。

> **原則**: ドキュメントは記憶ダンプではなく、読み手の判断と行動を助ける道具。書くたびに「誰のどの判断を助けるか」から逆算する。

## Writing Contextブロック (任意、draft冒頭)

書き出し時に思考を散らさないため、4問の答えをコメントブロックでdraft冒頭に置く:

```markdown
<!-- Writing Context (4 問・最終削除任意)
読み手: <人物像>
読後アクション: <approve / 実装 / 質問 等>
主要な数字・事例: <測れるもの必須>
なぜこれが必要: <問題 or PRD 接続>
-->
```

抽象語で埋めても無意味。具体人物像・数字・問題を書く。

## 品質検証タイミング

| コマンド | タイミング |
|---------|----------|
| `/design-doc` | Step 8書き出し → Step 8.5で `Read` + NG判定 + `Edit` で書き直しloop |
| `/prd` | 出力直前にself-review (Phase 4.5)。`--out <path>` 時はファイル経由 |
| `/docs` | Notion投稿前 (Step 4.8) にdraft self-review |
| `/retrospective` / `/diagnose` 長文 | 出力前に4問 + 共通セルフチェック6適用 |

**合格ライン**: Critical 1件以上or Warning 4件以上で書き直し (最大2 loop)。3 loop残存はユーザー報告。

**Web 出力 (Notion / GitHub / Confluence) 時は追加チェック 4 項目**: 1 文 60 字 / 主張型 heading / 段落 3-4 行上限 / 太字 scan 化 — 詳細 `PRINCIPLES.md` `## Web 可読性`。

## 分量目安

- 1セクション: 地の文3-5割、箇条書き / 表5-7割
- 箇条書きは3-5項目。7超は表or段落分割
- コードブロック5行以内、超過は意図1文補足
- 1ページ800-1500字、2000字超なら分割
- TL;DR冒頭1-3文で結論。「本稿では〜について述べる」系導入は削除

## 分離 / 統合の判断軸

複数 doc / 1 doc 内 cell 構成の判断:

| 状況 | 推奨 |
|---|---|
| 役割境界明確 (計画 SoT vs 当日 runbook) | 分離維持 |
| scroll 長すぎ / 編集競合多発 / 開く目的混在 | 分離 |
| 1 cell に詰め込みすぎで section 境界見えず | cell 分割 |
| cell 数を増やしても見やすくならない | 凝縮 (cell 数より論理単位) |

**統合の落とし穴**: 当日 runbook に Phase 表 / 指標定義が挟まると視認性悪化。

## SoT 階層の正本判定

複数文書 (DesignDoc / 計画 notebook / 実行 runbook / loadtest scenario) の整合性チェックで矛盾を発見したとき:

- **DesignDoc を正本**として扱う
- 派生文書 (notebook / runbook) が DesignDoc に無い項目を独自追加していたら、削除 or 注釈で位置づけを明示
- 試験中観測と本番監視で対象が異なる場合は注釈を入れる (例:「試験中観測のみ、本番監視対象外」)

## 突合観点 (関連 SoT 間の整合性)

複数文書間で下記を表で突合:

- テストデータ (規模・件数・単位)
- 観点 (試験項目・指標・仮説)
- 結論反映先 (未決事項 No.X → 何で消化されるか)

上流 SoT → 下流文書の対応関係が崩れていないか確認する。

## 既存の3層チェック (対話型リライト)

draft完成後の仕上げ (`/docs` が主に使用)。

| Layer | 目的 | 対象 / 発動 | 質問形式 |
|-------|------|-----------|---------|
| 1 Intent | セクション主旨を言語化、主旨外を削除候補 | セクション数 ≥ 3 or本文 ≥ 300字 | 自由記述「このセクション『<見出し>』で何を伝えたい？」 |
| 2 Understanding | 難解語をユーザーの言葉で再定義し置換 | カタカナ6文字+/英略3文字+/業界用語、`user_vocabulary.md` 既知語skip | 自由記述「『<用語>』ここでどういう意味？」 |
| 3 Expression | AI定型・硬い文語・根拠なき評価語除去 | 下記NG辞書ヒット | `AskUserQuestion` [そのまま / 削除 / 根拠追記 / 書換] |

**Layer 2反映**: ユーザー回答文を **AIで言い換えず原文のまま** draftに置換、`user_vocabulary.md`「用語定義」追記。説明できない場合は `AskUserQuestion` で [調べる / 削除 / 曖昧なまま残す]。

### トリアージルール (質問過多回避)

合計上限 **9件 (3+3+3)**。

| Layer | 上限 | 省略条件 |
|-------|------|---------|
| 1 Intent | 3 | 本文 < 300字orセクション < 3 |
| 2 Understanding | 3 | 既知語 ≥ 3 or難解語 < 3 |
| 3 Expression | 3 | ヒット0 |

上位絞込: 出現頻度順。既知語は常にskip。

## NG辞書 (長文向け検出)

PRINCIPLES.md の AI 臭 3 変換 を参照。Layer 3 で下記カテゴリ検出。

- **AI定型語** (削除): 効果的に / 効率的に / シームレスに / 〜を実現します / ご紹介します / 本稿では〜について述べる / ユーザーエクスペリエンス
- **硬い文語** (柔らかく): 〜である / 〜に基づき / 当該 / 以下に示す
- **根拠なき評価語** (根拠併記基本): 適切な / 最適な / 重要 / 一般的に / 強化する → 直後に数字or事例or「なぜ」1文

## Before/After サンプル

| 観点 | Before | After |
|------|--------|-------|
| 結論先行 | 本機能は効率的にドキュメント作成を可能にします | Notionへmdを直接投稿できる。手動コピペを無くすのが目的 |
| 難語定義 | CQRSで整合性を担保 | CQRS (読み書きを別モデル分離) で整合性。readはreplicaから返せてscale可 |
| 抽象→数字 | エラー処理を強化 | 5xx日次120件→8件、`context.WithTimeout` 全handler追加 |
| プロサ繋ぎ | 箇条書き10項目だけ | 「重要度順、最上位X理由〜」1文→3-5項目→「残りは参考」 |

## user_vocabulary.md

`~/.claude/projects/{project}/memory/user_vocabulary.md` に蓄積。形式: `用語定義` `セクション主旨` `嫌う表現` `好む言い換え` の4セクション、各 `項目 — 内容 (YYYY-MM-DD)`。

## ADRテンプレ (1テーマ1 Decision)

`{topic}` 1テーマ・`Decision` 1つの原則。複数決定を1 ADRに混ぜない。

```markdown
# ADR: [タイトル]
Status: [proposed | accepted | rejected | deprecated | superseded by ADR-XXX]
Created: YYYY-MM-DD

## Context  — 背景・動機・課題・ステークホルダー
## Discussion  — 代替案と pros/cons（案1/案2…）
## Decision  — 決定事項1つ + 主な理由
## Consequences  — 短期/長期のプラス・マイナス影響
## Compliance  — lint / レビュー / hook 等の担保方法
## Notes (任意)  — 参照資料・関連ADR
```

**注意**: 決定が覆る場合は元ADRを編集せず、新ADRで `Status: superseded by ADR-XXX` とする。

## PRD MoSCoWテンプレ (Must/Should/Could/Won't)

実装着手前にビジネス要件・ユーザーストーリーを固定。

```markdown
# [機能名]: PRD

## 概要 — 全体像3-5行、誰のどんな体験か
## 課題と目的 — 現状問題(箇条) / 達成目的
## ユーザーストーリー (MoSCoW)
- Must: [ユーザー]として[実現したいこと]をしたい。なぜなら[理由]
- Should / Could / Won't
## 機能仕様 — 基本機能・詳細・制約条件
## 非機能要件 — p95レイテンシ / セキュリティ / 可用性
## 技術的考慮事項 — 既存システム制約・他チーム依存
## UX/UI仕様 — 画面遷移・ワイヤー
## テスト計画 — 受け入れ基準・回帰観点
## 成功指標(KPI) — 数値で測れる成功定義
## スケジュール — マイルストーン・依存関係
## 関連ドキュメント
```

**MoSCoW運用**: 「全部Must」は優先順位放棄でNG。Won'tを書くとスコープ拡大を防げる。

## EARS受入基準 (WHEN/IF/WHERE + THEN)

受け入れ基準・バリデーション仕様は **EARS形式**で書く。自然言語の曖昧さを排除し、テストケースが機械的に書ける。

**基本パターン**:

```
WHEN [イベント] THEN システムは [応答]
IF [前提条件] THEN システムは [応答]
WHERE [配置/状態] THEN システムは [応答]
WHILE [継続的状態] THEN システムは [応答]
```

**例**:

```
WHEN ユーザーが「購入」ボタンを押下した場合
THEN システムは決済処理を開始する

IF 在庫数が 0 の場合
THEN システムは「在庫切れ」エラーを返す

WHERE ソート順が NULL の場合
THEN システムは該当アイテムを最後に表示する
```

### バリデーション網羅観点 (必須チェックリスト)

入力項目ごとに以下を漏れなく書く:

- [ ] **データ型**: 整数以外・文字列以外・真偽値以外
- [ ] **範囲**: 最小値未満・最大値超過・文字数超過
- [ ] **必須/任意**: 必須項目が未入力・空文字列・NULL
- [ ] **形式**: メールアドレス・電話番号・URL・日時形式
- [ ] **NULL**: NULL許可項目の動作 / NULL不許可項目のエラー
- [ ] **関連性**: 開始日時 > 終了日時 / 最小値 > 最大値
- [ ] **重複**: 既登録・ユニーク制約違反
- [ ] **存在**: 指定IDが存在しない・削除済み

「正常系のみ書いて出す」がよくあるバグ温床。8観点を機械的にチェック。

## コマンドとの接続

| コマンド | 適用 |
|---------|------|
| `/docs` | Step 5 draft → 5.5対話型リライト (Layer1→2→3) → 5.7セルフチェック → 投稿 |
| `/design-doc` | 書き出し前4問、draft完成後 [DDセルフチェック18](design-doc-protocol.md) |
| `/prd` | 同上。「なぜ？」「誰のため？」を厳格に。MoSCoWテンプレ使用 |
| `/git-push --pr` | 4問がPR description 4セクション: **Why** / **What changed** (数字・事例) / **Testing** / **Review focus** |
| `/diagnose` 長文 / `/retrospective` | 4問と原則1-4適用、箇条書きだけで終わらせない |

## 関連

- [PRINCIPLES.md](PRINCIPLES.md) — 共通原則 (4問 / 7指針 / 3変換 / 媒体別構造 / セルフチェック6)
- [design-doc-protocol.md](design-doc-protocol.md) — DD 4 Step + 10パターン + アンチパターン + セルフチェック18
- [external-post.md](external-post.md) — 短文向け (PRコメント / Slack / Issue + 5軸採点)
- [strategy.md](strategy.md) — ドキュメント種別・保存先 / 体系原則
- `guidelines/common/notion-writing.md` — Notion固有フォーマット (主語必須・見出し階層)
- `references/writing-patterns.md` — 詳細パターン (書き直しPhase / textlint / フェーズ境界)

衝突時優先順位: Notion固有 > 長文doc原則 > 共通PRINCIPLES。
