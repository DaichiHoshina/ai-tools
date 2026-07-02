# claude-code Directory Config

**Default = plain JP 常体 (genshijin OFF)**。chat も外向き text も常体 (〜する / 〜した) で開いた文章を書く。主語明示、指示語禁止 (「これ」「それ」「上記」→ 具体名)。**閉じてない文章 (体言止め羅列 / 助詞省略 / 名詞ぶつ切り / 動詞省略) を全 context で禁止する**。canonical: `rules/genshijin.md`。

`~/ai-tools/claude-code/` manages Claude Code config (commands / skills / hooks / agents / rules / guidelines / references). Synced to `~/.claude/` via `sync.sh`.

## Quick Reference

```bash
cd ~/ai-tools/claude-code
npm test                    # jest (statusline 等 JS test)
bats -r tests/              # bash hook / lib / scripts の bats 全実行
./sync.sh to-local --yes    # repo → ~/.claude 反映 (非対話)
./scripts/hook-bench.sh     # hook latency 計測 (warmup=5 / runs=15、--log で保存 / --diff で前回比較 / install-hook-bench-cron.sh で週次 cron)
```

**Golden workflow (頻出 3 種)**

- 実行 mode 判定 → `/plan` (inline / /dev / /workflow / /flow / /flow --auto / /goal の 6 択を Step 2 で判定、/goal は loop 系 objective gate task に限定)
- worktree 隔離 + commit + ff-merge + push (`[[ai-tools-worktree-workflow]]` canonical、**dir 名 slug と branch 名は必ず一致させる** → `rules/worktree-branch-name-match.md`):
  ```bash
  git stash push -u -m wip && git worktree add ../ai-tools-wt-<topic> -b <topic>
  # wt 内で編集 + commit
  git merge --ff-only <topic> && git push origin main && git worktree remove ../ai-tools-wt-<topic> && git branch -d <topic>
  ```
- skill 追加 → `/skill-add` / guideline 更新 → `/update-guidelines` / commit + push + PR → `/git-push --pr` (`pushして` でも発火)

## Repo layout

| dir | 役割 |
|---|---|
| `commands/` | slash command (`/plan` `/flow` `/review` `/workflow` 等) |
| `skills/` | Skill (`comprehensive-review` `jp-writing` `local-docs` 等) |
| `agents/` | subagent 定義 (`developer-agent` `po-agent` `manager-agent` `reviewer-agent` `explore-agent` 等) |
| `hooks/` | Claude Code hooks (`pre-tool-use.sh` `post-tool-use.sh` `session-start.sh` 等) |
| `rules/` | 規約 (`genshijin.md` `public-repo-private-data-block.md` `markdown-anchor-sync.md` 等) |
| `guidelines/` | 執筆 / language / design 規範 (`writing/` `design/` 等) |
| `references/` | 詳細仕様 / 履歴 / cross-ref 集 (`PARALLEL-PATTERNS.md` `INDEX.md` 等) |
| `templates/` | `settings.json.template` ほか canonical config |
| `scripts/` | sync 補助 / hook-bench / git-hooks |
| `lib/` | bash 共通 lib (`print-functions.sh` 等) |
| `tests/` | bats (`tests/integration/` `tests/unit/`) + jest |

詳細 dir 内 cross-ref は `references/INDEX.md` 参照。

## Editing Rule (data-loss guard)

- **Always edit source `~/ai-tools/claude-code/`**. `~/.claude/` 直接編集は `sync.sh to-local` で wipe される
- **root keys (env / model / statusLine / permissions / sandbox / worktree / enabledPlugins / extraKnownMarketplaces / autoUpdatesChannel ほか allowlist) は template canonical**。例外: `hooks` / `skillOverrides` は merge logic あり
- 🔒 PROTECTED SECTION / YAML frontmatter は改変禁止。詳細 (VERSION / SERENA_VERSION / stable channel 経緯): `references/editing-rule-detailed.md`

## Definition File SoT (ai-tools 一元)

**command / skill / agent / rule / guideline / hook / reference 等の定義 file は `~/ai-tools/claude-code/` を SoT として一元参照する**。`~/ghq/<repo>/.claude/` や `~/ghq/<repo>/CLAUDE.md` 等に同名定義があっても **AI は読み込まない**。

| 種別 | 取り扱い |
|---|---|
| memory file (`~/ghq/<repo>/memory/`、`~/ai-tools/memory/`) | **Read OK** (work-context / feedback 個別 file 含む) |
| 定義 file (command / skill / agent / rule / guideline / hook / reference) | **ai-tools 配下のみ Read**。repo 配下の同名 file は無視する |
| repo 配下 CLAUDE.md (`~/ghq/<repo>/CLAUDE.md`) | repo 固有 lint / format / CI / license / 法務 footer 等の **project 必須情報のみ** 参照、それ以外は ai-tools 側を優先 |
| repo 配下 code / config edit | repo の方針に従う (ai-tools SoT 適用外) |

