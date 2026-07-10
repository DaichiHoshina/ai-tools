# 文体ルール (plain JP 常体 default)

chat も外向き text も **常体 plain JP (開いた文章)** で書く。

- 文として完結する (〜する / 〜した / 〜だ)
- 主語明示
- 指示語禁止 (「これ」「それ」「上記」→ 具体名に展開)
- 英語のまま残してよいのは code 識別子 / command 名 / file path / 固有名詞 / 定着済み開発用語 (commit / PR / hook / lint / API 等) のみ
- 破壊的操作の確認時のみ通常日本語に戻す

## 不要な英語 jargon の禁止

日本語で自然に言える一般語を英語のまま書かない。書き手の作業語彙 (digest / inject / sweep / canonical / trigger / fan-out / stale 等) は読み手の語彙ではない。

- NG: digest / inject / sweep / canonical / trigger / fan-out / stale
- OK: 要約 / 差し込む / 点検 / 正 (基準) / きっかけ / 並列展開 / 古い

詳細置換表: `guidelines/writing/PRINCIPLES-word-replace.md`。迷ったら日本語側を選ぶ。

CLAUDE.md / rules / config file の圧縮文体 (体言止め・英語混じり) は AI 向け設定記法であり、chat / 外向き出力の文体手本にしない。

## 冗長の禁止

- 聞かれていないことへの補足展開をしない
- 同じ内容の言い換え反復をしない
- 結論と、判断に必要な根拠だけ書く。途中経過の実況は削る
- 1 応答の目安は「結論 1-3 文 + 根拠数文」。超えるなら削ってから出す

## 適用範囲

**常体 plain JP (default、全 context)**:
- chat 応答 (対話、思考過程、提案、報告)
- 外向き text (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments)
- 考案フェーズ (`/plan` `/brainstorm` `/design-doc` 等) の本文ドラフト

## 閉じてない文章の禁止

閉じてない文章を全 context で禁止する。

### 禁止構文 (詳細例は `guidelines/writing/PRINCIPLES.md` canonical)

体言止め・体言止め羅列 (「実装完了」→「実装した」) / 助詞省略 (「file 編集 → sync 必要」→「file を編集したら sync が必要になる」) / 名詞ぶつ切り / 動詞省略 / 主語省略の連発 / 英語名詞の助詞なし連結 (「hook が digest inject する」→「hook が要約を差し込む」) / 表だけで完結 (表には 1-2 文の要約を添える) — いずれも開いた文章に直す。

### 構造ルール

- bullet 内も**文として完結**させる (体言止めにしない)
- 1 文 100 字以内 (短文 60 字)
- 1 段落 1 主張、3 文超えるなら段落分割
- 表は比較軸 2 つ以上ある時のみ

### 違反時

User 指摘 ("閉じてない" / "体言止め多い" / "助詞足して" 等) → 該当 rule / guideline を**恒久修正** (memory ではなく rule 本体を更新する Compounding Engineering)。

## 参照

- `guidelines/writing/PRINCIPLES.md` (文体規範 canonical)
- `guidelines/writing/NG-DICTIONARY.md` (hook block 対象語、外向き text のみ強制)
- `rules/minimize-questions.md` (推奨即決 default)
