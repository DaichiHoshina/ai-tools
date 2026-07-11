# 長文ドキュメント執筆 (DesignDoc / PRD / RCA / Notionページ)

共通原則は [PRINCIPLES.md](PRINCIPLES.md) 参照。

> **原則**: ドキュメントは記憶ダンプではなく、読み手の判断と行動を助ける道具。書くたびに「誰のどの判断を助けるか」から逆算する。

本文は全種別 (DesignDoc / PRD / RCA / local-docs HTML / Notion) で **開いた文章 (plain JP) + 簡潔ミニマル** を守る。箇条書き内も文として閉じ、体言止め羅列・助詞省略を禁止する。該当しない template section は見出しごと削除する (canonical: `rules/plain-jp.md`)。

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

### AI hallucination 防止 (起動時の補足)

長文 doc を AI と書く場合、推測で書いて hallucination を埋め込む事故が多い。下記 3 つを起動時に必ず守る。

- **新 library / API method を直書きする前に、`context7` skill または WebFetch で最新 docs を確認**する。記憶を信用しない (CLAUDE.md `## Library API Live Doc Required` と整合)
- **検証していない数値・log・metric を書かない**。「不明」「未測定」と書いてレビュー時に補完する方が事故が少ない
- **「分からない場合は答えない」を貫く**。空欄や `TBD` を残す方が、もっともらしい誤情報より安全

## 品質検証タイミング

| コマンド | タイミング |
|---------|----------|
| `/design-doc` | Step 8書き出し → Step 8.5で `Read` + NG判定 + `Edit` で書き直しloop |
| `/prd` | 出力直前にself-review (Phase 4.5)。`--out <path>` 時はファイル経由 |
| `/docs` | Notion投稿前 (Step 4.8) にdraft self-review |
| `/retrospective` / `/diagnose` 長文 | 出力前に4問 + 共通セルフチェック7適用 |

**合格ライン**: Critical 1件以上or Warning 4件以上で書き直し (最大2 loop)。3 loop残存はユーザー報告。

**Web 出力 (Notion / GitHub / Confluence) 時は追加チェック 4 項目**: 1 文 60 字 / 主張型 heading / 段落 3-4 行上限 / 太字 scan 化 — 詳細 `PRINCIPLES.md` `## Web 可読性`。

## 1 文 1 行format (sentence-per-line)

DesignDoc / PRD / RCA など Git 管理長文 md に適用する規約。詳細: `guidelines/writing/PRINCIPLES.md` §markdown 長文 doc 参照。Notion など WYSIWYG 系本文には適用しない (改行が段落分割として描画されるため)。

## 分量目安

長さ・分割の基準は `PRINCIPLES.md` の「### 長文 (Design Doc / PRD / RCA / Notionページ)」を参照。

## 分離 / 統合の判断軸

複数 doc / 1 doc 内 cell 構成の判断:

| 状況 | 推奨 |
|---|---|
| 役割境界明確 (計画 SoT vs 当日 runbook) | 分離維持 |
| scroll 長すぎ / 編集競合多発 / 開く目的混在 | 分離 |
| 1 cellに詰め込みすぎで section 境界見えず | cell 分割 |
| cell 数を増やしても見やすくならない | 凝縮 (cell 数より論理単位) |

**統合の落とし穴**: 当日 runbookに Phase 表 / 指標定義が挟まると視認性悪化。

## SoT 階層の正本判定

複数文書 (DesignDoc / 計画 notebook / 実行runbook / loadtest scenario) の整合性チェックで矛盾を発見したとき:

- **DesignDocを正本**として扱う
- 派生文書 (notebook / runbook) がDesignDocに無い項目を独自追加していたら、削除 or 注釈で位置づけを明示
- 試験中観測と本番監視で対象が異なる場合は注釈を入れる (例:「試験中観測のみ、本番監視対象外」)

## 突合観点 (関連 SoT 間の整合性)

複数文書間で下記を表で突合:

- テストデータ (規模・件数・単位)
- 観点 (試験項目・指標・仮説)
- 結論反映先 (未決事項 No.X → 何で消化されるか)

執筆者は上流 SoT と下流文書の対応関係が崩れていないか確認する。

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

`PRINCIPLES.md` の「### NG辞書 (削除対象)」を canonicalとする。Layer 3の検出 categoryは同sectionの AI 定型語 / 硬い文語 / 評価語 に対応。

## Before/Afterサンプル

抽象→数字 / 難語定義 / 評価語→根拠の基本変換は `PRINCIPLES.md` の `## AI臭を消す3変換` を canonical とする。ここでは長文 doc 固有の 2 観点のみ挙げる。