## Definition File Token Saving

`.md` in commands/, skills/, agents/ consume tokens every session. Keep: decision tables, workflow defs, operation guards, prohibitions, 1 example. Remove: sample impl, duplicate explanations, detailed usage. Target: agent ≤300 / command ≤150 / skill 100-130 lines.

**EN-conversion-protected files/sections**: see `references/on-demand-rules/en-conversion-protected.md` (mistranslation breaks rules, bats tests, JP trigger matching).

**On-demand rules (auto-load 対象外、trigger 時のみ Read)**: `references/on-demand-rules/` 配下 (markdown-anchor-sync / en-conversion-protected / api-design / review-noise-discard / measure-before-hook-change / sync-canonical-with-bats)。trigger: md heading rename → `markdown-anchor-sync.md` / EN refactor・`/claude-update-fix` → `en-conversion-protected.md` / handler・controller・resolver・api・endpoint → `api-design.md` / `/review`・`/review-fix-push`・`comprehensive-review` skill 発火時 → `review-noise-discard.md` / `hooks/` block・warn 系編集時 → `measure-before-hook-change.md` / `commands/`・`agents/`・`references/` の heading・YAML key・step 番号改変時 → `sync-canonical-with-bats.md`。

## Discovery / Investigation Routing (anti-overuse)

Agent startup is the biggest cost source (dozens of seconds to minutes).

> ⛔ **`general-purpose` agent is absolutely banned** — `subagent_type` must be explicit on every `Task` call; unspecified fallback is also forbidden. On violation: abort immediately and switch to `explore-agent` (search) / `claude-code-guide` (CLI/SDK) / `developer-agent` (impl).

| Scope | Tool |
|---|---|
| 1-2 files / specific symbol | Bash grep/find or `mcp__serena__find_symbol` |
| 3+ query / broad search | `Task(explore-agent)` parallel fan-out by default (parallelism = domain count, max 8) |
| Claude Code CLI/SDK/API spec | `claude-code-guide` agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |
| **`general-purpose` agent** | **Forbidden** — highest cost source (measured max 501s). Always substitute with `explore-agent` / `claude-code-guide` / `developer-agent` |

> explore-agent / root-cause-analyzer を発火した後は、trailer フィールド (`status` / `confidence` / `issues_blocking`) を必ず読む。詳細: `references/agent-output-schema.md`

## Library API Live Doc Required

外部 library の API method / hook / config 直書き前に **context7 skill / WebFetch で最新 docs 取得**。trigger: library method 直書き (`useState` / `axios.create` 等) / 新 library 採用 / API spec 6 か月超。hook warn-only 検出 (`hooks/pre-tool-use.sh`)、skill: `skills/context7/SKILL.md`。

## Auto-Delegation (parent=Opus 4.7 default, subagent=Opus 4.7 executes)

*(Impl/edit task。Investigation phase → Discovery Routing)*

**Default = `developer-agent` (Opus 4.7)**。inline は exception only。Model 切替は `/model sonnet` (session 単位)。**1 dev = 1 file 原則** (`bundle_justification` なき複数 file fan-out 禁止)、**1 Task scope 上限** (file 3-5 / 観点 1-2 超 → 単一 message に N Agent 並列)、**parent 監視責任**。直列 chain でも step 内 fan-out (`[[feedback-no-single-agent-overload]]`)。

**Inline default の正当 exception (delegate 禁止)**: 以下は parent 直編集を推奨。dev 連投 → bundle-violation hard block の罠を踏まない:
- **CI fail 修正 / fixture 修正 / test 連鎖修正**: 周辺 file 把握必須、iteration 多発、bundle hook と相性最悪。parent context の方が cheap (`[[feedback-ci-fix-inline-default]]`)
- **review feedback 反映**: 既 file の局所修正 1-3 箇所、context 既保持
- **shellcheck / lint warn 1 箇所修正**: 1 line 編集

→ 上記 3 種 (CI fail 修正 / review feedback 反映 / shellcheck / lint warn 1 箇所修正) に該当する task は `/dev` / `/flow` ではなく inline で直編集する。delegate するなら明示理由 (>5 file / 30+ line each) を 1 行宣言してから。

**Parallel fan-out 自己強制 (hard rule)**: N≥2 dev は**単一 assistant message に N tool_use**。発火直前 self-check 1 行宣言必須。違反検出: `pre-tool-use.sh:_check_developer_agent_bundle_violation`。

