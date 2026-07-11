# 生成 report を repo tracked path に保存しない

`/retrospective` 等の command が生成する HTML report (cost 分析 / churn 分析 等) を `docs/reports/` のような repo 内 tracked path に保存しない。report には session ID / branch 名 / file path が含まれ、commit すると個人識別情報が履歴に永続化する。

- 生成先は `~/.claude/projects/<project>/reports/` など repo 外の path に固定する
- 既存の tracked path がある場合は `.gitignore` に `docs/reports/*.html` を追加する
- report 生成後は `git status` で意図しない HTML が staging に入っていないか確認する
