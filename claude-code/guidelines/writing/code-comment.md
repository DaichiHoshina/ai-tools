# コードコメント規約

コード内コメント (`//` `/*` `--` `<!-- -->` `#`) の書き方原則。
対象読者はコードレビュアー / 将来の自分 / AI エージェントとする。
対象外は PR 本文 / commit message で、それぞれ専用ガイドラインを参照する。

## 基本原則: default 書かない、書くなら Why not

記述対象の使い分け原則 (コード=How / テストコード=What / コミットログ=Why / コードコメント=Why not) は CLAUDE.md §Writing が canonical。
書くなら **Why not (なぜ別の選択肢を採らなかったか)** を書く。例外は (a) 調べても辿り着きにくい外部 / 内部運用 memo (`MEMO:` prefix 必須) (b) 公開 API の godoc の 2 つだけ。
設計根拠 (WHY: なぜこの値 / 順番 / 挙動か) は commit log が持つのでコードに書かない。コードに書かないと消える情報は「検討して捨てた選択肢」がほぼ唯一だからだ。
コードを読めば分かる内容 (what) を繰り返すコメントは削除する。

## 既存 comment に触るかの判定 (最優先)

**本規約の分量上限・品質基準は「これから書く新規 comment」に対する目標であり、既存 comment を機械的に短縮する根拠にしない**。既存 comment を触る前に、下記の順で判定する。

1. **理由と挙動を過不足なく説明できているか** → できているなら**そのまま残す** (行数超過でも触らない)
2. 削除 9 カテゴリ (what 言い換え / 開発経緯 / defensive 言い訳 / 主観評価 / commented-out code 等) に該当するか → 該当のみ削除
3. 内容は妥当だが冗長・曖昧・古い情報を含むか → その範囲だけ書き直す

**行数目安を理由に既存 comment を圧縮しない**。触った結果、読み手が失う情報 (理由 / 挙動 / 副作用) がある短縮は退行修正だ。分量が気になる時は「削るか、残すか」の 2 択で判定する (中途半端に縮めない)。

## 判定順序 (新規作成時)

**新規に comment を書く**時のみ適用する。既存 comment の判定は上記「既存 comment に触るかの判定」が優先する。

comment を書く前に **(a) 書くかどうか → (b) 何を書くか (Why not に絞れているか) → (c) 日本語品質** の順で判定する。
日本語品質 rule (主語明示 / 開いた文章) を理由に comment を長くしない。品質 rule は「書くと決めた文」にだけ適用する。

- **default = 書かない**。迷ったら書かない (コードと識別子で伝わるなら comment は不要)
- **行数上限は設けない**。Why not + 根拠を過不足なく書けば足りるだけの行数を使う。1 行で足りるなら 1 行、複雑な incident workaround / 外部仕様 memo / 公開 API の godoc は必要なだけ書く
- 行数を埋めるために書き足さない。伝わる最短で止める
- comment 密度は周辺 code に合わせる。全行 / 全 block に付けない
- 後述「fail-safe / fallback 説明」は 1 文 default。目的文を足すのは副作用が非自明な場合のみ

## 配置: 該当行の真上に書く

comment は説明対象の行の**真上**に置く。行末 comment や、対象から離れた位置 (数行上 / block 先頭にまとめる等) には書かない。読み手が comment と対象行を対応付ける手間をなくす目的。

- メソッド / 関数名の直上 comment は**そのメソッドの内容を簡潔に説明するもの**に限る (godoc 形式)。実装詳細や特定行の説明をメソッド直上に書かない
- 特定行の WHY / 重要 memo は、その行の真上に書く

```go
// NG: 行末 comment
time.Sleep(100 * time.Millisecond) // rate limit 対策

// NG: メソッド直上に行単位の説明を混ぜる
// rate limit が 10 req/s のため 100ms 遅延する
func ProcessBatch(ctx context.Context) (int, error) {

// OK: メソッド直上はメソッド要約、行の説明は該当行の真上
// ProcessBatch は inventory_batch から未処理レコードを取得して集計する。
func ProcessBatch(ctx context.Context) (int, error) {
    // 外部 API の rate limit が 10 req/s のため、1 バッチを 100ms ずつ遅延して送信する。
    time.Sleep(100 * time.Millisecond)
```

