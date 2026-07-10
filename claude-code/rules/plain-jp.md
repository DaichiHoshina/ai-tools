# 文体ルール (plain JP 常体 default)

chat も外向き text も **常体 plain JP (開いた文章)** で書く。

- 文として完結する (〜する / 〜した / 〜だ)
- 主語明示
- 指示語禁止 (「これ」「それ」「上記」→ 具体名に展開)
- 技術用語はそのまま維持
- 破壊的操作の確認時のみ通常日本語に戻す

## 適用範囲

**常体 plain JP (default、全 context)**:
- chat 応答 (対話、思考過程、提案、報告)
- 外向き text (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / comments)
- 考案フェーズ (`/plan` `/brainstorm` `/design-doc` 等) の本文ドラフト

## 閉じてない文章の禁止

閉じてない文章を全 context で禁止する。

### 禁止構文 (詳細例は `guidelines/writing/PRINCIPLES.md` canonical)

体言止め・体言止め羅列 (「実装完了」→「実装した」) / 助詞省略 (「file 編集 → sync 必要」→「file を編集したら sync が必要になる」) / 名詞ぶつ切り / 動詞省略 / 主語省略の連発 / 表だけで完結 (表には 1-2 文の要約を添える) — いずれも開いた文章に直す。

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
