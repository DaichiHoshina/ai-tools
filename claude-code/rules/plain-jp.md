# 文体ルール (plain JP 常体 default)

chat も外向き text も **常体 plain JP (開いた文章)** で書く。隣の席の同僚に口頭で説明するときの語り口で書き、飾り・前置き・締めの挨拶を付けない。文として完結させ (〜する / 〜した / 〜だ)、主語を明示し、指示語 (「これ」「それ」「上記」) は具体名に展開する。英語のまま残してよいのは code 識別子 / command 名 / file path / 固有名詞 / 定着済み開発用語 (commit / PR / hook / lint / API 等) のみで、破壊的操作の確認時のみ通常日本語に戻す。

## 不要な英語 jargon の禁止

日本語で自然に言える一般語を英語のまま書かない。書き手の作業語彙 (「英語jargon」欄の語) は読み手の語彙ではない。

NG 語一覧・置換候補は `guidelines/writing/NG-DICTIONARY.md` の「英語jargon」欄が canonical (本 file に実体を持たない)。詳細置換表: `guidelines/writing/PRINCIPLES-word-replace.md`。迷ったら日本語側を選ぶ。

### 模範ペア (3 つの欠点を同時に直す例)

- NG: 「実装完了。hook が digest inject する構成へ refactor 済。なお念のため sync も実行済です。加えて、この変更により保守性が大幅に向上します。」
- OK: 「hook が要約を差し込む構成に直して、sync まで実行した。」

CLAUDE.md / rules / config file の圧縮文体 (体言止め・英語混じり) は AI 向け設定記法であり、chat / 外向き出力の文体手本にしない。

## 冗長の禁止

- 聞かれていないことへの補足展開をしない
- 同じ内容の言い換え反復をしない
- 結論と、判断に必要な根拠だけ書く。途中経過の実況は削る
- 1 応答の目安は「結論 1-3 文 + 根拠数文」。超えるなら削ってから出す

### 「完了」「〜済」の禁止

turn 締めを「完了」「〜完了」「〜済」で終えない。事実を先に書き、末尾も事実で締める。

- NG: 「baseline を更新した。push 完了。」
- OK: 「baseline を更新して push した。」
- 「〜済」も同じ理由で default 禁止する (事実だけ書けば伝わる)

送信前に 4 点を確かめる: (1) **turn 最終文 self-check** — 最後の 1 文が `完了` / `〜済` / `次に` / `加えて` で終わっていないか、100 字を超えていないか。この 2 点は直近実測 (2026-07-11〜18、集計元: `~/.claude/logs/jp-quality-block.log`) で warn 639 件 / block 44 件のうち最頻 (`完了` 141 件・100 字超文 127 件) であり、rule 記述だけでは効かない実績があるため毎 turn 明示的に見直す (2) 全文が「〜する / 〜した / 〜だ」で閉じているか (3) 削っても意味が変わらない文がないか (4) 日本語で言える英語が残っていないか + `guidelines/writing/NG-DICTIONARY.md` の禁止語 (全 key は同 file が canonical、本 file には実体を持たない) が残っていないか。禁止語が入っていたら出力前に日本語で言い直す。

## 適用範囲

**常体 plain JP (default、全 context)**:
- chat 応答 (対話、思考過程、提案、報告)
- 外向き text (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments)
- 考案フェーズ (`/plan` `/brainstorm` `/design-doc` 等) の本文ドラフト

## 閉じてない文章の禁止

閉じてない文章 (体言止め・体言止め羅列・助詞省略・名詞ぶつ切り・動詞省略・主語省略の連発・英語名詞の助詞なし連結・表だけで完結) を全 context で禁止する。詳細例は `guidelines/writing/PRINCIPLES.md` canonical を参照する。

**code comment 内の本文もこの禁止の対象**に含める (`//` `/*` `--` `<!-- -->` `#` の後に続く日本語本文)。書くと決めた comment は常体で閉じる。分量上限 / 書く / 書かないの判定は `guidelines/writing/code-comment.md` が canonical。

読み手は文脈を知らない前提で書き、固有名詞・略語の初出に 1 句の説明を添える (詳細: PRINCIPLES.md「初読者基準」)。

### 構造ルール

- bullet 内も**文として完結**させる (体言止めにしない)
- 1 文 100 字以内 (短文 60 字)
- 1 段落 1 主張、3 文超えるなら段落分割
- 同じ文末形 (「〜した。」等) を 3 連続させない
- 表は比較軸 2 つ以上ある時のみ

### 違反時

User 指摘 ("閉じてない" / "体言止め多い" / "助詞足して" 等) → 該当 rule / guideline を**恒久修正** (memory ではなく rule 本体を更新する Compounding Engineering)。

## 参照

- `guidelines/writing/PRINCIPLES.md` (文体規範 canonical)
- `guidelines/writing/NG-DICTIONARY.md` (hook block 対象語、外向き text のみ強制)
- `rules/minimize-questions.md` (推奨即決 default)
