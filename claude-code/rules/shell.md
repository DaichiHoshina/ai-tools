---
paths:
  - "**/*.sh"
---
# Shell Script Rules

## Required

- set -euo pipefail
- shellcheck compliant
- Variables quoted as `"${var}"`

## Prohibited

- eval forbidden
- rm -rf / forbidden
- Undefined variable references forbidden

## Recommended

- Refactor into functions for reuse
- Error messages to >&2
- Return appropriate exit codes

## 失敗パターンカタログ

hooks/ の bash 編集で繰り返し踏む落とし穴を 10 件まとめる。shellcheck が検出できる項目も多いが、warn を握り潰す前にこの表で正しい一手を確認する。

| 症状 | ありがちな誤り | 正しい一手 |
|---|---|---|
| quote 漏れによる word splitting | `rm $file` と裸で展開し、space 入り path で分裂する | 常に `"${file}"` と quote する (shellcheck SC2086) |
| set -e が pipeline で効かない | `cmd \| grep x` の cmd 失敗を検知できると思い込む | `set -o pipefail` を併用し、条件は明示的に `if ! cmd; then` で書く |
| pipe while で変数代入が消える | `cmd \| while read -r l; do n=$((n+1)); done` の n が subshell 内で消える | `while read -r l; do ...; done < <(cmd)` と process substitution にする |
| [ と [[ の挙動差で誤判定 | `[ $a == b* ]` で pattern match や `&&` を期待する | bash 専用 script では `[[ ]]` を使い、pattern / regex / `&&` は `[[ ]]` 内で書く |
| local var=$(cmd) で $? が消える | `local out=$(cmd); [ $? -ne 0 ]` が常に 0 になる (local の戻り値を見ている) | `local out; out=$(cmd)` と宣言と代入を分ける (SC2155) |
| glob 0 hit で pattern が生のまま残る | `for f in *.log; do rm "$f"; done` が hit 0 件で `*.log` を処理する | `shopt -s nullglob` を設定するか、loop 内で `[[ -e "$f" ]] || continue` する |
| IFS の一時変更が漏れて後続が壊れる | `IFS=,` を戻し忘れて以降の word splitting が変わる | `IFS=, read -r a b <<< "$line"` と command 単位で局所化する |
| trap EXIT が多重上書きで前の cleanup を消す | 後から `trap '...' EXIT` を書いて既存 handler を潰す | 1 script 1 handler に集約するか、`trap -p EXIT` で既存を取り込んで連結する |
| $(cmd) の末尾改行削除に依存して壊れる | 改行終端の有無を command substitution が保つと思い込む | 末尾改行が意味を持つ data は file / process substitution で受け、比較は `printf` で正規化する |
| 未定義変数で `rm -rf "$VAR/"` が `/` を消す | `set -u` なしで typo した変数を展開する | `set -u` を必須にし、削除系は `rm -rf "${VAR:?VAR is empty}/"` で guard する |
