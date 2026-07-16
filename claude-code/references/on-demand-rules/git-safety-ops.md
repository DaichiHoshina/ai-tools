# Git / PR 操作の安全確認 (interrupt / merge 承認 / CODEOWNERS / 他者 comment)

## 他者 comment の編集・削除禁止

GitHub Issue / PR の comment 整理では、自分の comment だけを削除・編集の対象にする。他者の comment を minimize・削除・編集するのは発言権の侵害で、collaboration の信頼を損なう。

- `gh api` 等で comment を操作する前に投稿者を確認し、自分の comment のみ対象にする
- 整理 script を書くときは `--author=@me` 等の絞り込みを必ず付ける
- 他者の情報を統合したいときは、自分の comment に引用・参照する形にする

## interrupt 後の再試行禁止

user が Esc (interrupt) した操作を同 session で explicit approval なしに再試行しない。interrupt は「この操作に疑問あり」の signal だ。

- interrupt 後は理由を確認するか、別 approach を提案する
- 状態変更 (insert / update / delete / deploy) の auto retry を厳禁とする。error 起因の retry とは区別する

## merge 示唆発言 ≠ authorization

user 発言が文脈的に merge を示唆していても、明示的な y/n がなければ `git merge` を実行しない。「〜使えばいい」「〜でやって」は suggestion であって authorization ではない。merge 前に「<src> branch を <dst> branch にマージしてよいですか? (y/n)」を必ず確認する。文脈から merge が明らかに見えても省略しない。

## CODEOWNERS auto-review-request 発火条件

既存 PR branch への push 前に auto-review-request の発火条件を確認し、満たす push は user 承認を取る。

- 発火条件: (1) 差分 500 行以上の push (2) main merge を含む push
- `git diff --stat` で行数を確認してから push を判断する
- N PR への一括 push は事前に件数と内容を明示して承認を待つ
- reviewer の手動 assign 禁止は `ai-output.md` を参照する
