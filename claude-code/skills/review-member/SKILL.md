---
allowed-tools: Read, Grep, Glob, Bash
name: review-member
description: team メンバーの過去 PR review 傾向を lens として当てる pre-PR self-review。「レビュアー観点で見て」「member レビューで」「/review-member」で起動。read-only。
---

# review-member

自分の PR に付いた過去の human review コメントから抽出した「team 固有の指摘傾向」を lens として当て、PR 提出前に同じ指摘が付きそうな箇所を先に炙り出す。読み取り専用で修正はしない。

## When to use

| skill / command | 用途 |
|---|---|
| `/review-member` (本 skill) | team 固有の指摘傾向を lens として当てる pre-PR self-check |
| `/review` | 汎用的な自作コード review |
| `/comprehensive-review` | 多観点並列 review (workflow で fan-out) |

review 系を重ねる場合は `/review-member` → 直った差分に対して `/review` の順で回すと重複が減る。

## Input

以下の優先順で対象を決める。

1. 引数に file path / glob が渡されたらそれを対象にする
2. 引数に `PR #<number>` / PR URL が渡されたら `gh pr diff <n>` で diff を取る
3. staged diff (`git diff --cached`) が空でなければそれを対象にする
4. 上記全て該当しなければ「対象を指定して」と縮退して終わる (推測で全 file を走査しない)

対象が 50 file 超のときは「対象が大きすぎる。file か directory を絞って」と縮退する。

## Lens (21 観点)

以下 lens を順に当てる。各行の heuristic に該当したら候補として拾い、`## Noise discard` で 1 度濾す。lens 1-15 は 2026-07 の 76 件、lens 16-21 は 2026-07-24 追加 (rinchsan / kojima の 2026 全 466 件 base で count ≥5 の pattern)。

