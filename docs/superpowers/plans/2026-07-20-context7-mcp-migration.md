# context7 MCP 化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development / superpowers:executing-plans。checkbox で進捗を追う。

**Goal:** ai-tools 側 self-made `context7` skill (curl 手組み実装) を、公式 MCP server `@upstash/context7-mcp` (v3.2.4 npm) 呼び出しに置換する。curl 特有の network 例外処理を MCP 統合に寄せ、skill 本体は「MCP tool 呼び出しの使い方 + failure behavior 指示」に書き換える。

**Architecture:** MCP server は `claude mcp add` で登録する (`~/.claude/mcp.json` に反映)。skill file (`~/ai-tools/claude-code/skills/context7/SKILL.md`) は curl 手順を MCP tool (`mcp__context7__resolve-library-id` / `mcp__context7__query-docs`) 呼び出し手順に書き換える。**pre-tool-use.sh:124 は既に MCP tool 名を認識済**であり、hook 側の対応は不要と想定 (実発火試験で確認する)。

**Tech Stack:** `@upstash/context7-mcp` (npm), `claude mcp add`, `~/ai-tools/claude-code/skills/context7/SKILL.md`, `~/ai-tools/claude-code/hooks/lib/write-checkers.sh` (既存 skip rule 温存)。

## Global Constraints

- **SoT 遵守**: skill file 修正は `~/ai-tools/claude-code/skills/context7/` 配下のみ。`~/.claude/` は sync.sh 経由でしか触らない
- **worktree 必須**: 実装は worktree に切ってから (main 直接 edit 禁止)
- **MCP server 追加 = user 環境変更**: `~/.claude/mcp.json` は user 環境設定であり ai-tools SoT の外。ここは直接編集で可 (commit 対象外)
- **既存 hook 挙動を壊さない**: `write-checkers.sh:63` の「skill 経由 write は skip」を残す。hook 側の keyword 一覧 (`_LIVE_DOC_KEYWORDS`) にも触らない
- **可逆性**: MCP 化後の smoke test が失敗したら (a) `claude mcp remove context7` (b) skill file を revert で元に戻せる粒度で commit
- **文体**: commit / plan は `rules/plain-jp.md` 準拠

---

### Task 1: 前提確認と worktree 準備

**Files:**
- 読取: `~/.claude/mcp.json`, `~/ai-tools/claude-code/skills/context7/SKILL.md`, `~/ai-tools/claude-code/hooks/lib/write-checkers.sh` の該当行
- 作成: worktree のみ

**Interfaces:**
- Produces: worktree path `~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/` (branch `feat/context7-mcp`)

- [ ] **Step 1: mcp.json 現状 read**

Run: `cat ~/.claude/mcp.json`
Expected: `{"mcpServers":{}}` or 既存 MCP server 定義。context7 が既に定義されていない前提を確認する

- [ ] **Step 2: MCP server 名確定 (公式 doc 確認)**

Run: `npm view @upstash/context7-mcp version bin`
Expected: v3.2.4 前後、bin フィールドで実際の起動 command を確認 (npx で動くか、それとも direct install が要るか)

- [ ] **Step 3: worktree 作成**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git worktree add -b feat/context7-mcp ../ai-tools.wt/context7-mcp main
cd ../ai-tools.wt/context7-mcp
git status
```
Expected: `On branch feat/context7-mcp` + clean

---

### Task 2: MCP server install + connect 確認

**Files:**
- Modify: `~/.claude/mcp.json` (直接編集、sync 経路外)

**Interfaces:**
- Produces: `mcp__context7__resolve-library-id` / `mcp__context7__query-docs` tool が Claude Code で利用可能な状態

- [ ] **Step 1: MCP server 登録**

Run:
```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
```
Expected: `Added MCP server "context7"` のような success message

- [ ] **Step 2: 登録確認**

Run: `claude mcp list`
Expected: `context7` が list に出現。既存 (Figma / Slack / Notion / serena) と併記

- [ ] **Step 3: mcp.json 反映確認**

Run: `cat ~/.claude/mcp.json | jq '.mcpServers | keys'`
Expected: `["context7", ...]` に含まれる (他に既存 server があれば併記)

- [ ] **Step 4: 実際に tool call を試す (別 session が要る可能性大)**

user に依頼する: 「新 session を開いて、`mcp__context7__resolve-library-id` で `react` を検索し、結果が返るか確認してほしい」

Expected: library ID 候補が返る (例: `/websites/react_dev_reference`)。失敗時は Task 1 Step 2 の bin 情報を再確認し、Rollback 手順へ

---

### Task 3: skill file を MCP 呼び出しに書き換え

**Files:**
- Modify: `~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/skills/context7/SKILL.md`

**Interfaces:**
- Consumes: Task 2 で有効化した MCP tool 名 (`mcp__context7__resolve-library-id`, `mcp__context7__query-docs`)
- Produces: MCP 前提の skill 本体。Failure Behavior 指示 (4 パターン) は保持する

- [ ] **Step 1: 現行 skill を read (再確認)**

Run: `head -80 ~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/skills/context7/SKILL.md`
確認: 現行 Workflow 節 (curl 前提)、Failure Behavior 表、Hook 連携行

- [ ] **Step 2: skill 本体を書き換え**

Edit tool で以下の書き換えを行う:
- frontmatter `allowed-tools: Bash` → `allowed-tools: mcp__context7__resolve-library-id, mcp__context7__query-docs`
- `## Workflow` 節の curl example 2 つを MCP tool call example に置換 (実際の tool 名 / パラメタは Task 2 Step 4 で確定した仕様に合わせる)
- `## Example` 節も MCP 呼び出しに置換
- `## Tips` 節から curl 固有 tips (jq / URL-encode 等) を削除、MCP 固有 tips に更新
- **`## Failure Behavior` 表は残す** (MCP 側が自動で fallback するとは限らないので、skill 使用者への指示として温存)
- `## Overview` 節の「via curl」を「via Context7 MCP」に置換
- Hook 連携行 (「Hook 連携: `hooks/lib/write-checkers.sh` の `_LIVE_DOC_KEYWORDS` ...」) は変更不要

