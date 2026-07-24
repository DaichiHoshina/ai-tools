---
allowed-tools: Bash, Read, Edit
name: pr-comments-by-reviewer
description: 指定 reviewer が特定 scope の PR に書いたコメントを抽出し local-docs HTML に集約する。「rinchsan と kojima のオリパ review 集めて」「reviewer 別コメント抽出」で起動。read-only 収集 + 追記のみ。
---

# pr-comments-by-reviewer

指定した複数 reviewer が、特定 scope (title keyword / label / path) の PR に書いた review コメントを 1 年分まとめて抽出し、local-docs の集約 HTML に追記する。既存 doc の視点は「自分の PR に付いたコメント」だが、本 skill は「特定 reviewer 視点でのコメント収集」で reviewer 別セクションを増設する。

## 用途の切り分け

| skill | 視点 | 追記単位 |
|---|---|---|
| `pr-review-digest` | 自分の PR に他者が付けたコメント | PR block に日次追記 |
| `pr-comments-by-reviewer` (本 skill) | 指定 reviewer が書いた全コメント (誰の PR かは問わない) | reviewer 別 section を新設 or 更新 |
| `review-member` | reviewer 傾向を lens 化して自分の diff を pre-check | 出力 = chat のみ、doc 更新なし |

review-member の lens base data を更新するときの source data 収集にも本 skill を使う。

## 前提

- **config**: `~/.claude/references-private/pr-review-digest.env` を流用する (`TARGET_REPO` と `TARGET_DOC_GLOB` のみ参照、`AUTHOR` は無視)
- **除外 body**: 本文が空 / `LGTM!` / `👍` / `Approve[dsぐ]` / `了解[です]?` / `確認しました` / `コメントしました[！]?` / `OK[です]?` の完全一致のみ (本文が続けば残す)
- **除外 user**: bot 全般 (`coderabbitai` / `Copilot` / `copilot-pull-request-reviewer` / `github-actions` / `dependabot` / `datadog`)

## Input

引数から以下を取得する。欠落時の default は下記の通り。

| 引数 | 例 | default |
|---|---|---|
| `--reviewers` | `rinchsan,takanorikojima-star` | 必須 (未指定なら user に聞く) |
| `--scope` | `オリパ\|oripa` (title regex、パイプは `\|` でエスケープ) | 必須 (未指定なら user に聞く) |
| `--scope-files` | `oripa` (changed files 正規表現) | `--scope` と同じ値 (fallback) |
| `--since` | `2026-01-01` | 今年 1/1 |
| `--until` | `2026-12-31` | 今年 12/31 |
| `--doc` | HTML 絶対 path | `TARGET_DOC_GLOB` の最新 1 件 |
| `--include-files-check` | (flag) | title 非マッチ PR も changed files 走査で救う (時間 3x) |

**doc 更新方針**: 常に既存 doc への追記 (append) のみ。新規 doc 作成は本 skill の対象外 (local-docs skill の hard rule で HTML 直書きは `_templates/{type}.html` から `cp` する規約があるため)。初回は `local-docs` skill で先に空 doc を作り、以降本 skill で追記する。

**自然言語 trigger**: 「rinchsan と kojima のオリパ review 集めて」→ `--reviewers=rinchsan,takanorikojima-star --scope='オリパ|oripa' --include-files-check` と解釈する。人名の handle 解決は org member 検索で行う (下記 Step 1)。

## Flow

### Step 0. config load + handle 解決

```bash
CONF=~/.claude/references-private/pr-review-digest.env
[ -f "$CONF" ] || { echo "config not found: $CONF"; exit 1; }
set -a; source "$CONF"; set +a
```

reviewer 名が姓 (`kojima` / `小島` 等) で org member 表記と異なる可能性がある。org member から候補を引く:

```bash
resolve_handle() {
  local name="$1"
  # 完全一致優先
  if gh api "users/${name}" >/dev/null 2>&1; then
    echo "$name"; return
  fi
  # org member から曖昧一致 (要 org read scope)
  local org="${TARGET_REPO%%/*}"
  gh api "orgs/${org}/members?per_page=100" --paginate --jq '.[].login' 2>/dev/null \
    | grep -i "$name" | head -1
}
```

candidate が 0 件 or 2 件以上なら user に確認する (推奨即決 rule の例外: 誤 reviewer 収集は無駄仕事が大きい)。

### Step 0.5. 引数を shell 変数に展開

skill 起動時の引数を bash 変数に落とす。以降の Step は全てこの変数を参照する。

