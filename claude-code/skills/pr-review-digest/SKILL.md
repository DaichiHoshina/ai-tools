---
allowed-tools: Bash, Read, Edit
name: pr-review-digest
description: 自分が作成した PR に対する他者レビューコメント集約 HTML を日次で追記する。「pr レビュー集約」「my-pr-review 更新」「PR コメント digest」で起動。
---

# pr-review-digest

`local-docs/operations/pr-review-comments/*.html` 形式の集約 doc を日次更新する汎用 skill。前回集計日から今日までに追加された「他者からの新着レビューコメント」を該当 PR block の末尾に **単純追記** する。件数集計・block 再構成はしない (数字表示は撤廃済み方針)。

## 前提

- **実 config は private file から読む**: `~/.claude/references-private/pr-review-digest.env`
  ```bash
  TARGET_REPO=<owner>/<repo>            # 例: acme/monorepo
  AUTHOR=<gh-username>                  # 対象 PR author
  TARGET_DOC_GLOB=<abs-path-glob>       # 集約 HTML の glob (最新 1 件を採用)
  ```
  file が無い場合は user に作成を促して abort する。skill 本体 (public repo に置く) には社名・repo 名・user 名を書かない。

- 除外 user: `coderabbitai` / `Copilot` / `copilot-pull-request-reviewer` / `github-actions` / `dependabot` / `datadog` / `${AUTHOR}` (env の値、本人)
- 除外 body: `LGTM!` 単独 / `![LGTM](...)` 単独 / `コメントしました[！]?` 単独 / `レビューしました[！]?` 単独。**本文が続くもの (「LGTM! + 補足…」等) は残す**

## Flow

### Step 0. config load

```bash
CONF=~/.claude/references-private/pr-review-digest.env
[ -f "$CONF" ] || { echo "config not found: $CONF"; exit 1; }
set -a; source "$CONF"; set +a
```

### Step 1. snapshot

実行前に現行 file を archive dir にコピーする (rollback 用)。

```bash
# glob は eval 経由で展開する (source した env 変数の * は自動展開されない)
DOC=$(eval ls -t "$TARGET_DOC_GLOB" 2>/dev/null | head -1)
[ -n "$DOC" ] && [ -f "$DOC" ] || { echo "no doc matched: $TARGET_DOC_GLOB"; exit 1; }
ARCHIVE=$(dirname "$DOC")/_archive
mkdir -p "$ARCHIVE"
cp "$DOC" "$ARCHIVE/$(basename "$DOC" .html)-$(date +%Y%m%d-%H%M%S).html"
```

### Step 2. since 日付を決める

`<!-- data-window: YYYY-MM-DD/YYYY-MM-DD -->` の右辺 + 1 日を since とする。無ければ `<!-- updated: -->` を fallback、それも無ければ user に聞く。

```bash
SINCE=$(grep -oE 'data-window: [0-9-]+/[0-9-]+' "$DOC" | awk -F/ '{print $2}')
# macOS (BSD date) 前提。Linux (GNU date) で回す場合は `date -d "$SINCE + 1 day" +...` に置換する
SINCE_ISO=$(date -j -v+1d -f "%Y-%m-%d" "$SINCE" +%Y-%m-%dT00:00:00Z)
TODAY=$(date +%Y-%m-%d)
```

### Step 3. 対象 PR 抽出

```bash
gh api "search/issues?q=repo:${TARGET_REPO}+is:pr+author:${AUTHOR}+updated:>=$SINCE&per_page=100" \
  | jq -r '.items[].number' | sort -n > /tmp/pr_review_digest_prs.txt
```

### Step 4. 各 PR の新規コメント fetch (並列)

各 PR について 3 endpoint を叩き、bot / 本人除外 + since 絞り + 挨拶単独除外を jq で適用する。

