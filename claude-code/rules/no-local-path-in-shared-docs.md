# 共有 doc に個人ローカルパスを書かない

DesignDoc / PR body / issue 本文 / Slack / Notion などチーム共有 doc に**個人ローカルパス (`~/ghq/...` / `~/Documents/...` / `~/.claude/...` / `/Users/<name>/...`) を書かない**。

## 原則

- 個人 path は他 member から見えず、共有 doc からリンクしても開けない
- 長い内容を「退避 file 参照」で圧縮するのではなく、**本文中に 1 行で統合する**
- 退避が必要なほど詳細が要るなら、組織の共有 doc 領域 (repo 配下 `docs/` / Notion / 内部 wiki) に置いて URL / 相対 path で参照する

## 個人 doc 領域 (local-docs / 個人 Notion) の外部共有禁止

個人マシン上の doc 領域 (local-docs HTML / md、個人 Notion) と、そこから派生する path / URL を外部共有しない (Slack 投稿 / PR コメント貼付 / メール添付 不可)。chat 応答内でも path / URL / 「local-docs にある」表現を提示しない。

- 共有指示を受けても個人 doc の内容を直接コピーしない。共有が必要なら機密除去と推測の検証を経て、共有先向けに別途書き起こす
- doc 作成完了の chat 報告は doc 名 + 1 行要約のみとし、`http://localhost:PORT/...` や `./serve.sh` 等の閲覧手順を添えない
- 外向き text での代替: GitHub issue / PR の URL で参照するか、必要な要旨を本文に転記する
- 個人 doc 配下の相対 link (doc 間の参照) は禁止対象外
- 例外: user が「個人メモと承知の上で参考程度に貼る」と明示した場合のみ共有できる
- draft push 前に、個人 doc の代表 dir 名や project ID pattern を含んでいないか grep で点検する

## 適用範囲

チーム共有される全ての外向き doc (冒頭の列挙と同じ)。ai-tools は public repo なので `~/ai-tools/` 内 doc も同様。

## 参照

- `guidelines/writing/design-doc-protocol.md`
- `guidelines/writing/external-post.md`
- `rules/public-repo-private-data-block.md`