```bash
# Claude が呼ぶときは以下 5 変数を事前設定してから Step 1 へ進む
REVIEWERS="rinchsan,takanorikojima-star"   # --reviewers (カンマ区切り)
SCOPE="オリパ|oripa"                       # --scope (title regex)
SCOPE_FILES="oripa"                        # --scope-files (未指定は $SCOPE を継承)
SINCE="2026-01-01"                         # --since (default: 今年 1/1)
UNTIL="2026-12-31"                         # --until (default: 今年 12/31)
DOC=$(eval ls -t "$TARGET_DOC_GLOB" 2>/dev/null | head -1)   # --doc (未指定は glob 最新)
INCLUDE_FILES_CHECK=0                       # --include-files-check flag (1 で有効)

TARGETS_JSON=$(printf '%s' "$REVIEWERS" | jq -R 'split(",")')   # jq --argjson TARGETS 用
OWNER="${TARGET_REPO%%/*}"
REPO="${TARGET_REPO##*/}"
```

### Step 1. PR list 取得

```bash
WORK=$(mktemp -d)
for u in ${REVIEWERS//,/ }; do
  gh search prs --repo "$TARGET_REPO" --reviewed-by "$u" \
    --created "${SINCE}..${UNTIL}" --limit 200 \
    --json number,title,state,createdAt,url,author \
    > "$WORK/prs-${u}.json"
done

# union + scope filter (title regex)
jq -s --arg re "$SCOPE" '
  add | unique_by(.number)
  | map(select(.title | test($re; "i")))
  | sort_by(-.number)
' "$WORK"/prs-*.json > "$WORK/scope-prs.json"
jq -r '.[].number' "$WORK/scope-prs.json" > "$WORK/pr-numbers.txt"
```

`--include-files-check` = 1 のときは title 非マッチ PR を changed files で救う:

```bash
if [ "$INCLUDE_FILES_CHECK" = "1" ]; then
  # union 全体から title マッチを除いた残りを走査
  jq -s '(add | unique_by(.number)) - (input | map(.))' \
    "$WORK"/prs-*.json "$WORK/scope-prs.json" \
    | jq -r '.[].number' > "$WORK/need-file-check.txt"
  > "$WORK/extra-prs.txt"
  cat "$WORK/need-file-check.txt" | xargs -P 8 -I {} sh -c '
    files=$(gh pr view {} --repo '"$TARGET_REPO"' --json files --jq ".files[].path" 2>/dev/null)
    if echo "$files" | grep -qiE "'"$SCOPE_FILES"'"; then
      echo {} >> "'"$WORK"'/extra-prs.txt"
    fi
  '
  cat "$WORK/extra-prs.txt" >> "$WORK/pr-numbers.txt"
  sort -u "$WORK/pr-numbers.txt" -o "$WORK/pr-numbers.txt"
fi
```

### Step 2. review コメント bulk fetch (GraphQL)

各 PR につき 1 query で reviews + reviewComments + issueComments をまとめて取得する。`$OWNER` / `$REPO` は Step 0.5 で split 済:

```bash
mkdir -p "$WORK/reviews"
QUERY='query($pr: Int!, $owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      number title url state createdAt
      author { login }
      reviews(first: 100) {
        nodes {
          author { login } state submittedAt body
          comments(first: 100) {
            nodes { author { login } path line originalLine body createdAt url }
          }
        }
      }
      comments(first: 100) {
        nodes { author { login } body createdAt url }
      }
    }
  }
}'

cat "$WORK/pr-numbers.txt" | xargs -P 6 -I {} sh -c '
  gh api graphql -f query="'"$QUERY"'" \
    -F pr={} -f owner="'"$OWNER"'" -f repo="'"$REPO"'" \
    > "'"$WORK"'/reviews/{}.json" 2>/dev/null || echo "{}" > "'"$WORK"'/reviews/{}.json"
'
```

### Step 3. filter (jq)

指定 reviewer 分のみ抽出 + 定型除外:

```bash
cat > "$WORK/filter.jq" <<'JQ'
def is_trivial:
  ( . // "" | gsub("\\s+"; "") ) as $s
  | ($s | length) < 5
    or ($s | test("^(LGTM!?|👍|👍！|了解|了解です|確認しました|コメントしました|Approve|Approve[dsぐ]|OK|okです?|OK！)$"; "i"));

def is_target: . as $u | ($TARGETS | any(. == $u));

.data.repository.pullRequest as $pr
| {
    number: $pr.number,
    title: $pr.title,
    url: $pr.url,
    state: $pr.state,
    createdAt: $pr.createdAt,
    author: $pr.author.login,
    reviews: [
      $pr.reviews.nodes[]
      | select(.author.login | is_target)
      | {
          reviewer: .author.login,
          state: .state,
          submittedAt: .submittedAt,
          summary: (if (.body | is_trivial) then null else .body end),
          inline: [
            .comments.nodes[]
            | select(.author.login | is_target)
            | select(.body | is_trivial | not)
            | {reviewer: .author.login, path, line: (.line // .originalLine), body, createdAt, url}
          ]
        }
      | select(.summary != null or (.inline | length) > 0)
    ],
    issueComments: [
      $pr.comments.nodes[]
      | select(.author.login | is_target)
      | select(.body | is_trivial | not)
      | {reviewer: .author.login, body, createdAt, url}
    ]
  }
| select((.reviews | length) > 0 or (.issueComments | length) > 0)
JQ

mkdir -p "$WORK/filtered"
for f in "$WORK/reviews/"*.json; do
  pr=$(basename "$f" .json)
  result=$(jq -c --argjson TARGETS "$TARGETS_JSON" -f "$WORK/filter.jq" "$f" 2>/dev/null)
  if [ -n "$result" ] && [ "$result" != "null" ]; then
    printf '%s\n' "$result" > "$WORK/filtered/${pr}.json"
  fi
done
```