| # | 観点 | 判定 heuristic | 修正 template |
|---|---|---|---|
| 1 | 命名整合 | 同種概念に異なる型 / 命名を混在 (nullable 系 2 種併存、ID field 名の揺れ、URL grouping が既存慣習外、`sql.NullString` と `sql.Null[string]` の mix、`InhouseCode` と `InHouseCode` 等の大小揺れ) | 既存慣習に寄せて 1 系統に統一する |
| 2 | godoc / 意図明示 | 新規 export 関数に godoc が無い、あっても目的 + 呼び出しタイミングが書かれていない、初出 jargon (「3 識別子」「flag」等) が未展開、論理削除 / 復活 / NULL クリア等の副作用が省かれている、DesignDoc 前提の代名詞をそのまま書いている | godoc に「目的 + 呼び出しタイミング + 非自明な副作用 (has_size = true のとき等の前置き含む)」を 1 段落で書く。略語は初出で内容を並記する |
| 3 | 不要 comment 削除 | 関数コメントと重複する行内 comment、無意味な wording 変更 (batch→バッチ 等)、code の what を言い換えただけの comment | 削除する。書き換えるなら why not (却下した選択肢と理由) を書く |
| 4 | layer 責務 | Usecase から Writer (Command 実装) を直接参照、独自 Err が impl 側に置かれ interface / Command 側から参照できない、repository method から別 repository method を呼んでいる | 独自 Err は Command / interface 側に置き、Usecase は interface 経由で参照する。repository 間依存は Usecase 層で束ねる |
| 5 | immutable 化 | `new*` で生成した後に別 pass で mutation (loadIsMaintenance 系)、Handler で View を後から書き換える | Usecase の Output に必要 field を含め、newView 内で 1 pass で組む |
| 6 | 重複 struct 回避 | 別 endpoint の Request / View / Response を「今は中身同じだから」で共有 | 専用 struct を作る (削除予定 endpoint に道連れされない) |
| 7 | 非推奨 API | Deprecated コメント付きの関数 / 経路 (gorp の `:ids` 展開等) を新規 code で採用 | Deprecated コメントで案内された正 API を使う。既存 code は放置可 |
| 8 | PR 単独 pass | migration PR に entity 変更を混ぜている、migration だけで CI が通らない、DesignDoc の分割方針から逸脱 | test / entity 変更を先行 PR に切り出し、migration PR は migration のみに戻す |
| 9 | DB 安全側 | FK が CASCADE (RESTRICT 相当が安全な場面)、`created_at` に `DEFAULT CURRENT_TIMESTAMP` が無い、`has_*` flag の要否検討が浅い、UNIQUE key の対象単位 (1 order に複数 prize 紐付くか等) が確認されていない | RESTRICT に変える。`DEFAULT CURRENT_TIMESTAMP` を付ける。flag は運用 (data mig 漏れ検知等) の価値を明記する。UNIQUE key は「実データ単位で 1 対 1 か」を DesignDoc / 実 schema で裏取り |
| 10 | error semantics | client 起因 (在庫不足 / lock 競合) を 500 系で返す、error message が原因不明 (「更新に失敗」だけ) | 4xx / 409 に直す。error message に対象 entity 名 + key を入れる |
| 11 | 命名空間 | pkg 直下 private 関数で公開範囲が広すぎる (impl の method 化で済む) | impl の method にして呼び出し元を絞る |
| 12 | 観測性 | log message に対象 entity 名 / key が無い、count 変数のインクリメント数が実際の件数とズレる (`++` 1 回で複数件を数える)、`ctx.Request.Context()` を使わず分散 tracing が繋がらない | log に entity + key + operator_id 等を入れる。count は `+= N` で実数を反映する。context は `ctx.Request.Context()` を root にする |
| 13 | test 対称性 | subtest 内で `t.Parallel()` を呼んでいない、意義の無い test の目的が書かれていない、使い捨て batch でも test 自体は要る、Create 側だけ test して Update 側の test が無い | subtest 冒頭に `t.Parallel()` を追加、test は「何を保証するか」を name か comment で明示、CRUD は片側だけでなく網羅する |
| 14 | PR 概要一致 | PR body に「含まれる」と書いた項目が実 diff に無い / 逆に diff にある変更が概要から漏れている | PR body を実 diff に合わせて書き直す |
| 15 | AI 委譲 diff 目視 | 意味を変えない wording swap (batch→バッチ / インシデント→障害 等) や意義のある comment 削除が diff に混入、AI 由来の日本語置換 (「エラー」→「例外」等) が意味を変えていないか未検査 | AI 生成 diff を著者が pre-commit で目視、意味の無い変更は revert してから push する |
| 16 | 未使用コード検出 | 参照ゼロの struct / method / 変数 / CSS class が残る (test からしか呼ばれない method、旧経路の残骸)。「使われていない」「dead code」「削除しても良い」の指摘が付く | grep で参照数を数え、0 件なら定義本体 + test + fixture を同 PR で掃除する |
| 17 | deploy 順序整合 | migration / API / frontend を跨ぐ変更を 1 PR に押し込み、後方互換なしのまま逐次 deploy を想定している。「先に main にマージ」「デプロイ順序」「後方互換」の指摘が付く | 後方互換 phase (拡張のみ) → 切替 phase → 旧経路削除 phase の 3 段に PR を分け、順序を PR body に明記する |
| 18 | FatalError / SELECT 対応 | `SELECT *` を新規 code で採用 (select_star_guard linter 逃れ)、DB 読取結果を `db.FatalError` で分岐せず `assert.NoError` のみで検証、entity 変更なしで migration 単独 CI が通らない | 必要 column のみ列挙、読取は `assert.False(t, db.FatalError(err))` に揃える、migration 単独で CI 通る状態にしてから merge する |
| 19 | domain logic 配置 | 値の変更 / 検証 (Valid / SetXxx) が Usecase / Handler / repository 側に散っており、domain model 側に method が無い。「モデル側に置いておきたい」「domain model を Usecase で直接変更」の指摘が付く | model に `SetXxx` / `Valid` / `Xxxable` 系 method を実装し、呼び出し側は「method 呼び出し + 保存」だけにする |
| 20 | architecture 層配置 | v1 (pkg) / v2 (v2/pkg) / bounded_context のどこに置くべきか判断されないまま、既存踏襲で v1 に追加し続ける。循環参照や層跨ぎ import が発生する | 新規 = v2 優先、既存修正 = 元の層のまま、将来 = bounded_context の方針で配置根拠を PR body に 1 行書く |
| 21 | Go 版数 追従 | `tt := tt` shadowing (go 1.22 以降不要)、`&T{}` (go 1.26 の `new()` で書ける)、`for _, v := range slice` の loop var capture 対策等、古い idiom が残る | 現行 go version の言語機能に合わせて置き換える (`go.mod` の go directive を SoT にする) |

## Flow

Step 1. Input 判定 (上記 `## Input`) で対象 file list を確定する。

Step 2. 対象 file を Read して、上記 21 lens を順に heuristic 照合する。lens ごとに以下を確認する:
- 静的 pattern (Grep / Bash) で当たるものは 1 pass で拾う (例: lens 9 の `CASCADE` / lens 12 の `mismatchGroups++` / lens 16 の 参照 grep 0 件 / lens 18 の `SELECT \*` / lens 21 の `tt := tt`)
- 意味 review が要るもの (lens 2 godoc / lens 5 immutable / lens 14 PR 概要一致 / lens 17 deploy 順序 / lens 19 domain logic 配置 / lens 20 architecture 層配置) は Read で本文を見て判断する
- file type 別 dispatch は `## Noise discard` の最終節を参照 (Go / migration / Vue で当てる lens を絞る)

Step 3. `## Evidence gate` で各候補に実測根拠を付ける。付けられない候補はここで落とす。

Step 4. `## Noise discard` (canonical: `references/on-demand-rules/review-noise-discard.md`) で候補を濾す。追加 rule:
- lens 該当 0 の観点は出力しない (`lens 3: 該当なし` は書かない)
- confidence 低 (heuristic 一致だが意図的な例外の可能性が高い) は落とす。判断迷ったら残して confidence を `low` と付記する
- 既に本文 comment / godoc で意図が説明済みなら落とす

