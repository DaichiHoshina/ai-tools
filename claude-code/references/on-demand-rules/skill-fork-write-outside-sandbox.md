# Skill fork 実行は sandbox 外への write ができない

`jp-fix` / `natural-japanese` 等の skill を Skill tool 経由で呼ぶと "forked execution" として動くことがある。fork 先は親 (メインループ) より狭い permission scope で動き、対象 file が session の sandboxed working directory (起動 repo 配下) の外にある場合、Read は通っても Edit / Write / Bash (書込系) が permission denied になる。

repo 外の個人 doc (`/Users/<name>/...` 直下など) を対象に「わかりやすく書き換えて」等の依頼を skill 経由で受けた場合:

- fork 実行に丸投げせず、**親 (メインループ) が直接 Read/Edit する**
- skill は下請けの助言・lint 実行 (`lint.py` / `outline.py` / `terms.py` 等の read-only 系は fork でも通る) に留める
- 「permission denied で止まった」という報告が skill から返ってきたら、権限昇格を試みず親が引き継ぐ (回避 command を探さない)

## 経緯

`[[2026-07-19]]` 負荷試験レポート (`~/-30474-dev-負荷試験-計画-結果.md`、repo 外の個人 doc) の `/jp-fix` 書き換えで fork 実行が Edit/Write を全て denied され、親が直接編集して完了させた。
