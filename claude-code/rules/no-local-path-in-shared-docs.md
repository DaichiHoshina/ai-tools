# 共有 doc に個人ローカルパスを書かない

DesignDoc / PR body / issue 本文 / Slack / Notion などチーム共有 doc に**個人ローカルパス (`~/ghq/...` / `~/Documents/...` / `~/.claude/...` / `/Users/<name>/...`) を書かない**。

## 原則

- 個人 path は他 member から見えず、共有 doc からリンクしても開けない
- 長い内容を「退避 file 参照」で圧縮するのではなく、**本文中に 1 行で統合する**
- 退避が必要なほど詳細が要るなら、組織の共有 doc 領域 (repo 配下 `docs/` / Notion / 内部 wiki) に置いて URL / 相対 path で参照する

## 適用範囲

DesignDoc / PR body / issue / Slack / Notion / MR description ほかチーム共有される全ての外向き doc。ai-tools は public repo なので `~/ai-tools/` 内 doc も同様。

## 参照

- `guidelines/writing/design-doc-protocol.md`
- `guidelines/writing/external-post.md`
- `rules/public-repo-private-data-block.md`