## 残す 3 分類 (優先順)

### (1) Why not: 採らなかった選択肢とその理由 (原則これだけ書く)

「素直に書くならこうするはず」の選択肢を捨てた箇所に書く。次の読み手 (将来の自分 / AI) が「なぜこう書かないのか」と書き直したくなる場所が対象で、退行修正を防ぐ効果が最も高い。
設計判断の根拠 (WHY: なぜこの値か / なぜこの順番か) はコードに書かず **commit log に書く**。コードに残す価値があるのは、書き直しの誘惑が働く Why not だけだ。

```go
// retry は行わない。呼び出し元の job scheduler が再実行を持ち、二重 retry で送信が重複するため。
send(msg)
```

```bash
# sed -i は BSD / GNU で引数仕様が異なるため使わない。一時 file + mv で置換する。
sed "s/.../" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
```

判定基準: そのコメントを消したとき、レビュアーが「普通は X では?」と指摘してきそうなら Why not を書く。誰も別案を思いつかない箇所には書かない。

### (2) 重要 memo: 調べても辿り着きにくい外部 / 内部運用情報だけ (例外、`MEMO:` prefix 必須)

コード / repo 内 / 公式 doc をすぐ引けば分かる情報は書かない。残すのは外部仕様の非自明な罠・incident 由来 workaround・非公開制限・内部運用の取り決めのように「見ても調べても辿り着きにくい」ものだけ。
**`MEMO:` prefix を付ける** (Why not と区別し、機械的に grep 可能にする)。

```go
// MEMO: 外部決済 API の仕様で金額は円単位の整数。小数点以下は切り捨て (四捨五入では決済エラーになる)。
amount := int(price)
```

### (3) godoc: 公開シンボルの API doc (行数制限なし)

公開 API には godoc / JSDoc / docstring 形式で API doc を付ける。private シンボルには原則付けない。実装詳細や特定行の説明を書かない。swagger / OpenAPI annotation もこの分類に含む。

godoc は `go doc` / IDE hover / pkg.go.dev で参照される公開仕様 doc であり、code の実装 comment とは目的が別だ。使用例・引数説明・返り値・edge case・関連 API への言及など、利用者が API を正しく使うために要る情報を書く。冗長さは通常 comment と同じく避ける (書けば書くほど良いわけではない、書き手として不要な行は削る)。

```go
// ProcessBatch は inventory_batch から未処理レコードを取得して集計する。
//
// 集計単位は 1 バッチ = 最大 100 件。外部 API の rate limit (10 req/s) を
// 尊重し、100ms 間隔で送信する。ctx を cancel すると次バッチ開始前に停止し、
// 処理済み件数を返す。err は外部 API エラーおよび DB write エラー時に非 nil。
//
// 呼び出し元は返り値の件数を必ず確認する (context cancel 時の部分成功を検知するため)。
func ProcessBatch(ctx context.Context) (int, error) {
```

## 削除する 9 カテゴリ

### (1) what: コードの言い換え

コードを読めば分かる内容の繰り返しは削除する。

```go
// NG: i をインクリメントする
i++

// NG: エラーを返す
return err
```

### (2) PR 文脈依存: チケット番号単独 / 開発時の経緯

将来の読み手にはチケット番号だけでは内容が分からない。
チケット番号を残すなら、なぜその対応をしたかを 1 文添える。

```go
// NG: #5678 対応
// OK: 外部サービスのタイムアウトが 30s に変更されたため、クライアント側も 30s に合わせる (issue #5678)。
```

### (3) 自明アサーション: 型から明らかな制約

型システムや言語仕様で保証される内容を再説明しない。

```go
// NG: nil の場合は early return する
if err != nil {
    return err
}
```