```bash
EXCLUDE_USERS="coderabbitai|Copilot|copilot-pull-request-reviewer|github-actions|dependabot|datadog|${AUTHOR}"
JQ_EXCLUDE_USER="select(.user.login | test(\"^(${EXCLUDE_USERS})\$\") | not)"
JQ_EXCLUDE_FILLER='select((.body // "") | test("^(LGTM!?|!\\[LGTM\\]\\(https?://[^)]+\\)|コメントしました！?|レビューしました！?)\\s*$") | not)'

for pr in $(cat /tmp/pr_review_digest_prs.txt); do
  {
    gh api "repos/${TARGET_REPO}/pulls/${pr}/comments?per_page=100" --paginate 2>/dev/null \
      | jq --arg s "$SINCE_ISO" "[.[] | select(.created_at >= \$s) | $JQ_EXCLUDE_USER | $JQ_EXCLUDE_FILLER | {kind:\"inline\", user:.user.login, path:.path, line:.line, created_at:.created_at, body:.body}]" > /tmp/pr_${pr}_inline.json &
    gh api "repos/${TARGET_REPO}/issues/${pr}/comments?per_page=100" --paginate 2>/dev/null \
      | jq --arg s "$SINCE_ISO" "[.[] | select(.created_at >= \$s) | $JQ_EXCLUDE_USER | $JQ_EXCLUDE_FILLER | {kind:\"thread\", user:.user.login, created_at:.created_at, body:.body}]" > /tmp/pr_${pr}_thread.json &
    gh api "repos/${TARGET_REPO}/pulls/${pr}/reviews?per_page=100" --paginate 2>/dev/null \
      | jq --arg s "$SINCE_ISO" "[.[] | select(.submitted_at >= \$s) | select((.body // \"\") != \"\") | $JQ_EXCLUDE_USER | $JQ_EXCLUDE_FILLER | {kind:\"summary\", user:.user.login, state:.state, created_at:.submitted_at, body:.body}]" > /tmp/pr_${pr}_summary.json &
    wait
  }
done
```

### Step 5. 追記位置決定と Edit

各 PR block を `<summary><strong>PR #${pr}</strong>` で検索し、`</details>` の 1 行手前に li を追加する。追加 li の HTML 雛形:

- **inline**: `<li><strong>${user}</strong> <code>${path}:${line}</code> <span class="ts">${date}</span><br>${body_html}</li>`
- **thread**: `<li><strong>${user}</strong> <span class="ts">${date}</span><br>${body_html}</li>`
- **summary APPROVED**: `<li><span class="lbl lbl-ok">APPROVED</span> <strong>${user}</strong> <span class="ts">${date}</span><br>${body_html}</li>`
- **summary COMMENTED**: `<li><span class="lbl lbl-note">COMMENTED</span> <strong>${user}</strong> <span class="ts">${date}</span><br>${body_html}</li>`

該当 PR block が存在しない場合:

- 「人間レビュアーコメント 0 件の PR」list にあれば削除して、新 details block を追加する
- 無ければ「新規 PR」として `<h2>` "PR 別コメント一覧" 直下の `<p>...</p>` の直後に details block を挿入する

body HTML 変換: 改行 `\n` → `<br>`。URL / user @ mention はテキスト保持。markdown 記法は無変換。

**単純追記原則**: 既存 li の再配置・件数再計算・block 順序変更はしない。既存 h4 セクション (`<h4>inline review comments</h4>`) が該当 PR に無ければ、新 h4 + ul を `</details>` 直前に差し込む。

### Step 6. metadata 更新

- `<!-- updated: -->` を今日の日付に
- `<!-- data-window: -->` の右辺を今日の日付に
- リード文の「データ取得日は YYYY-MM-DD。」を今日の日付に

### Step 7. CSS/JS path check

追記後、shared CSS/JS の相対 path が生きているか grep で確認する。修正はしない (書き換えると他 doc への波及リスク、警告のみ出す)。

### Step 8. build

```bash
cd "$(dirname "$DOC")/../.."
/usr/bin/env -i HOME="$HOME" PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" node _index/build.mjs
```

exit 0 で done。fail 時は Step 1 の snapshot から差し替えて調査する。

## 出力

- 更新した file path
- 追記した PR 番号と件数の 1 行 summary (chat log 用、doc 本体には数字を書かない)
- fail 時: snapshot path + error 内容

## Failure Handling

| Situation | Behavior |
|---|---|
| config file 不在 | 上記 env のひな型を提示して abort |
| gh auth 失効 | user に `gh auth login` を促して abort |
| 対象 doc が glob で 0 件 | 「初回作成は手動で」と促して abort (本 skill は追記専用) |
| gh api rate limit | 5 分待って 1 回だけ retry |
| build.mjs fail | snapshot から restore + user escalate |

## Notes

- 集計数値 (「計 N 件」「レビュアー別 table」) は書かない (user 決定)
- CSS/JS 相対 path は doc の階層で変わる。skill 側で自動修正しない
- 挨拶除外 regex は本文完全一致のみ。前後空白は許容、他文字が混じれば残す
- 実 config は `~/.claude/references-private/pr-review-digest.env`。本 skill file (public repo) には固有名詞を書かない (canonical: CLAUDE.md `Public-repo private-data block`)