| 観点 | Before | After |
|------|--------|-------|
| 結論先行 | ドキュメント作成を効率化する仕組みです | Notionへmdを直接投稿できる。手動コピペを無くすのが目的 |
| プロサ繋ぎ | 箇条書き10項目だけ | 「重要度順、最上位X理由〜」1文→3-5項目→「残りは参考」 |

## user_vocabulary.md

`~/.claude/projects/{project}/memory/user_vocabulary.md` に蓄積。形式: `用語定義` `セクション主旨` `嫌う表現` `好む言い換え` の4セクション、各 `項目 — 内容 (YYYY-MM-DD)`。

## 文書構造論 — PREP 以外の選択肢

PREP (`PRINCIPLES.md` 既出) は「結論先出し → 理由 → 例 → 結論再確認」で **判断 / 採否を促す** ケースに最適。文書の目的が異なる場合は別構造を選ぶ。

| 構造 | 適用場面 | 順序 | Why |
|---|---|---|---|
| **PREP** | 採否を促す決定文書 (PR 本文 / 提案 / RCA 結論) | Point → Reason → Example → Point | 結論を先に渡し検討負荷を下げる |
| **SCQA** | 問題提起 / 経営提案 / 投資稟議 | Situation → Complication → Question → Answer | 「なぜこの問いか」を共有してから解を渡す。読み手が当事者意識を持ちやすい |
| **SDS** | 短報告 / メール / Slack 投稿 | Summary → Details → Summary | 結論を冒頭 + 末尾の 2 回置き、記憶定着させる。短文で詳細埋没を防ぐ |
| **ピラミッド原則 (Minto)** | 大型 proposal / 戦略文書 / 多論点 deck | 結論 → (縦: なぜ?) + (横: 他にあるか?) で MECE 分解 | 多論点を MECEで階層化、論証強度が読み手に伝わる |

**判断**: 採否決定 → PREP / 問題提起 → SCQA / 短報告 → SDS / 多論点戦略 → ピラミッド。同一文書内で構造混在はしない (例: SCQAで始めて途中からPREPに切り替えると論証の前提が崩れる)。

### SCQAテンプレ (架空例)

```
Situation (現状): 自社の通知配信は SES + cron で日次 10 万通を処理している。
Complication (変化): 季節キャンペーンで瞬間 50 万通 / 時の要件が発生、cron では完走 5 時間で SLA 1 時間を満たさない。
Question (問い): どの方式で 50 万通 / 時を達成するか。SES 維持 + 並列化 / SQS + Lambda 化 / マネージドサービス置換 の 3 案。
Answer (解): SQS + Lambda 化を採用。根拠は (1) 既存資産再利用 (2) スループット線形 scale (3) コスト前年比 +15% で許容範囲。
```

### SDSテンプレ (短報告、架空例)

```
Summary: 負荷試験完了、p95=320ms (目標 1s)、deadlock 0 件、本番 GO 判断可。
Details:
  - Phase 1 (60 VU): p95=180ms / success 100%
  - Phase 2 (200 VU): p95=320ms / success 99.97%
  - deadlock 0 件 (全 Phase)
Summary 再: 全 Phase で SLO 充足、deadlock リスクなし、本番 GO で問題ない。
```

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

**prototype-first 運用 (Cagan 2024-2025)**: PRD 本文を厚くするより、clickable prototype / wireframe / 画面遷移図の link を本文中で参照する方が discovery を進めやすい。`## UX/UI仕様` には Figma / wireframe link を置くことを推奨する。link が無い PRD は実装に入れない判断基準にするとよい。

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

## 報告書 / 振り返り構造

報告書・障害報告・1on1 振り返り・sprint reviewは **事実 / 解釈 / 提案** または **KPT / YWT** で分離する。混在禁止。

### 報告書: 事実 / 解釈 / 提案 三層分離

障害報告 / 顧客報告 / 監視結果共有は 3 層を明示的に section 分離する。

| 層 | 内容 | 書き方 |
|---|---|---|
| **事実** | 観測値・log・metric・時系列 | 数値と時刻のみ、評価語ゼロ |
| **解釈** | 原因の推論・影響範囲・関係性 | 「と推定する」「が原因と判断する」根拠併記 |
| **提案** | 次の行動・防止策・調整事項 | 担当 + 期限 + 期待効果 |

**Why**: 事実と解釈の混在は読み手に「記述内容は確定値か推論か」を判断させ、認知負荷が上がる。事実層の数値だけ抽出して別判断したい読者のために 3 層分離する。