**Subagent silent-fail guard**: subagent では `AskUserQuestion` 不可 + permission prompt 系 tool auto-deny で **silent fail**。approval-gated edit / 判断 fork は parent escalate (`status: blocked` + `issues_blocking[]`)。canonical: `agents/developer-agent.md` § Silent-fail guard。

詳細 (Model 切替経緯 / delegate threshold / parallel fire format / inline exceptions / silent-fail web 出典): `references/auto-delegation-detailed.md`

## Tool Call Format (生テキスト呼び出し禁止)

ツール呼び出しは**必ず harness の正規 function-call 機構**で行う。応答本文に `call` / `<invoke ...>` / `<parameter ...>` 等の XML をテキストとして書かない → 実行されず `Your tool call was malformed` エラー。同じ malformed を繰り返したら**即停止**して正規 tool call をやり直す。`[[feedback-no-raw-text-tool-call]]`

## Collaboration stance (AI = 思考パートナー)

AI を**思考パートナー**として扱う。subagent report の数値 / file 変更 / 測定値は最低 1 つ cross-check してから採用する (`fact-check` = `references/developer-agent-delegation-prompt.md` §0.5 B)。**Pattern**: developer-agent (Generator) → reviewer-agent / verify-app (Verifier)。Verifier は `status: accept` / `status: reject` + 具体 feedback を return し、reject 後に Generator が再生成する 1 round loop。

## Session Efficiency

**Autonomous mode ON by default + 質問抑制 default**。質問許可は 4 条件 (破壊的操作 / scope 完全欠落 / 推奨拮抗 / 既存方針競合) のみ。canonical: `rules/minimize-questions.md`。Long output = conclusion-first + PREP。Decision request = leading `要決定:` block。Token budget: Read with `limit`/`offset` (>200-line files)、Bash long output via `| head/tail -N`、code via Serena `find_symbol`。Full list: `references/session-efficiency-detailed.md`。

## Public-repo private-data block

**全 repo 共通 (public / private 問わず)**: commit message 本文 / trailer / footer、PR title / body、issue / MR comment に**具体的な人名 / GitHub handle (`@<handle>`) / Slack display name / 社員 alias を書かない**。Co-Authored-By trailer の AI marker (`Claude Opus 4.7` 等) は人物ではないため対象外。レビュー指摘の引用が必要なら handle を伏せて「レビュー指摘」と総称する。canonical: `~/ai-tools/memory/feedback_no_personal_name_in_commit.md`

**ai-tools repo は public**。社内 product 名 / 社内識別子 / 個人名 / 会社名 / project 固有名詞を `~/ai-tools/` 配下 file・commit message に書込禁止。`pre-tool-use.sh` hard block、canonical list: `~/.claude/references-private/private-name-list.txt`。詳細: `rules/public-repo-private-data-block.md` (`[[public-repo-social-hit-incident]]`)

**Hook block / NG-DICTIONARY.md**: AI定型語 / カタカナ造語禁止 / 難読漢語 / 非日常英語を hook block。**既存 key の name 変更禁止** (hook が exact match 参照)。詳細: `guidelines/writing/NG-DICTIONARY.md`

## Rewind / Context Management

**Esc**: pause / **Esc ×2** or `/rewind`: restore to checkpoint. Details: `references/checkpoint-rewind.md`

**>40% → `/compact`**。30 分 idle → `/clear`。同問題 2 連続失敗 → `/clear` + rewrite prompt。`user-prompt-submit.sh` 150/350 msg auto-warn。詳細: `references/performance-insights.md`

## Work output routing

| 種別 | 出力先 | 起動 trigger |
|---|---|---|
| 進捗報告 (status / 着手 / 完了 / blocker) | GitHub issue comment | `/post-comment gh-issue-comment` (「進捗書いて」「ステータス更新」) |
| 調査ログ / 手順書 / 計画書 / RCA / postmortem | local-docs HTML | `local-docs` skill (「調査まとめて」「手順書」「RCA 書いて」) |
| session 内一時 plan (phase 分割 / next-action) | `~/.claude/plans/` md | `/plan` (「impl の phase 分割」「実装方針」) |

詳細: `references/work-output-routing.md`

## Natural Language Triggers (top 5)

| Input | Action |
|---|---|
| "push" / "pushして" | `/git-push --pr` |
| "全自動で" / "autoで" / "おまかせ" | `/flow-auto` |
| "レビュー" / "レビューして" | `/review` |
| "team で" / "agent team で" / "分担で" / "本格的に" | `/flow` (PO/Manager/Dev hierarchy, forced) |
| "並列実行で" / "wt 分けて" / "worktree 分けて" / "Developer 並列で" | `/flow --parallel` |