### Step 4. HTML section 生成

まず対象 doc の既存 `<h2>` 数を数えて次番号 N を決める:

```bash
NEXT_H2=$(grep -cE '^<h2' "$DOC")
NEXT_H2=$((NEXT_H2 + 1))
```

reviewer ごとに `<h3>${NEXT_H2}.K reviewer_name のコメント</h3>` (K は 1..) 直下に PR 別 `<details class="pr-block">` を並べる。1 details の中身:

- `<summary>`: PR #<n> · state · author · title
- `review summary` ul (state = APPROVED/COMMENTED/CHANGES_REQUESTED を chip 表示)
- `inline review comments` ul (path:line + 本文)
- `thread comments` ul (本文のみ)

既存 doc の class (`pr-block` / `qa` / `lbl lbl-ok` / `lbl lbl-note` / `ts` / `pr-meta`) を流用する。style は既存 doc 側にすでに定義済み。

body HTML 変換: 改行 `\n` → `<br>`、`&<>` は `html.escape`。URL / mention は plain text 維持。

### Step 5. doc に追記

1. 既存 doc の末尾 `<script id="local-docs-script"` 直前に挿入する (`head -n <line>` + append + `tail -n +<line>` を Bash で組み、Edit tool は差分適用に使う)
2. section 見出しは `<h2 id="reviewer-sections">${NEXT_H2}. reviewer 別コメント集約 (SCOPE)</h2>`。**既存の同 id を持つ h2 があれば** そこから次 h2 or `<script>` タグ手前まで置換する (2 回目以降の同 scope 更新)
3. frontmatter を更新: `<!-- updated: -->` を今日、`<!-- data-window: -->` の右辺を今日、左辺は `SINCE` に揃える

### Step 6. build

```bash
cd "$(dirname "$DOC")/../.."
/usr/bin/env -i HOME="$HOME" PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" node _index/build.mjs 2>/dev/null
```

## Output

- 更新した file path
- reviewer 別統計を chat に 1 行ずつ: `<reviewer>: 対象 PR N 件 · summary S · inline I · thread T`
- 対象 PR 番号 list (up to 10 件、超過は `... (全 N 件)` で truncate)

doc 本体には統計数字を書かない (`pr-review-digest` と同方針)。

## Failure Handling

| 状況 | 挙動 |
|---|---|
| config 不在 | 「~/.claude/references-private/pr-review-digest.env を作って」と 1 行で abort |
| gh auth 失効 | 「gh auth login を実行して再試行して」と 1 行で abort |
| reviewer handle 未解決 (0 件) | 「<name> の gh handle が特定できない。org member から候補: ...」と提示、user 選択 |
| reviewer handle 複数候補 | 候補 list を出して user 選択 |
| PR 0 件 | 「scope に該当する PR なし」と 1 行返して終わる (doc は変更しない) |
| GraphQL rate limit | 5 分待って 1 回だけ retry |
| doc glob で 0 件 | 「初回は `local-docs` skill で空 doc を作ってから本 skill で追記する」と促して abort |
| build.mjs fail | 追記 file を snapshot dir に退避して user escalate |

## Notes

- 本 skill は read-only 収集 + doc 追記のみ。原 PR には触れない
- 定型除外 regex は本文完全一致のみ。判定 body に空白以外の他文字が混じれば残す
- `--include-files-check` は title 非マッチ PR 数 × ~200ms かかる。1 年分 100+ PR で 20-30 秒
- 実 config は private file、public repo (本 skill file) には固有名詞を書かない (canonical: CLAUDE.md `Public-repo private-data block`)
- lens 化して review-member に組み込みたい場合は本 skill の出力 HTML を Read → explore-agent に lens 分類させる。lens 再学習手順は `review-member` SKILL.md の Notes 参照
- 初回の 1 pass は数百 API call で 5-10 分かかる。以降は since を絞れば数分に収まる