**blameless 原則 (postmortem / RCA / incident report)**: 主語を「個人」ではなく「system / process / 仕組み」にする。「A さんが手順を飛ばした」ではなく「checklist に該当 step がなく、目視確認に依存していた」と書く。再発防止 (提案層) も「個人の注意喚起」ではなく「自動化 / lint / hook / 手順書改訂」で書く。詳細: `local-docs` skill の postmortem 本文ルール。

### KPT (Keep / Problem / Try)

振り返り (1on1 / sprint review / 事後検証) で課題と継続を分離する三分割。

| 項目 | 内容 |
|---|---|
| **Keep** | 続けたい良い習慣・成功した手法 |
| **Problem** | 直面した課題・改善余地のある手順 |
| **Try** | 次に試す改善案・期限 + 担当 |

P (Problem) と T (Try) の対応関係を 1:1で書く (P3 → T3)。Pだけ書いて Tがないと actionにならない、Tだけ書いて Pがないと根拠不明。

### YWT (やった / わかった / 次にやる)

KPTの軽量版。正の学習サイクル中心、短文で書く。

| 項目 | 内容 |
|---|---|
| **やった (Y)** | 今回実施した内容 |
| **わかった (W)** | 学んだ知見 / 失敗 / 制約 |
| **次にやる (T)** | 次回の action |

KPTは課題明示が必須、YWTは継続学習の記録に特化。週次や日次の軽い振り返りは YWT、月次以上の改善には KPTを使う。

### 議事録: 決定 / 検討 / 持ち帰り 三分割

ミーティング議事録は 3 種類を分離することを推奨する。

| 種別 | 書き方 |
|---|---|
| **決定事項** | 担当 + 期限明示。確定したことのみ |
| **検討中** | 次回アジェンダ化。「次回までに Xを調査して持参」 |
| **持ち帰り** | 担当 + 期日。会議外で確認 / 相談する |

3 種類が混在すると参加者間で「決まったこと」の認識がずれる。決定事項だけを section 抽出して Slackへ投稿できる粒度に整える。

## AI prompt の引用記法

長文 doc 内で AI prompt (Claude / GPT 等への指示文) を引用する場合は、地の文と混ぜず以下の 2 形式で区別する。

| 場面 | 記法 |
|---|---|
| 単一行 prompt | バッククォート inline (`` `次の log を 3 行で要約して` ``) |
| 複数行 prompt | code fence + lang tag (`` ```prompt `` または `` ```text ``) |

```prompt
あなたは SRE です。以下の log から障害の起点 (timestamp + service 名) を 1 行で抽出してください。
回答は JSON 形式 `{ "timestamp": "...", "service": "..." }` のみとし、説明文を付けないでください。
```

地の文に prompt を埋め込まない (`「〜してください」と頼んだ` のような間接話法は再現性が下がる)。doc を読んだ人が同じ prompt を再現できる粒度で書く。

## コマンドとの接続

| コマンド | 適用 |
|---------|------|
| `/docs` | Step 5 draft → 5.5対話型リライト (Layer1→2→3) → 5.7セルフチェック → 投稿 |
| `/design-doc` | 書き出し前4問、draft完成後 [DDセルフチェック18](design-doc-protocol.md) |
| `/prd` | 同上。「なぜ？」「誰のため？」を厳格に。MoSCoWテンプレ使用 |
| `/git-push --pr` | PR 本文は [pr-description.md](pr-description.md) canonical (7-section JP: 背景 / Related Issue / 実装概要 / 影響範囲 / 動作確認エビデンス / 動作確認手順 / 備考) を適用。本 doc の 4 問 (読み手 / 行動 / 数字 / なぜ) は draft 起点として併用 |
| `/diagnose` 長文 / `/retrospective` | 4問と原則1-4適用、箇条書きだけで終わらせない |

## 関連

- [PRINCIPLES.md](PRINCIPLES.md) — 共通原則 (4問 / 8指針 / 3変換 / 媒体別構造 / セルフチェック7)
- [design-doc-protocol.md](design-doc-protocol.md) — DD 4 Step + 10パターン + アンチパターン + セルフチェック18
- [external-post.md](external-post.md) — 短文向け (PRコメント / Slack / Issue + 5軸採点)
- [strategy.md](strategy.md) — ドキュメント種別・保存先 / 体系原則
- `guidelines/common/notion-writing.md` — Notion固有フォーマット (主語必須・見出し階層)
- `references/writing-patterns.md` — 詳細パターン (書き直しPhase / textlint / フェーズ境界)

衝突時優先順位: Notion固有 > 長文doc原則 > 共通PRINCIPLES。
