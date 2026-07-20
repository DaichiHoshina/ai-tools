# CI 完了を inline で待たない

`gh pr checks` / build / deploy 等、外部レイテンシで結果が変わらない待ち処理を inline (foreground の `sleep` ポーリング) で回さない。turn を数十分専有し、user は他の指示を出せなくなる。

## How to apply

- push 後は「push した。CI は `gh pr checks <PR>` で確認できる」と 1 行報告して turn を終える
- 監視が必要なときは Bash tool の `run_in_background: true` で回し、通知が来たら結果を報告する
- foreground の `sleep` で background 完了を待つのも同罪 (turn 専有) なので行わない
- user が CI 結果を求めたら、その時点の状態を 1 回だけ取得して報告する

## 例外

- 完了確認が実装の次工程で必要 (test 結果を待って fix する 等) で、background で待てない場合のみ短い sleep (1-2 分上限) を許容する
- その場合も「n 分待つ」と事前に予告して turn の見通しを共有する

## 関連

- `rules/thinking-principles.md` §「turn を完結させて終える」— 待ちのために turn を止めない
- `references/session-efficiency-detailed.md` — turn 内 token cost の考え方