Step 5. Output format で出力する。

## Evidence gate (指摘前の実物照合、必須)

heuristic 一致だけで指摘を出さない。過去運用 (2026-07-24 fact-check) で 7 件中 5 件が実物と照合していない誤指摘だった (godoc 誤読 / test 網羅の見落とし / 既受入済 pattern の蒸し返し / PR body 既記載 / repo 内 0 件の慣行を前提化)。各候補は出力前に以下の照合を通し、通らないものは落とす。

| 誤指摘 pattern | 照合手順 (指摘前に必須) |
|---|---|
| 「〜が無い」系 (lens 2 godoc 欠落 / lens 13 test 欠落 / lens 16 未使用) | 対象 file と対応 `_test.go` を Grep して不在を実測する。「無い」は grep 0 件を根拠にし、hit したら候補ごと落とす |
| 「〜と書いてある」系 (godoc / comment / PR body の内容への指摘) | 該当行を Read して原文を指摘に引用する。引用できない (= 読み違いの可能性) なら落とす |
| 「repo 慣習では〜」系 (lens 1 / 7 / 19 / 20 の慣行前提) | 慣行の実在を Grep で数え、件数を根拠に添える。repo 内 0 件の「慣習」を前提にしない |
| 既決の蒸し返し | PR 対象なら `gh pr view --comments` で既存 thread を確認する。同 pattern が議論済み / 受け入れ済みなら落とす |

Output の各指摘には根拠 (grep 件数 / 引用行 / thread 参照のいずれか 1 つ) を必ず付ける。

## Output format

```
## review-member 結果

- [lens 名] file:line — 症状 (根拠: grep 件数 / 引用行 / thread 参照) → 修正案
- [lens 名] file:line — 症状 (根拠: 同上のいずれか) → 修正案
...

## 判定
pass  (該当 0)
```
または
```
needs-fix N 件
```

- lens 名は table の「観点」列 (「命名整合」「godoc / 意図明示」等) を使う
- 症状は事実 1 文、修正案は 1 文。根拠は `## Evidence gate` で取った実測を 1 つ書く
- 全観点合計 25 件を超えたら「重要度上位 25 件のみ表示 (全 N 件)」と 1 行添えて truncate する (lens 21 化に合わせ 20 → 25)

## Noise discard

canonical: `references/on-demand-rules/review-noise-discard.md`。追加:

- lens 該当 0 の観点行は書かない
- 「かもしれない」「念のため」等 confidence 低の指摘は落とす
- 既に godoc / comment で意図明示済みなら落とす
- 対象が test file のみのとき、lens 2 / 4 / 5 / 8 / 10 / 17 / 19 / 20 は原則落とす (production code 向け lens)
- 対象が migration file のみのとき、lens 8 / 9 / 17 / 18 を優先的に当て、他は落とす
- 対象が Vue / frontend のみのとき、lens 1 / 3 / 5 / 6 / 15 / 16 を優先、他 (Go 向け) は落とす

## Failure Handling

| 状況 | 挙動 |
|---|---|
| 対象未指定 (Input 4 に該当) | 「file / PR / staged diff のいずれかを指定して」と 1 行返して終わる |
| 対象 file 50 超 | 「対象が大きすぎる。file か directory を絞って」と縮退する |
| `gh pr diff` 失敗 | 「PR diff 取得失敗。auth or number を確認」と 1 行返して終わる |
| Read 対象が binary | skip して残りを続ける |

## Notes

- 本 skill は read-only。修正は user が別途 `/dev` 等で回す
- lens は「team のレビュー傾向」で、絶対 rule ではない。ケースごとに例外を許容する
- lens 追加 / 削除は、以下のいずれかの source から頻出 pattern を抽出して、四半期に 1 回程度 review する:
  - 自分の PR に付いた新規 review コメントの傾向 (base data 76 件相当、`pr-review-digest` skill の集約 HTML から拾う)
  - 特定 reviewer が他者 PR に書いた review コメントの傾向 (base data 数百件、`pr-comments-by-reviewer` skill で reviewer 別 + scope 別に集めて explore-agent で 15+ lens に分類する)
- 起動時は前提 config file の読込は不要 (`pr-review-digest` と異なり、本 skill は lens 定義を本 file 内に持つ)
- lens base data 更新履歴:
  - 2026-07-13 初版: 15 lens、自分の PR 76 件 base
  - 2026-07-24 拡張: 21 lens、rinchsan / kojima の 2026 全 review 466 件 base (対象 PR 60 件)。新 lens 6 件 (16 未使用コード検出 / 17 deploy 順序 / 18 FatalError / 19 domain logic 配置 / 20 architecture 層配置 / 21 Go 版数追従)。既存 lens は heuristic に頻出 pattern を追加補強
