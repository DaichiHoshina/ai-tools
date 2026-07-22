# macOS shell / bats / launchd の罠

hook script / test / launchd LaunchAgent を書く時に読む。macOS BSD 環境と bash 3.2 前提の落とし穴を集約した。

## 1. macOS launchd は sleep 中に発火しない

macOS の launchd `StartCalendarInterval` job は sleep 中に発火せず、wake 時に 1 回だけ遅延実行される。skip されるのは電源 off の時だけ。

**How to apply**: 定刻発火が要る夜間 job には `sudo pmset repeat wakeorpoweron <days> <HH:MM:SS>` の自動 wake と、wake 直後に `caffeinate -s -t <sec>` を回す LaunchAgent (ai-tools では `com.claude.night-caffeinate`) をセットで使う。`caffeinate -s` は AC 電源時のみ有効で、バッテリー + 蓋閉じでは効かない。

## 2. launchd は sleep 中の予定を wake 時に catch-up する (skip は電源 off のみ)

`StartCalendarInterval` は cron と違い、Mac sleep 中に到達した予定を wake 時にまとめて 1 回実行する。cron / systemd timer の類推で「PC sleep 中は skip される」と誤認しない。実挙動確認は `pmset -g log` でできる。

**How to apply**: launchd の StartCalendarInterval を使う LaunchAgent を書く時、sleep 対策の catch-up 機構を追加で作らない。夜間 job (02:03 発火想定) が PC 閉じてる時間帯にあっても、翌朝 wake で 1 回 fire する前提で設計する。launchd 触る前に類推で判断しない。

## 3. macOS BSD awk は `-F' \| '` を空白 split に degrade する

pipe 区切り log を macOS BSD awk で読むとき、field separator に `-F' \| '` を渡すと FS が空白 split に degrade する。実測で NF が期待の 4 から 7/9/11/29 に化ける。GNU awk は `\|` を扱えるが portability を優先し、必ず文字クラス `-F' [|] '` を使う。

**Why**: 2026-07-20 の rule-recall-surface Task 3 で metric が n=0 c100=空 ck=空 を返した。同じ FS を Task 2 fix にも使っていたが grep 併用で偶然動いていた。壊れた $3 でも substring match が拾う fragile state だった。

**How to apply**: hook / cron script / metric TSV command / log 集計 shell で `awk -F' \| '` を書きそうになったら `awk -F' [|] '` に置き換える。grep 併用で見た目動く場合も fragile なので同時に直す。

## 4. bats の `! grep` は非最終行だと fail を握りつぶす

bats test で `! grep -q PATTERN FILE` を否定 assertion として使うとき、その行が test 関数の最終行でないと fail が握りつぶされる。原因は bash の `set -e + !` の相互作用で、`!` で否定した command の失敗は early-exit の対象外になる仕様。最終行だけが test の verdict を決めるため、bug 検出行が先・trivial に真の行が後の並びだと regression guard として機能しない。

**Why**: 2026-07-20 の rule-recall-followup で発覚。reviewer が base commit に checkout して test 9 を単独実行し、bug が再現しているのに ok を返すことを empirical に示した。同 pattern を持つ既存 test 3 にも同じ穴があった。

**How to apply**: bats の否定 assertion は `run cmd; [ "$status" -ne 0 ]` 形式で書く。既存 `! grep -q` を見つけたら同時に書き換える。単発 `! grep` (最終行 1 行だけ) は正しく fail 化されるため必ずしも書き換え不要だが、複数 assertion がある関数では例外なく `run + status` に統一する。参照実装: `tests/integration/rule-recall-surface.bats` の test 3/9。

## 5. bats を worktree cwd で実行すると cwd-guard で 38 本が偽 fail する

ai-tools の hook test (`bats -r tests/unit/hooks/`) を `.claude/worktrees/<name>/` 配下の cwd から実行すると、`hooks/lib/write-checkers.sh` の cwd-guard (worktree session 中の worktree 外 path Edit を Forbidden にする機能) が `/tmp` path を使う Edit 系 test で発火し、38 本が偽 fail する (2026-07-16 の pretooluse-split loop で実踏)。

**Why**: cwd-guard は `CLAUDE_PROJECT_DIR` (無ければ `pwd`) が `*/.claude/worktrees/*` に一致すると worktree session と判定する。test helper は cwd を変えないため、worktree 内から回した bats がそのまま guard 対象になる。

**How to apply**:
1. worktree 内で bats を回すときは `CLAUDE_PROJECT_DIR=$HOME/ghq/github.com/DaichiHoshina/ai-tools bats -r tests/unit/hooks/` で guard を回避する
2. `/loop` の gate command を worktree 起点にする場合も同じ env を gate に含める。含めないと gate が永遠に FAIL し、maker が無駄 iteration で cost を焼く
3. gate green 判定を pipeline (`bats ... | tail`) で見ない。pipe の exit は tail のものになるため `bats ...; echo $?` か `&&` 連鎖の位置で確かめる

## 6. Claude Code CLI は Bash tool 実行に /bin/bash (3.2) を hardcode する

Claude Code CLI (`~/.local/share/claude/versions/<ver>`) は Bash tool 実行 shell として `/bin/bash` を hardcode する。macOS 標準 bash は 3.2 で `declare -A` 等の bash 4+ 構文を通さない。

**Why**: foreground session ではまだ問題が顕在化していなかったが、launchd 経由の headless `claude -p` で jp-quality lib の `declare -A` が全 tool block を起こし判明した。PATH 側で bash 4+ を先に置いても Bash tool の shell 選択は CLI 内部制御で覆せない。

**How to apply**: hook / lib で bash 4+ 構文を使う時は、hook 冒頭で `[[ BASH_VERSINFO[0] -lt 4 ]]` を検知して `/opt/homebrew/bin/bash` に `exec` 切替する guard を置く。`_JP_HOOK_BASH_UPGRADED=1` 等の env で無限 loop 防止。source される lib file は shebang が効かないため、source 側 (入口 hook) で切替する。canonical impl: `hooks/pre-tool-use.sh` 冒頭。

## 関連

- `references/on-demand-rules/hook-implementation-pitfalls.md` — hook 実装全般の罠
- `references/on-demand-rules/bash-tool-environment.md` — Bash tool の環境制約
- `references/bats-test-writing.md` — bats test 書き方