### (4) defensive 言い訳: 「念のため」「とりあえず」「一応」

不確かさを表明するコメントは実装の問題を隠す。正しく実装してからコメントを書く。

```go
// NG: 念のため nil チェック
// NG: とりあえず 0 を返しておく
// NG: 一応ログを出しておく
```

### (5) 主観評価: 根拠のない「十分」「余裕」「問題ない」

客観的な根拠のない評価は将来の意思決定を誤らせる。
数値や条件に置換するか削除する。

```go
// NG: タイムアウトは十分な余裕がある
timeout := 30 * time.Second

// OK: 外部 API の p99 応答が 8s のため、2 倍余裕を持って 16s に設定する。
timeout := 16 * time.Second
```

### (6) テスト不確実表現: 「〜するはず」「おそらく」

テストや検証で確認してから断言する。

```go
// NG: これで重複が防げるはず
// NG: おそらくここでキャッシュが効く
// OK: Redis の SETNX で排他制御する。同一キーへの並行書き込みは先着 1 件のみ成功する。
```

### (7) 重複: 同一概念を複数箇所で説明

同じ内容のコメントが複数箇所にある場合、最も文脈に近い 1 箇所だけ残す。

### (8) 経過メモ: 開発中の変遷・時系列記述

コメントは**現在のコードの事実のみ**を記述する。開発中の変遷 (「〜から変更」「以前は〜だった」「レビュー指摘で修正」「当初 X だったが Y にした」) は git history / PR が保持するため、コードに残さない。

```go
// NG: 当初は 30s だったが timeout 頻発のため 60s に変更
// NG: レビュー指摘により defer に書き換え
// NG: v2 移行に伴い旧ロジックから差し替え
// OK: 外部 API の p99 応答が 45s のため 60s に設定する。
timeout := 60 * time.Second
```

経緯に WHY が含まれる場合は、経緯部分を落として現在形の根拠だけ残す。

### (9) commented-out code: 削除予定コードを残さない

不要になったコードは削除する。version control が履歴を保持するため、コメントアウトで残す必要はない。

```go
// NG: 旧実装を残す
// result := oldCalculate(input)
result := newCalculate(input)
```

例外: 短期 (≤1 sprint) の A/B 切替や、PR レビュー中の比較目的で一時的に残す場合のみ。その場合は **`TODO:` prefix + 理由** を 1 行添える (`TODO:` で機械的に grep 可能にし、削除漏れの回収経路を確保する)。

```go
// TODO: 旧計算式。A/B 比較が終わったら削除する。
// result := oldCalculate(input)
result := newCalculate(input)
```

## 意図的な冗長 (defensive redundancy) は 1 行 comment で明示する

「(4) defensive 言い訳」で削除するのは「念のため」等の**不確かさ表明**である。区別して、**故意に条件を二重に書いた保険的な冗長**は残す。ただし意図が読み取れない冗長は refactor で消されるため、**1 行 comment で「何を守るか」を必ず添える**。

典型例は SELECT で絞った id を UPDATE / DELETE に渡す構造で、UPDATE / DELETE 側にも同じ where 条件を重ねて書くパターン。SELECT filter が守っている前提では UPDATE 側の条件は理論上 noop に見えるが、SELECT filter が将来 refactor で壊れた場合の最後の砦として機能する。

```sql
-- NG: 意図が読み取れず「重複だから消そう」となりやすい
SELECT id FROM orders WHERE reserved_flag = 0 AND processed_at IS NULL FOR UPDATE;
UPDATE orders SET processed_at = NOW() WHERE id IN (...) AND reserved_flag = 0;

-- OK: comment で保険の意図を明示する (構造は NG と同じ)
SELECT id FROM orders WHERE reserved_flag = 0 AND processed_at IS NULL FOR UPDATE;
-- SELECT filter が破れても予約済み row (reserved_flag = 1) を書き換えないよう UPDATE 側でも守る保険。
UPDATE orders SET processed_at = NOW() WHERE id IN (...) AND reserved_flag = 0;
```