**注意**: Task 2 Step 4 で tool の実 signature を確認してから書く。想像で書かない (verification-before-completion 原則)

- [ ] **Step 3: 書き換え後 read で確認**

Run: `head -60 ~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/skills/context7/SKILL.md`
Expected: curl 記述が消え、MCP tool 呼び出し記述に置換されている。Failure Behavior は残っている

- [ ] **Step 4: commit**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp
git add claude-code/skills/context7/SKILL.md
git commit -m "$(cat <<'EOF'
feat(context7): curl 手組みを Context7 MCP 呼び出しに置換する

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: hook 側の skip rule と CLAUDE.md 参照の整合確認

**Files:**
- 読取のみ: `~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/hooks/lib/write-checkers.sh`, `~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/CLAUDE.global.md`
- Modify (必要時のみ): 上記 file

**Interfaces:**
- Consumes: Task 3 で書き換えた skill 本体
- Produces: hook + CLAUDE.md が MCP 前提でも正しく動く状態

- [ ] **Step 1: write-checkers.sh:63 の skip rule 確認**

Run: `sed -n '60,70p' ~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/hooks/lib/write-checkers.sh`
確認: `*/skills/context7/*) return 0 ;;` が残っている。MCP 呼び出しは Bash 経由ではないので skip rule は形骸化するが害はない → **温存**

- [ ] **Step 2: pre-tool-use.sh:124 の MCP tool 認識確認**

Run: `sed -n '120,128p' ~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/hooks/pre-tool-use.sh`
Expected: `mcp__context7__resolve-library-id` / `mcp__context7__query-docs` が既に許可リストにある → **触らない**

- [ ] **Step 3: CLAUDE.md § Library API Live Doc Required の記述確認**

Run: `grep -A2 "Library API Live Doc" ~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp/claude-code/CLAUDE.global.md`
Expected: `skill: skills/context7/SKILL.md` の参照が残る → **触らない** (skill file は同 path に存続)

- [ ] **Step 4: 変更不要と判断した場合は skip、変更が要ればここで edit + 追加 commit**

想定: Step 1-3 全て「触らない」で確定するはず。commit なしで Task 4 done

---

### Task 5: sync 実行 + main ff-merge + 効果測定 baseline

**Files:**
- 実行: `sync.sh to-local`
- 更新: 本 plan file 末尾に効果測定欄

**Interfaces:**
- Consumes: Task 3 の skill 書き換え
- Produces: `~/.claude/skills/context7/SKILL.md` に反映

- [ ] **Step 1: sync 実行**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools.wt/context7-mcp
bash claude-code/sync.sh to-local --yes 2>&1 | tail -10
```
Expected: `skills/context7` が更新される旨の line

- [ ] **Step 2: 反映確認**

Run:
```bash
grep "mcp__context7" ~/.claude/skills/context7/SKILL.md | head -3
grep -c "curl" ~/.claude/skills/context7/SKILL.md
```
Expected: mcp__context7 が hit、curl 出現数が 0 (完全置換の確認)

- [ ] **Step 3: 実発火試験 (別 session 依頼)**

user に依頼する: 「新 session で `useState` の直書きを Edit で試み、pre-tool-use.sh の live-doc warn が出るか、続けて context7 skill を発火して MCP tool call が動くかを確認してほしい」

Expected: (a) live-doc warn が出る (既存動作の非破壊確認) (b) context7 skill 起動時に MCP tool が呼び出せる

- [ ] **Step 4: main へ ff-merge + worktree cleanup**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git merge --ff-only feat/context7-mcp
git worktree remove ../ai-tools.wt/context7-mcp
git branch -d feat/context7-mcp
git log --oneline -3
```
Expected: fast-forward 成功、worktree list から消える

