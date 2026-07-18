# Hook 実装の罠集

`hooks/*.sh` の新規実装・logic 追加・NG list 変更の前に読む。latency baseline 計測は `measure-before-hook-change.md` が canonical で、本 file は実装内容側の罠を扱う。

## 罠 1: NG list (PRINCIPLES.md) 追加時の 3 罠

2026-06-04 session で新 NG list 追加時に 3 連続で失敗した実績から手順を固定した。

### 1-A. `〜` prefix 付き literal は `grep -qF` で match しない

`hooks/pre-tool-use.sh:_check_term_list` は fixed-string match (`grep -qF`)。literal に `〜かもしれない` と書くと、text 側に `〜` (U+301C) が無いため match 0 で block が発火しない。list には prefix なしの素 literal (`かもしれない`) を書く。既存 list は元から prefix なしで、新 list だけ説明文の感覚で `〜` を付けてしまうのが罠だ。

### 1-B. commit message 本文に NG literal を直書きすると自己 block する

allowlist は `~/ai-tools/` 配下 file 編集のみで、commit message は対象外。commit body には literal を書かず「推測語 4 種を block する (list は PRINCIPLES.md の該当 section)」のように抽象表現 + file 参照へ逃がす。

### 1-C. sync to-local を忘れると全 commit / gh / Slack MCP が blocked になる

hook は sync 先 (`~/.claude/`) の `hooks/pre-tool-use.sh` が同じ sync 先の PRINCIPLES.md から list を動的抽出する。source 編集後に sync していないと `_assert_required_keys` が exit 2 (loud fail) で後続操作を全部止める。`./claude-code/sync.sh to-local --yes` で反映する (`--yes` 必須)。

### 1-D. 新 NG literal 追加前に git log を確認する

`git log --all --oneline | grep -F '<term>'` で既存 commit に同 literal が含まれていないか確かめる。push 済 commit を hook は block しないが、影響範囲の判断に要る。

### canonical 手順 (5 step)

1. PRINCIPLES.md の NG 辞書 section に `**<name> (block)**: <素 literal>` を追加する (`〜` prefix なし)
2. hook を編集する: `required_keys` / `_inject_keys` / `_block_if_ai_jargon` の 3 箇所 (既存 category を手本にする)
3. `./claude-code/sync.sh to-local --yes` で反映する
4. block test: `echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"<NG literal>\""}}' | ~/.claude/hooks/pre-tool-use.sh; echo "exit=$?"` で exit=2、通常 message で exit=0 を確かめる
5. commit + push: body に literal を直書きせず file path 参照に逃がす

## 罠 2: session_id は stdin JSON から取る (env は leak する)

Claude Code は session_id を env でなく **stdin JSON** で hook に渡す。`${CLAUDE_SESSION_ID:-$$}` のような env 参照は空 fallback で bash PID になり、`/tmp/claude-session-*` 系 flag file が絶対 hit しない silent bug になる (2026-06 commit `775f842` で発生、`4265e10` で修正)。env `CLAUDE_CODE_SESSION_ID` を優先する逆 pattern も hook 7 file で再発した (env は session 切替時に前 session の値が leak する、incident 2026-06-25)。

- 必ず `SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")` で stdin から抽出する
- flag file path は `/tmp/claude-hook-<hook-name>-${SESSION_ID}` で session 粒度にする
- 参照実装: `hooks/session-start.sh` / `hooks/post-tool-use.sh`
- `tests/unit/hooks/session-id-stdin-priority.bats` が env 優先代入を grep 検出する。新 hook 追加でこの bats が RED になったら stdin 優先に直す
- smoke test: hook 手動発火 → `/tmp/claude-hook-*` 作成確認 → 2 回目で skip 確認

## 罠 3: git commit の option 判定は word-boundary 正規表現にする

substring 判定 (`[[ "$COMMAND" != *"-m"* ]]`) は `--message` が `-m` を部分文字列に含むため誤マッチする。2026-06-14 `e8af1de` でこの罠により `git commit --amend --message='...'` が block も warn もされず NG 語がすり抜けた。

- word-boundary regex を使う: `=~ (^|[[:space:]])(-m|-F|--message|--file)([[:space:]=]|$)`
- 本文抽出側も short / long / `=` 区切りの全形式に対応させる。抽出と warn 抑止が両方すり抜けると安全網が消える
- test には long form と `=` 区切りを必ず含める
- 注: `git commit -F=file` は git 自体が fatal で弾くため block 不要 (`gh --body-file=` とは挙動が別)

NG 語 canonical は `guidelines/writing/NG-DICTIONARY.md`。

## 罠 4: 存在チェックは引数付き command から `${cmd%% *}` で実行 file を剥がす

settings.json の `command` field は `hook.sh cleanup` のような引数付き形式を取る。丸ごと `-f` チェックすると存在しない path を評価して false-positive になる (2026-05-17 に `session-start.sh` の診断で「not found」誤診断 4 件、`5dc6c1d` で修正)。`[ -f "${cmd%% *}" ]` のように引数を除去してから確認する。

## 罠 5: 文体違反の再発は rule 追記で止まらない、block 昇格が構造対応

「完了」多用など文体違反の再発に対して、rule / CLAUDE.md への規範追記は効かないことが実測で確定している (rule 追加翌日から同 pattern 復活、7 日累積 warn は増加)。warn は systemMessage で user にしか見えず AI に届かない (7 日で block 79 件 vs warn 1850 件)。block だけが AI に書き直しを強制する feedback loop になる。

- 文体・出力品質の改善依頼が来たら、規範 file の追記より先に `lib/jp-quality/block-checks.sh:_chat_quality_check` の block 対象昇格を検討する
- warn を次 turn へ届けたい場合は `/tmp/claude-stop-jpq-warn-*` 経由の additionalContext 還流を使う (commit `a3c1485`)
- 誤爆が多い検査 (断定語「完了」、連続漢字) は block にしない。loop 上限 5 を浪費して機構全体が log-only へ降格する

## 罠 6: 語彙 denylist は意味を判定できない、量 gate が構造対応

NG 語ゼロ + 常体で閉じた What 言い換え comment は文字列照合を必ず通過する (2026-07-18 実測)。意味の判定を hook でやろうとせず、量 (新規日本語 comment の行数上限) を機械強制する方が構造対応になる。参照実装: `lib/comment-style-checker.sh` の comment 量 gate。

## 罠 7: checker 自己改修中の stale warn はノイズ

worktree で checker 自体を改修している間は、sync 前の古い live checker が新規範では正しい行 (動詞終止・動詞 + 閉じ括弧等) に warn を出し続ける (2026-07-18 実踏)。この warn は sync 後に消えるため、1 件ずつ追わず「新 checker で判定し直して本物だけ直す」で切り分ける。

## 関連

- `measure-before-hook-change.md` — hook 編集前の latency baseline 計測
- `guidelines/writing/NG-DICTIONARY.md` / `guidelines/writing/PRINCIPLES.md` — NG 語 canonical
- `CLAUDE.repo.md` "## Hook 編集 baseline rule"
