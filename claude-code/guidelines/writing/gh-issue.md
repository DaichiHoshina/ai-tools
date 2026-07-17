# GitHub issue body 書式

共通文章原則は [PRINCIPLES.md](PRINCIPLES.md) 参照。

## 原則

- **簡易 pattern (背景 / やること / 補足) を default にする**
- **開いた文章 (plain JP) 必須**: 箇条書き内も「〜する / 〜した」で文として閉じる。体言止め羅列・助詞省略を body 全体で禁止する (canonical: `rules/plain-jp.md`)
- **階層で結論と根拠を分ける**: 同レベル bullet に「変更」と「変更の理由」を並列に置かない。親 = 変更 1 文、子 = 理由 / 補足 の形にする (詳細 pattern と NG/OK 例は `PRINCIPLES.md` `## 箇条書き階層化` `### checkable pattern` + `pr-description.md` `### 変更 bullet の型`)
- **簡潔ミニマル**: 該当しない section は見出しごと削除する。空 section・「特になし」を残さない
- template 系 (What / Why / To Do / Acceptance Criteria の 4 節構造) は section 数が多く読みづらい。避ける
- design doc がある場合は背景末尾に doc path を 1 行 link、issue 本文は doc の anchor 指定で詳細を委譲する
- **時限マーカー禁止**: 「本 issue で新設」「先週合意した」「#XXX 以降」等、merge / 投稿後の読み手が解決できない時制参照を書かない (canonical: `pr-description.md` `### 時限マーカー禁止`)

## Canonical format

```markdown
## 背景

(2〜4 段落: 何が問題か / なぜ起きるか / 影響範囲。設計 doc がある場合は path を最後に link)

## やること

### 1. <小タイトル>

(file path + 変更内容を箇条書きで具体的に)

### 2. <小タイトル>

(同上)

### 3. test を追加

(test ケースを箇条書き)

## 補足

- 親 issue / 関連 issue link
- 起点 doc / 根拠 file path
- 後続 issue (本 issue では対応しないもの)
- 完了条件 (build pass / regression なし 等)
```

## 避ける書式 (template 系)

```markdown
# 概要 (What)
# なぜやるのか (Why)
# やってほしいこと (To Do)
# 受け入れ条件 (Acceptance Criteria)
# AI 向け: コンテクスト情報
```

- section 数が多く読みづらい
- 「受け入れ条件」と「やってほしいこと」が冗長
- 「AI 向け」節は共有 issue に不要 (repo の CLAUDE.md / AGENTS.md で cover)

## How to apply

- impl issue 起票時、`gh issue create --template` は使わず本 file の pattern で body を組む
- design doc がある case は背景末尾に doc path を 1 行 link、詳細は doc の §N anchor で委譲する
- 完了条件 (build / test / regression 確認) は補足末尾に箇条書きで集約、別 section を切らない

## GitHub project field

GitHub project board 上で他 issue と「見た目が違う」と感じたら `Priority` / `Size` 等の field が未設定の可能性が高い。`gh project item-list` で他 issue の field 値を確認して合わせる。本文 pattern と別問題。

## 適用範囲

- 全 repo (組織を問わない)
- impl issue / 調査 issue / タスク issue 起票時

## 参照

- `guidelines/writing/pr-description.md`
- `guidelines/writing/design-doc-protocol.md`
- `guidelines/writing/PRINCIPLES.md`
