# Shell snapshot が rc を上書きする挙動

Claude Code の Bash tool は起動時にシェル環境を `~/.claude/shell-snapshots/snapshot-zsh-<ts>-<id>.sh` へ焼き込み、以降の各 Bash 呼び出しはこの snapshot を source する。`~/.zshrc` (や `.bashrc`) を編集しても**現行セッションには即時反映されない**。snapshot は次回 Claude 起動時に再生成される。

## 環境判定の軸

snapshot 実行時の環境は以下のため、非対話判定に `interactive` / tty を使うと空振りする。

| 変数 | snapshot 実行時の値 |
|------|--------------------|
| `[[ -o interactive ]]` | N (非対話) |
| `[ -t 1 ]` (stdout tty) | N |
| `$CLAUDECODE` | `1` |
| `$CI` | 空 |

→ Claude Bash tool を判別する信頼できる軸は **`CLAUDECODE`** のみ。`ls` 等の alias は snapshot 内で展開済 (例: 素の `ls` が `ls -GF` で焼き込まれる)。

## rc の挙動を即時直す手順

1. `~/.zshrc` を修正する (恒久。次回起動の新 snapshot に反映)
2. 現行 snapshot を特定し同じ修正を当てる (即時反映): `grep -ln "<pattern>" ~/.claude/shell-snapshots/*.sh`
3. 古い snapshot は過去セッション用で今後 source されない。削除してよい

## ハマりどころ

- `[[ cond ]] && cmd` を関数末尾に置くと cond false 時に関数が exit 1 を返す。末尾に `return 0` を補う
- `env` / `printenv` 単体は secret 保護 hook で deny される。rc / snapshot 内の `$VAR` 参照は実行時評価のため hook を通らない

## 典型例

`cd(){ builtin cd "$@" && ls }` のような rc 関数は、cd ごとに移動先の `ls` を全 Bash 出力先頭へ混入させる。`[[ -z "$CLAUDECODE" && -z "$CI" ]] && ls` でガードし末尾に `return 0` を付けると、対話シェルでは従来どおり動作しつつ Claude / CI 環境ではノイズを抑止できる。
