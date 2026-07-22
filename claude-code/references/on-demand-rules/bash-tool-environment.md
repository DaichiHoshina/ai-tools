# Bash tool / macOS 環境の制約

Claude Code Bash tool から shell command を実行する時、および Mac 環境の disk / node / sudo 起因の失敗に遭遇した時に読む。

## 1. sudo が使えない (! bash-input 経路)

Claude Code の `!` bash-input は非対話実行のため、sudo が「a terminal is required to read the password」で失敗する。

**How to apply**: sudo が要る操作は最初から「普通の Terminal で直接実行してほしい」と案内する。実行後に session 側で結果 (`pmset -g sched` 等) を読んで検証する。

## 2. cwd project 外の mutation 系 command は deny される

Bash tool は cwd project の**外**にある git repo で mutation 系 (`git rm` / `git add` / `git stash drop` 等) を実行しようとすると permission deny する。2026-07-15 に `~/ghq/github.com/oraios/serena` の rebase autostash conflict resolve を試みた際、`git add` / `git rm` / `git stash drop` の全てが deny された。read-only (`git status` / `git log`) は通る。

**Why**: Claude Code の permission 判定は tool 側で cwd と operation の関係を評価し、project 境界外の state 変更を安全策で block する。`--add-dir` を渡していない外部 dir は auto-accept 対象外。

**How to apply**: `/serena-update-fix` `/claude-update-fix` 等で外部 clone の git 操作が必要な時は、mutation を試す前に「Bash が deny する前提」で計画する。detect → user manual command block を chat に出して手動対応を依頼する形が最短。read-only な情報収集 (`git log` / `git status` / `git tag`) は Bash で完結できる。

## 3. disk full だと Bash tool が完全停止する

Claude Code の Bash tool は呼び出しごとに `/private/tmp/claude-502/<session>/tasks/<id>/` を作成する。Mac の Data volume が満杯 (2026-07-17 実測: 残 130MB) だと `ENOSPC: no space left on device, mkdir '/private/tmp/claude-502/...'` で全 Bash 呼び出しが失敗する。df / du / rm すら実行できない。

**Why**: tool の作業 dir 作成は harness の必須 setup で、skip 経路がない。Read/Edit/Write は動くが、調査・削除の主力である Bash が完全停止する。

**How to apply**:
- disk full の相談を受けたら最初に `df -h /` で空き確認。残 <1GB なら user 側 terminal で先に空きを作ってもらう
- 依頼する 1 発 command は「大物候補削除 + df 表示」に絞る。例: `rm -rf ~/Library/Developer/Xcode/DerivedData/* ~/Library/Caches/* 2>/dev/null; df -h /`
- 数 GB 空いたら以降は tool 側で調査 → 削除に切り替えられる

## 4. Docker Desktop for Mac は 100GB 級に肥る (disk 逼迫の第一容疑)

Docker Desktop for Mac の `~/Library/Containers/com.docker.docker` は container/image/volume の実データ置き場で、prune せず使い続けると単独で 100GB 級に肥れる (2026-07-17 実測: 105GB、Mac 全体 189GB Library の 55%)。

**Why**: Docker Desktop は raw disk image (Virtualization.framework) を確保する方式で、image/container/volume を削除しても disk image は自動縮小しない。`docker system prune -a --volumes` で内部を消してから、必要なら Preferences > Resources > Advanced で disk image size 上限を下げると実 disk へ反映される。

**How to apply**:
- Mac disk 逼迫時は `du -sh ~/Library/Containers/*` で最初に Docker を疑う
- 定期 cleanup: 月 1 で `docker system prune -a --volumes -f` (2026-07-17 は 20.3GB 回収)
- 恒久対策として Docker Desktop の disk image size 上限を実使用量+20GB 程度に絞る運用を検討する

## 5. node / npm / pnpm は _load_nvm 未展開で silent fail する

Claude Code Bash tool は `.zshrc` を最小限しか読まないためか、`node` / `npm` / `pnpm` 等が zsh function として lazy load 定義されているのに `_load_nvm` 本体が未定義で「command not found: _load_nvm」を連発して exit 0 で沈黙する。

**Why**: 2026-07-21 snkr.com/local-docs の `node _index/build.mjs` 実行時に発生。exit 0 で成功したように見えたが index 未更新。`which node` で `node () { _load_nvm; node "$@" }` が判明した。

**How to apply**:
- Bash tool から node / npm / pnpm を叩く前に `source ~/.zshrc 2>/dev/null;` を prefix する
- exit code 0 でも「_load_nvm not found」warn が並んでいたら実 command は走っていない
- 恒久対策として build script 側で PATH 直指定するのが本命だが、まずは source prefix で回避

## 関連

- `references/on-demand-rules/gh-api-pitfalls.md` — gh api 経由 jq の control char 罠
- `rules/shell.md` — shell 一般の書き方