上記 5 entry 以外 ("workflow で" / "test が通るまで" / "再度DD" 等) を含む全 list: `references/natural-language-triggers.md`

## Git Merge Prohibition

| Operation | Rule |
|---|---|
| PR branch merge (`gh pr merge` etc.) | **Strictly forbidden**. Output PR URL, direct to browser |
| git merge / rebase / branch delete | User confirmation required |
| Circumventing a deny rule with another tool | **Forbidden**. Keep the same intent and ask user (`[[feedback-deny-rule-no-escalation]]`) |

## Definition of Done (DoD)

Apply relevant items only. Scale by change size (typo → #6 / new feature → all): (1) Types 0 errors (2) Tests pass ≥80% (3) Lint 0 (4) Security clean (5) Build success (6) **1 smoke test** (required) (7) For DB changes, verify 4 paths: FK / long TX / replica lag / maintenance scope impact (`[[feedback-db-change-review-blind-spot]]`). Bundle: `/lint-test` / `/verify-once`.

## Root Cause Analysis

Structural fix over symptomatic. **Reproduce → identify → design → verify** 4 steps required. Details: `/root-cause` skill。Production rollback: revert PR → main merge → deploy が CI canonical path。直接 platform 操作 (ECS task def rollback 等) は上書きされるため revert PR と並行実施 (`[[feedback-rollback-via-revert-pr]]`)。

## Compounding Engineering

Misbehavior / non-obvious success → document immediately → auto-avoid next session。Memory write target (ai-tools repo): **`~/ai-tools/memory/` 固定** (`.gitignore` 済)。`~/.claude/projects/.../memory/` と Serena `.serena/memories/` への write 禁止。詳細: `references/compounding-engineering-cycle.md` / `references/memory-relocation-pattern.md`

**Hook 編集 baseline rule**: `hooks/*.sh` の block / warn 系編集前に **on-demand rule `references/on-demand-rules/measure-before-hook-change.md` を Read + `./scripts/hook-bench.sh --log` で baseline 計測**。skip すると latency regression が 24-48h 後に判明する (`[[2026-06-24 cd70e4e]]`)。

## Pre-write Self-check (except chat)

外向き text を書く前に **today's commits を確認** (`git log --since=midnight --pretty=format:'%h %s'`)。hook が write-type tool 前に auto-inject (2 source: working repo + `~/ai-tools` guidelines)。code comment: `guidelines/writing/code-comment.md`。

## Writing Style (genshijin OFF default)

chat も外向き text も **常体 plain JP の開いた文章** (〜する / 〜した、主語明示、指示語禁止) で書く。**閉じてない文章を全 context で禁止する**: 体言止め羅列 / 助詞省略 / 名詞ぶつ切り / 動詞省略 / 主語省略の連発。bullet 内も文として完結させる。canonical: `rules/genshijin.md` + `guidelines/writing/PRINCIPLES.md` + `guidelines/writing/NG-DICTIONARY.md`

**AI定型語 hook block**: 外向き text に AI定型語 (NG-DICTIONARY.md canonical) が含まれると `hooks/pre-tool-use.sh` が exit 2 でブロック。削除・置換して再実行 (`~/.claude/logs/jp-quality-block.log`)。**commit message draft 前だけでなく、work-context / decision doc / gh comment / MEMORY.md 等の file 書き込み前にも NG 語を先手 sweep する** (登録済み語の block が retry 2〜3 往復のトークン損失を生むため。頻出は 該当なし 系 / 難読漢語 / AI 段取り定型)。canonical: `guidelines/writing/NG-DICTIONARY.md`

## Default Readability + Writing Priority

prose 出力に先手で適用 (hook block 待ち retry を減らす = token 節約)。文体規範 canonical: `guidelines/writing/PRINCIPLES.md` + `NG-DICTIONARY.md`。外向き prose・docs は 1 文 100 字 (短文 60 字) 上限。外向き doc は**種別 guideline を on-demand で 1 本だけ読んで書く** (一覧: `guidelines/writing/README.md`)。深い書き直し / 全項目 self-check 時のみ `/jp-writing`。

外向き text は **ai-tools guidelines を project 設定より優先**。優先順: (1) `guidelines/writing/` canonical → (2) `rules/` → (3) project template。例外 (project 優先): lint / format / CI / license / 法務必須 footer。詳細: `guidelines/writing/README.md`

## References

`references/INDEX.md` / `references/model-selection.md` / `references/performance-insights.md` / `references/developer-agent-delegation-prompt.md` / `guidelines/writing/README.md`
