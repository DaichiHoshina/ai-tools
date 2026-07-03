# 共有 doc に個人ローカルパスを書かない

DesignDoc / PR body / issue 本文 / Slack / Notion など**チーム共有 doc に個人ローカルパス (`~/ghq/...` / `~/Documents/...` など) を書かない**。

## 原則

- 共有 doc から `~/ghq/` `~/Documents/` `~/.claude/` `/Users/<name>/...` などの個人 path を参照しない
- 長い内容を「退避 file 参照」で圧縮するのではなく、**本文中に 1 行で統合する**
- 退避が必要なほど詳細が要るなら、そもそもその doc に書かない判断もある

## Why

`~/ghq/` などの path は個人メモ領域で他 member には見えない。共有 doc からリンクしても他 member は開けず、指摘対象になる。

## How to apply

### NG

```markdown
複合 UNIQUE 採用理由 → 退避ファイル `~/ghq/docs/investigation/....md` 参照
```

### OK (本文統合)

```markdown
複合 UNIQUE: group 境界での検索最適化と仕様の自己記述性のため
```

### OK (共有領域への退避)

- 組織の共有 doc 領域 (repo 配下 `docs/` / Notion / 内部 wiki 等) へ退避する
- URL / 相対 path で参照する
- 退避先も他 member から開ける状態にする

## 目安

- DesignDoc は組織の template 準拠 (300〜500 行程度)
- 長すぎるなら本文に残す情報を絞る (`guidelines/writing/design-doc-protocol.md` の「削る雑音 10 ルール」参照)

## 適用範囲

- DesignDoc / PR body / issue / Slack / Notion / MR description
- チームで共有される全ての外向き doc
- ai-tools は public repo のため `~/ai-tools/` 内 doc も同様 (個人 path を書かない)

## 参照

- `guidelines/writing/design-doc-protocol.md`
- `rules/public-repo-private-data-block.md`
- `guidelines/writing/external-post.md`
