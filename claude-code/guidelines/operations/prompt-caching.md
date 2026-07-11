# Prompt Caching Guidelines

> **Purpose**: Claude の prompt cache を使って token コストとレスポンス時間を下げる。session 設計と `/clear` タイミングの判断基準として参照する。

## cache が効く範囲

Claude は会話の先頭から連続した「安定部分」を cache する。具体的には次の 3 種類が対象となる。

- **system prompt** (CLAUDE.md / rules / guidelines の注入テキスト)
- **config 注入** (session-start hook が差し込む固定 context)
- **会話の安定 prefix** (session 冒頭の読み取り専用部分)

cache 対象外: ユーザー入力 / assistant 応答 / 途中で変化した system prompt。

## cache 効率を上げる原則

1. **安定したテキストを上に置く** — system prompt や config は会話先頭に集め、変わらない順に並べる。途中で挿入すると cache が壊れる。
2. **context を最小に保つ** — 不要なファイルを Read しない。大きな file を丸ごと読み込むと安定 prefix が短くなり、cache hit 率が下がる。
3. **揺れる部分を末尾に置く** — ユーザー入力 / 動的 context は会話の末尾に集める。先頭側の安定部分に触れなければ cache はそのまま使い続けられる。

## cache TTL と `/clear` 推奨の関係

Claude の cache TTL は **5 分**。5 分以上アイドルになると cache が失効し、次のターンで再構築コストが発生する。

session が長くなると cache_read の累積コストが上昇し続ける。`/clear` の目安は CLAUDE.md § Rewind / Context Management (`>40% → /compact`、`30 分 idle → /clear`) を参照する。

`/clear` を実行した直後は cache が完全にリセットされる。そのため **タスク境界** で `/clear` するのが、再構築コストを最小にする最も効果的なタイミングとなる。

## 失敗パターン

| パターン | 何が起きるか | 対処 |
|---|---|---|
| session 途中で CLAUDE.md を編集 | system prompt が変わり、それ以降の全ターンで cache miss | 編集後に `/clear` で session を切り直す |
| 大量の file を Read しながら会話を続ける | context が膨らみ cache 先頭が短くなる | Read を最小にし、必要な symbol だけ Serena で取得 |
| 5 分超のアイドル後にそのまま続ける | cache が失効しているため再構築コストが発生 | 長時間離席後は `/clear` を検討する |
| 同一 session で複数タスクを連続実行 | タスクごとに context が積み上がり cache_read が肥大化 | タスク完了後に `/clear` でリセットする |