- [ ] **Step 5: 効果測定欄を plan 末尾に追記**

Edit tool で本 plan file 末尾に効果測定欄追加:
```markdown
## 効果測定

- **before (2026-07-20)**: skill 内 curl call 実装、network 例外は skill 使用者が読み解く
- **after (実装後)**: MCP tool call、permission / sandbox 統合の恩恵、curl 特有例外の解消
- **判定基準**: 1 週間後、context7 skill 発火時に MCP tool が期待通り呼び出せていれば成功。呼び出し失敗 log が出ていれば Rollback
- **副作用監視**: `claude mcp list` で context7 が connected 状態を保っているか週次確認。API rate limit / 429 発生時の挙動を skill 使用者から fedback
```

- [ ] **Step 6: 効果測定追記 commit**

Run:
```bash
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git add docs/superpowers/plans/2026-07-20-context7-mcp-migration.md
git commit -m "$(cat <<'EOF'
docs(plan): context7 MCP 化 効果測定欄を追記する

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Rollback 手順

MCP tool call が動かなかった場合 or 想定外の副作用が出た場合:

```bash
# skill 側 revert
cd ~/ghq/github.com/DaichiHoshina/ai-tools
git revert <Task 3 の commit>
bash claude-code/sync.sh to-local --yes

# MCP server 削除
claude mcp remove context7
```

skill は curl 実装に戻り、hook 側は温存されているので影響なし。

## 未確定事項

- Task 2 Step 4: MCP tool の実 signature (パラメタ名 / 返却 schema) は npm module か公式 doc を Task 2 実行時に確認する必要がある。想像で skill を書き換えると再修正が発生する
- Task 3 の skill 書き換え文面は Task 2 完了後に確定する。それまで固定文面は書かない (verification 原則)
- Failure Behavior 表の 4 パターンのうち「代替キーワード suggest」「libraryId 候補 3 件 fallback」は MCP tool 側が自動でやる可能性がある。Task 2 Step 4 で挙動確認し、自動化されていれば skill 記述を「MCP 側で自動処理される」に更新する
- npm 経由の MCP server は npx がキャッシュを持たない場合、初回起動が遅い。permission auto-accept 設定 (settings.json の allow list) に `mcp__context7__*` を追加すべきか、Task 5 Step 3 の smoke 結果で判断

## 実装差分メモ (2026-07-20 実行時に判明)

- **`claude mcp add` の scope**: default は project local (`~/.claude.json` の該当 project 節) に書かれるため、全 project から使える user scope が要る場合は `--scope user` を明示する。実装時は最初 project scope で登録してしまい、`claude mcp remove` して user scope で入れ直した (実測)
- **tool 名確定**: 公式 README (github.com/upstash/context7) の MCP Tools 節で `resolve-library-id` (params: `query`, `libraryName`) と `query-docs` (params: `libraryId`, `query`) を確認。skill file の allowed-tools frontmatter と Workflow 節はこの signature に合わせて記述
- **Failure Behavior は温存**: MCP server 側が代替 keyword suggest / libraryId fallback を自動でやる保証がないため、skill 使用者向け指示として 4 パターン全て残した
- **hook / CLAUDE.md 変更なし**: pre-tool-use.sh:124 が `mcp__context7__resolve-library-id` / `mcp__context7__query-docs` を既に GUARD_CLASS=Safe 認識済であり、write-checkers.sh の skill skip rule も温存で問題なし
- **jp-quality hook で 2 回 block を食らった**: 冒頭 description + Overview 冒頭が 100 字超で block、句点分割で通過。この過程自体は verification-before-completion の効果例 (無検証で通したかった書き方が block された)

## 効果測定

- **before (2026-07-20)**: skill 内 curl call 実装、network 例外は skill 使用者が読み解く、jq / URL-encode の Bash tips を skill file に持つ
- **after (2026-07-20 実装済)**: `mcp__context7__resolve-library-id` / `mcp__context7__query-docs` の MCP tool 呼び出しに置換、`~/.claude.json` の user scope に context7 server 登録済、`claude mcp list` で Connected 確認済
- **判定基準**: 1 週間後 (2026-07-27) に (a) `claude mcp list` で context7 が Connected を保っている (b) skill 発火 log で MCP tool call の成功件数を確認する。失敗が続けば Rollback 手順へ
- **副作用監視**: `~/.claude/logs/pre-tool-use.log` (もしあれば) で `mcp__context7__*` 呼び出し時の permission 挙動を確認。auto-accept が要るなら settings.json allow list に追加する検討
- **計測 command**: `claude mcp list | grep context7`