**判定基準**:

- SELECT で絞った id を UPDATE / DELETE に渡す構造で、UPDATE / DELETE 側にも同じ where があったら意図を確認する
- 意図的な保険なら 1 行 comment で「どのカラムが守られるか」を残すよう指摘する
- 逆に「重複だから消したい」を見つけたら、SELECT 側の filter が絶対に外れない保証があるか確認してから消す

同じ判定は API 層の権限チェック二重化 (route middleware + handler assertion)、frontend の入力バリデーション二重化 (client-side + server-side) にも当てはまる。**二層目が理論上 noop に見える場合、意図 comment がないと片方が消される。**

## AI 時代のコメント

### AI 生成マーカー禁止

`// AI-generated` / `// TODO: AI suggested` / `// Generated by Copilot` 等の生成元マーカーは残さない。レビュー時に判断根拠が「AI が書いた」に矮小化され、人間レビュアーが思考停止する原因になる。詳細: `references/on-demand-rules/ai-output.md`。

### Comment Traps 回避

削除予定コード / 古い WHY コメント / 「(8) commented-out code」の例外なき長期放置は、AI コード生成 (Copilot / Claude Code 等) が **「有効な現役例」と誤読** して誤った提案を生む原因になる。コメントと実装の乖離を放置せず、コード変更時に同 PR で更新または削除する。

出典: arxiv 2024 "Comment Traps: How Defective Commented-out Code Augment Defects in AI-Assisted Code Generation"。

---

## 日本語品質

コメントを日本語で書く場合は以下の品質基準を守る。
**guard: 以下の品質 rule は「書くと決めた行」にだけ適用する。** 本節の OK 例は NG 例より長いが、これは「書くと決めた文の直し方」であって「長く書くほど良い」ではない。書き直すと長くなる comment は、その前にまず削除 (what 言い換えなら書き直しではなく削除が正解) を検討する。

### 主語明示

主語を省略すると「誰が / 何が」動くかが曖昧になる。

```
NG: 取得に失敗した場合はスキップする。
OK: 設定値の取得に失敗した場合は、該当レコードをスキップして次の処理に進む。
```

### データ保持識別子の godoc は名詞述語で閉じる (動作動詞禁止)

const / var / struct field などデータを保持するだけの識別子の要約に、動作動詞 (「まとめる」「持つ」「管理する」「制御する」) を付けない。入れ物は動作しない。「何であるか」を名詞 (一覧 / 組 / 対応表 / 既定値) で言い切る。

```
NG: // ExcludeKeys は、重複チェックの対象から外すプロダクトとサイズの ID をまとめる。
OK: // ExcludeKeys は重複チェックから除外する (プロダクト ID, サイズ ID) の組の一覧。
```

NG 例は「Keys がまとめる」という主述不一致に加えて、次項の修飾連鎖も同時に踏んでいる。

### 連体修飾の連鎖回避 (かかり先曖昧)

「A の B の対象から外す C と D の ID」のように修飾が 3 つ以上連なると、「外す」「の」のかかり先が複数解釈になる。読み手が「C の ID と D の ID なのか、(C, D) の組なのか」を問い返したくなったら書き直す。組・一覧・対応表などの構造語と括弧表記 `(X, Y) の組` で構造を固定する。

### 「ため」連鎖回避

「〜のため〜のため〜のため」と続くと因果関係が不明確になる。2 文に分割する。

```
NG: 外部 API のレート制限があるため処理件数を制限するためスリープを入れる。
OK: 外部 API のレート制限は 10 req/s。超過時は HTTP 429 が返るため、100ms のスリープを挟んで送信する。
```

### 半角スペース: 英数字と日本語の間

```
NG: Versionチェック、IDを取得する
OK: Version チェック、ID を取得する
```

### 二重否定回避

```
NG: null でない場合は処理しない
OK: null の場合のみスキップする
```

### 接続詞乱用回避

