# jp-fix の file 書き換えは developer-agent 委譲が正規経路

`jp-fix` skill (`skills/jp-fix/SKILL.md`) は `context: fork` + `allowed-tools: Read, Grep` + `disallowed-tools: [Bash, Edit, Write]` と定義されている。これは sandbox の制約ではなく、**意図的な read-only 設計**だ。jp-fix 自身は評価・検出だけを行い、file への実書き込みは行わない。

file 対象の write / rewrite は、`commands/jp-fix.md` の Dynamic Load by Type 表に正規の委譲経路が明記されている。

> file 対象の write / rewrite → `Task(developer-agent)` を 1 発火し、natural-japanese quick 工程 (lint → 判断台帳 → 書き直し → `--baseline` 再 lint) の収束ループを agent 内で完結させる

## 対応

- jp-fix (または同様に `context: fork` + Bash/Edit/Write disallowed な skill) の fork 実行結果が「permission denied で Edit/Write できなかった」と報告してきても、**sandbox 障害と早合点しない**
- まず `commands/jp-fix.md` の該当 skill 定義を Read し、委譲経路 (`Task(developer-agent)` 等) が定義されているか確認する
- 定義されていれば、親からその経路で委譲する。親が直接 Edit で代行するのは正規の分業を無視した工程逸脱になる

## 経緯

`[[2026-07-19]]` 負荷試験レポート (repo 外の個人 doc) の `/jp-fix` 書き換えで fork 結果が Edit/Write denied を報告し、委譲経路を確認せず親が直接編集で完了させた。当初「fork 先は sandboxed working directory 外へ書けない」という誤った原因で on-demand-rule 化したが、`/grill` で jp-fix / commands 双方の定義を読み直した結果、真因は「委譲経路 (`Task(developer-agent)`) を確認せず親が直接介入したこと」と判明し、本 file に訂正した。