「しかし」「また」「さらに」「なお」が連続すると流れが追いにくくなる。
文を分割するか接続詞を削除する。

---

## 「変に略さない」原則

体言止め圧縮で主語が物や状態に移り、擬人化が生じるパターンを避ける。

### 擬人化 NG パターン

| NG | OK |
|---|---|
| `--dry-run flag 未渡しが実際の INSERT を走らせないようにする` | `--dry-run flag の指定漏れがあった場合に、意図せず実際の INSERT が実行されることを防ぐ目的。` |
| `flag 未指定時は dry-run=true。` | `dry-run flag の取得に失敗した場合は安全側に倒して dry-run=true として続行する。` |
| `タイムアウト到達で処理中断。` | `タイムアウトに達した場合は、処理中のバッチを中断して部分的な結果を返す。` |

**違反典型**:
- 主語が物 / 状態 / flag の擬人化 (「flag が〜する」「エラーが〜する」)
- 口語動詞 (「倒す」「握る」「進まれる」)
- 連用形否定 (「未渡し」「未指定時」) — 「指定がない場合は」と展開する

### 多義語は文脈で明示化

「打ち切り」「同期」「中断」「停止」のように **文脈依存で意味が変わる単語** は、何の打ち切りか / 何との同期かを 1 語添えて明示化する。

| Before (多義) | After (文脈明示) |
|---|---|
| `打ち切り` | `別 TX 更新の中断` |
| `同期更新` | `別 TX で実行する更新` (「同期」が時系列同期と読まれる懸念) |
| `中断` | `retry を諦めて log 出力する` |
| `停止` | `worker process の終了 (再起動可)` |

**判断基準**: 単語単独で読み手が「何の」と問い返したくなったら多義。1 語で意味を固定する。

### 略称・外部 doc 前提の代名詞禁止

**code comment 内で「3 識別子」「A 系」「例の flag」等の略称や、DesignDoc / 社内 slack を前提とした代名詞を使わない**。code reader は当該 DesignDoc を読んでいる保証がない。初出は 1 句で具体名に展開する。

| NG | OK |
|---|---|
| `3 識別子は size_codes 側だけが持つため、products 側を NULL に落とす。` | `has_size = true のとき inhouse_code / oripa_item_id / oripa_item_code は size_codes だけが持つため、products の同フィールドには NULL を設定する。` |
| `例の flag が立っていれば skip する。` | `enable_new_pipeline flag が true なら旧経路を skip する。` |
| `A 系と B 系の判定は DesignDoc 参照。` | `admin API 経由 (A 系) は同期処理、batch 経由 (B 系) は非同期。詳細: <URL>` |

**判断基準**: comment 内の名詞句が「同 repo の別 file を grep すれば意味が特定できる」か。特定できない (外部 doc を要する) 名詞は展開するか URL を添える。

### godoc / 関数コメントと実装内 comment は重複させない

関数直上の godoc で説明した内容を、関数内 comment で繰り返さない。実装内 comment は Why not / 分岐理由に限る (canonical §「残す 3 分類」)。重複した実装内 comment はレビューで削除を促される。

### 独立 directive は隣接シンボルと空行で分離する

`//go:generate` / `//go:build` / `// +build` / linter 抑制 (`//nolint:xxx`) 等の**独立 directive は、直下の関数 / 型定義と意味的に無関係な場合、無関係シンボルの直上に置かない**。位置による関連付けを避けるため 1 行空行を入れる。

例:

```go
// NG: OrderProduct と無関係な directive が隣接し、関連ありに見える
//go:generate mockgen -source=oripa_product.go
type OrderProduct interface { ... }

// OK: 空行分離で無関係を示す
//go:generate mockgen -source=oripa_product.go

type OrderProduct interface { ... }
```

**判断基準**: directive の対象が directive 直下のシンボルでない場合は空行を挟む。対象が直下シンボル (例: `//nolint:xxx` が直下 func に効く) なら密着で可。

---

## 識別子は用語変更しない (ログ互換性のため)

DD / コメント / docs 本文で用語をリネーム (例: 「同期更新」→「別 TX 更新」) する時、コード上の **識別子 (const 名 / 変数名 / feature flag tag / log key / metric 名)** は据え置く。

**理由**: 識別子変更は log 検索 / metric query / feature flag 履歴を破壊する。コメント / docs は文脈で正しい用語に従う一方、識別子は **時系列で安定** していることが運用上必須。

**判断**:
- 更新する: コメント本文 / docs 本文 / PR タイトル / commit message
- 据え置く: const 名 / 変数名 / struct field 名 / feature flag tag / log key / metric 名 / DB column 名

例 (架空):
- 用語 rename: `同期更新` → `別 TX 更新` (コメント / docs)
- 識別子: `productSyncTimeout` / `product_sync_failure` (feature tag) はそのまま (log 検索互換性のため)

リネームと同時に識別子も変えたい場合は、log query / metric / runbook の追従コストを見積もり、別 PR で行う。

---

## 「理由 + 対処」を 1 文で閉じる

Why not を書くなら、対応する動作 (「なので〜する」「そのため〜する」) を同じ 1 文に含める。理由だけ書いて対処を書かないと、読み手は理由から動作を逆算する手間を負う。動作だけ書くと what の言い換えになりがちで削除対象になる。

- 定型: `〜すると〜になるので、〜する。` / `〜だと〜が起きるため、〜する。`
- 長さ: 1 行 (80-100 字以内) に収まる。理由と対処それぞれで 1 行使うと大抵冗長
- 1 文で閉じないなら 2 文目を足すのでなく、そもそも comment が要るかを見直す

```go
// NG (what 言い換え): 削除した行も無条件に退避する
// NG (理由だけ): 削除した行の sort_order を残すと次回の保存で重複エラーになる
// OK (理由 + 対処): 削除した行の sort_order を残すと次回の保存で重複エラーになるので、削除対象もまとめて退避する
```

---

## 英単語 +「化」の圧縮禁止

「true 化」「slot 化」「無効化」など、英単語 (または短い語) に「化」を付けて動作を圧縮する書き方は、主語が消えて何が起きるか読み取れない。主語のある文に開く。

```
NG: OR 条件で誤って true 化しない
OK: OR でつなぐ実装が、どれも一致しないのに true を返さない
```

「化」を残してよいのは業務用語 (可視化 / 標準化 / 非同期化 等) として定着している場合のみ。「〜化する」で主語が物や状態になったら擬人化 NG (「変に略さない」原則 §擬人化 NG パターンと同じ判定)。

---

## fail-safe / fallback 説明は 1 文 default

安全側への倒しや代替動作の説明は 1 文で書く。

```
// {対象} の {取得失敗 / 不在 / 解析エラー} の場合は安全側に倒して {既定値} として続行する。
```

```go
// inventory_batch の設定ファイル解析に失敗した場合は安全側に倒して dry-run=true として続行する。
dryRun := cfg.GetBoolSafe("dry_run", true)
```

2 文目 (「{誤操作シナリオ} で {副作用} が発生することを防ぐ目的。」) を足すのは、**防ぎたい副作用がコードから読み取れない場合のみ**。dry-run のように既定値の意図が自明なら 1 文で止める。テンプレを全 comment の雛形にしない。

---

## 英単語 +「する」動詞化回避

地の文の動詞は日本語に寄せる。識別子・コマンド名はバッククォートで囲い動詞化しない。

| Before | After | 備考 |
|---|---|---|
| `1 件でも失敗があれば非 0 exit する` | `1 件でも失敗があれば終了する` | exit code の詳細は数値が意味を持つ場合のみ残す |
| `不一致を検出 (非 0 exit)` | `不一致を検出した場合は終了する` | 括弧書き → 文に展開 |
| `ctx を cancel する` | `ctx をキャンセルする` | 英語動詞 → カナ動詞化 |
| `lock を acquire する` | `ロックを取得する` | 英語名詞・動詞 → 日本語 |

**判断基準**:
- 識別子 (`ctx` / `dryRun` / `--dry-run`) はバッククォートで囲い、動詞は日本語で添える
- `exit code 1 で終了する` など数値が意味を持つ場合は英単語を残してよい
- 地の文の動詞を英語のままにしない

---

## 体言止め許容ケース

以下の場合は体言止めを許容する。

- godoc の要約行 (慣習的に名詞句で始める、複数行の場合は先頭行のみ対象)
- 短い WHY ラベル (前後の文脈で主語が明確な場合)
- 単発の体言止め (文末の変化として許容する。連続 2 行 / 1 編集 3 件以上の連発は hook が block する)

```go
// ProcessBatch はバッチ処理のエントリーポイント。 ← 1 行 godoc: OK
// rate limit 対策: 100ms スリープ。 ← 前後でバッチ処理の説明がある: OK
```

---

## 違反検知: コメント audit 手順

新規 PR やレビュー時に以下の手順でコメントを分類する。

機械検出 (事前 sweep): 抽出したコメントを file に集めて `scripts/jp-textlint.sh <file>` を通す (詳細列挙は [PRINCIPLES.md § 機械検出 grep](PRINCIPLES.md#機械検出-grep-出力前-sweep) canonical)。冗長表現・弱い表現の混入を自動で拾ってから、下記 14 カテゴリで精査する。

### 抽出コマンド

```bash
# Go
grep -rn '^[[:space:]]*//' <対象ディレクトリ> | grep -v '_test.go' | head -50

# SQL
grep -rn '^[[:space:]]*--' <対象ディレクトリ> | head -50

# TypeScript / JavaScript
grep -rn '^[[:space:]]*//' <対象ディレクトリ> | head -50
```

### 分類・報告フォーマット

抽出したコメントを以下 14 カテゴリ (本文の「残す 3 分類」+「削除する 9 カテゴリ」に、WHY 移動と AI 生成マーカーを加えた監査用の全量) で分類し、削除 / 書き直し対象を特定する。

| カテゴリ | 判定基準 | アクション |
|---|---|---|
| Why not (残す) | 採らなかった選択肢とその理由 | そのまま (最優先で保護) |
| WHY (移動) | 設計判断の根拠 (なぜこの値 / 順番か) | commit log へ移してコードからは削除 |
| 重要 memo (残す) | 調べても辿り着きにくい外部仕様 / incident / 内部運用 | `MEMO:` prefix を付ける。調べれば分かるものは削除 |
| godoc (残す) | 公開シンボルの API doc (行数制限なし) | そのまま。private / 実装詳細は削除 |
| what (削除) | コードの言い換え | 削除 |
| PR 文脈依存 (書き直し) | チケット番号単独 | WHY を 1 文追加 |
| 自明アサーション (削除) | 型から明らか | 削除 |
| defensive 言い訳 (削除) | 「念のため」等 | 削除 + 実装を正す |
| 主観評価 (書き直し) | 根拠なし評価語 | 数値 / 条件に置換 |
| テスト不確実 (書き直し) | 「〜するはず」等 | 検証して断言 |
| 重複 (削除) | 同一概念の複数説明 | 1 箇所に集約 |
| 経過メモ (書き直し) | 「〜から変更」「以前は〜」等の時系列記述 | 経緯を落とし現在形の WHY のみ残す |
| commented-out code (削除) | コメントアウトされたコード | 削除 (例外時は `TODO:` prefix + 理由) |
| AI 生成マーカー (削除) | `// AI-generated` 等の生成元表示 | 削除 |

confidence < 80% の判定は discard する (「この行が何カテゴリか不明確」な場合は指摘しない)。

---

## 関連

- [PRINCIPLES.md](PRINCIPLES.md) — 文章共通原則 (日本語品質 / 体言止め / 文体分離)
- `references/on-demand-rules/ai-output.md` — AI 生成マーカー禁止 (`// AI-generated` 等)
