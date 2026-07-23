# claude-code Directory Config

文体 default は plain JP 常体 (canonical: `rules/plain-jp.md`)、質問抑制 default (canonical: `rules/minimize-questions.md`)、思考原則 (事実検証 / 証拠一致 / turn 完結 / 結論先行) の canonical は `rules/thinking-principles.md`。いずれも auto-load 済のため詳細は本 file に書かない。**turn 締め self-check (必須)**: 送信直前に `rules/plain-jp.md` §送信前 4 点を毎回適用する。末尾 `完了` / `〜済` / `次に` と 100 字超の文を禁止し、実測根拠も同 rule に置く。

`~/ai-tools/claude-code/` が Claude Code config の SoT で、`sync.sh` で `~/.claude/` へ同期する。**ai-tools repo 固有 rule (Quick Reference / Repo layout / Editing Rule / Token Saving / Hook baseline) は `~/ghq/github.com/DaichiHoshina/ai-tools/CLAUDE.repo.md` に分離済 (owner 階層 `~/ghq/github.com/DaichiHoshina/CLAUDE.md` の import 経由で load、repo 直下 CLAUDE.md は `claudeMdExcludes` で除外)**。`~/.claude/` を直接編集しない (sync で wipe される)。

## Turn pre-flight check-in

chat 出力前に (a) 最終文が 完了/〜済/次に で終わっていないか (b) 100 字超えていないか (c) 矢印チェーンを prose 化したか の 3 点を先に決めてから書く。turn 締め self-check (下記) と対称の最終 gate。

## Golden workflow

- 実行 mode 判定 → `/plan` (inline / /dev / /workflow / /flow / /goal / /loop。7 択の判定表と /workflow 下位 7 template は `commands/plan.md` Step 2 が canonical)。plan → 実装は Next command block (`/dev --plan <file>` 等)、`/plan --go` は判定 mode のまま continue する。mode 判定のみなら `/mode <task>`
- commit + push + PR → `/git-push --pr` (`pushして` でも発火)
- 全 command / skill の見取り図 (幹 + 3 根の tree) → `references/command-tree.md`

## Definition File SoT (ai-tools 一元)

command / skill / agent / rule / guideline / hook / reference の定義 file は `~/ai-tools/claude-code/` のみ Read し、`~/ghq/<repo>/.claude/` 等の同名定義は読み込まない。memory file (`~/ai-tools/memory/`、`~/ghq/<repo>/memory/`) は Read OK。repo 配下 CLAUDE.md は repo 固有 lint / format / CI / license / 法務 footer 等の project 必須情報のみ参照する。repo 配下 code / config edit は repo の方針に従う (SoT 適用外)。

**repo 配下 `.claude/` 配下 doc の扱い**: 基本 Read しない。repo ごとの「新規実装規範 digest」memory で判断する。例は snkrdunk.com の [[snkrdunk-claude-dir-digest]] + [[snkrdunk-guideline-gap]] だ。既存 file 修正は gap file + 周辺 code、新規作成は digest 規範に従い、迷ったら参照実装を pinpoint Read する (Serena `find_symbol` 等)。一般論 (文体 / 思考原則 / delegation 等) は常に ai-tools 側が正で、digest 未整備 project は初回に同 pattern で作る。

**On-demand rules (auto-load 対象外、trigger 時のみ Read)**: `references/on-demand-rules/` 配下。trigger 一覧: `references/on-demand-rules/README.md`。

## Serena 必須化

Serena MCP connect 済 project では、**session 内で最初のコード関連 tool (Read / Grep / Glob / Edit 等) の前に `mcp__serena__initial_instructions` を 1 回呼ぶ**。code に触れない turn (雑談 / model 切替 / config 相談) では発火しない。

## Discovery / Investigation Routing (anti-overuse)

Agent 起動が最大の cost 源 (数十秒〜数分)。

> ⛔ **`general-purpose` agent is absolutely banned** — `subagent_type` must be explicit on every `Task` call. On violation: abort and switch to `explore-agent` (search) / `claude-code-guide` (CLI/SDK) / `developer-agent` (impl).

| Scope | Tool |
|---|---|
| 1-2 files / specific symbol | Bash grep/find or `mcp__serena__find_symbol` |
| 3+ query / broad search | `Task(explore-agent)` parallel fan-out (parallelism = domain count, max 8) |
| Claude Code CLI/SDK/API spec | `claude-code-guide` agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |

> explore-agent / root-cause-analyzer 発火後は trailer (`status` / `confidence` / `issues_blocking`) を必ず読む。詳細: `references/agent-output-schema.md`

## Library API Live Doc Required

外部 library の API method / hook / config 直書き前に context7 skill / WebFetch で最新 docs を取得する。trigger: library method 直書き / 新 library 採用 / API spec 6 か月超。skill: `skills/context7/SKILL.md`。

## Auto-Delegation (優先順: 速さ > クオリティ > トークン効率)

*(Impl/edit task。Investigation phase → Discovery Routing)*

task 着手前に「独立 scope の数 N」を数え、下記 table を厳守する:

| N (独立 scope 数) | Default |
|---|---|
| 1 (単発 task) | **inline** (agent 起動 overhead を回収できない) |
| 2+ (独立 task 複数) | **agent 並列 fan-out** (単一 message に N tool_use、peak=N) |
| iteration 前提 (CI fail / fixture / test 連鎖 / review feedback / lint 1 箇所 / 1 symbol fix) | **inline 固定** |

- **クオリティ最優先 mode**: 破壊的変更 / migration / security 修正は developer-agent → reviewer-agent / verify-app の 1 round loop
- **並列 fan-out 必須 (直列禁止)**: 着手前に独立 scope を全列挙して N を確定し、N≥2 は単一 message に N tool_use を bundle する。依存逐次は `serial_reason`、各 prompt に `scope: i/N` を明記する
- **1 dev = 1 file 原則** (`bundle_justification` なき複数 file fan-out 禁止)。silent-fail guard / scope 上限は `agents/developer-agent.md` が canonical
- **相談 turn は fable advisor**: 定義 file の方針相談 / 「大事」「重要」明示 / 既決判断への異議で発火する。最初の write 前に `/fable --consult` で助言を取る (canonical: `commands/fable.md`)

詳細 (判定 flow / fire format / serial_reason 仕様 / inline 例外): `references/auto-delegation-detailed.md`

## Tool Call Format (生テキスト呼び出し禁止)

tool 呼び出しは harness の正規 function-call 機構のみで行い、応答本文に `<invoke>` 等の XML をテキストとして書かない。malformed 連発時は即停止してやり直す。delegation (Task 委譲) 文脈で特に誘発されやすい。`hooks/stop.sh` の raw XML guard は turn 終了後の最終防衛で、turn 中の連続生成は止められないため一次防御は応答生成側だ。

## Collaboration stance (AI = 思考パートナー)

subagent report の数値 / file 変更 / 測定値は最低 1 つ cross-check してから採用する (`fact-check` = `references/developer-agent-delegation-prompt.md` §0.5 B)。

## Session Efficiency

Autonomous mode ON。Long output = conclusion-first + PREP、Decision request = 先頭 `要決定:` block、Token budget = Read `limit`/`offset` + Bash `| head/tail`、code = Serena `find_symbol`。詳細: `references/session-efficiency-detailed.md`。

## Public-repo private-data block

commit / PR / issue / MR に人名 / handle / Slack name / 社員 alias を書き込まない (全 repo 共通、Co-Authored-By AI marker は対象外)。詳細は auto-load 済 rule `rules/public-repo-private-data-block.md` + `guidelines/writing/NG-DICTIONARY.md` (既存 key rename 禁止) が canonical。

## Rewind / Context Management

**Esc**: pause / **Esc ×2** or `/rewind`: checkpoint restore (`references/checkpoint-rewind.md`)。**>40% or msg 数 150 超 → `/compact` を自主提案** (OR 条件どちらか先着。200 超は force split で手遅れ)。30 分 idle → `/clear`、同問題 2 連続失敗 → `/clear` + rewrite prompt。詳細: `references/performance-insights.md`

## Work output routing

| 種別 | 出力先 | 起動 trigger |
|---|---|---|
| 進捗報告 (status / 完了 / blocker) | GitHub issue comment | `/post-comment gh-issue-comment` (「進捗書いて」) |
| 調査ログ / 手順書 / RCA / postmortem | local-docs HTML | `local-docs` skill (「調査まとめて」「RCA 書いて」) |
| session 内一時 plan | `~/.claude/plans/` md | `/plan` |

詳細: `references/work-output-routing.md`

## Natural Language Triggers (top 5)

| Input | Action |
|---|---|
| "push" / "pushして" | `/git-push --pr` |
| "全自動で" / "autoで" / "おまかせ" | `/flow --auto` |
| "レビュー" / "レビューして" | `/review` |
| "team で" / "agent team で" / "分担で" / "本格的に" | `/flow` (PO/Manager/Dev hierarchy, forced) |
| "並列実行で" / "wt 分けて" / "worktree 分けて" / "Developer 並列で" | `/flow --parallel` |

全 list: `references/natural-language-triggers.md`

## Worktree-first 作業 (user 決定 2026-07-19)

全 repo で main 上の直接作業を避け、worktree + branch を切ってから作業する (検証前の変更が main へ混入するのを防ぐ)。ai-tools repo のみ作業完了後に main へ ff-merge して閉じる (canonical: `references/on-demand-rules/ai-tools-worktree-flow.md`)。他 repo は PR 経路で、merge 操作は下表の禁止 rule に従う。例外は typo 級の 1 file 即修 + user 明示指示のみとする。

## Git Merge Prohibition

| Operation | Rule |
|---|---|
| PR branch merge (`gh pr merge` etc.) | **Strictly forbidden**. Output PR URL, direct to browser |
| git merge / rebase / branch delete | User confirmation required |
| Circumventing a deny rule with another tool | **Forbidden**. Keep the same intent and ask user |
| user が interrupt (Esc) した状態変更操作の同 session 再試行 | **Forbidden**。interrupt = 疑問 signal、理由確認か別案提示へ (`references/on-demand-rules/git-safety-ops.md`) |

## Definition of Done (DoD)

Apply relevant items only. Scale by change size (typo → #6 / new feature → all): (1) Types 0 errors (2) Tests pass ≥80% (3) Lint 0 (4) Security clean (5) Build success (6) **1 smoke test** (required) (7) For DB changes, verify 4 paths: FK / long TX / replica lag / maintenance scope impact. Bundle: `/lint-test` / `/verify-once`.

## Verification before completion (evidence before claims)

「完了」「動く」「passing」等の success 宣言前に、検証 command を fresh に実行して出力と主張を照合する (canonical: `superpowers:verification-before-completion` skill)。**発火 trigger**: (a) commit / push / PR 作成前 (b)「実装した / 動くはず」を書く前 (c) subagent の success 報告を採用する前。skip した場合は「未検証」と明示する。

## Root Cause Analysis

Structural fix over symptomatic (Reproduce → identify → design → verify)。詳細: `/root-cause` skill。Production rollback は revert PR → main merge → deploy 経路 (Platform 直接操作は応急処置、revert PR と並走必須)。ローカル再現 = 真因確定と同一視しない (`references/on-demand-rules/incident-local-repro-not-root-cause.md`)。

## Compounding Engineering

Misbehavior / non-obvious success → 即 document → 次 session で auto-avoid。memory write 先は project 階層 CLAUDE.md 宣言の auto-memory dir、宣言なしは `~/ai-tools/memory/` 固定 (write は `/memory-save` 経由のみ)。恒久 file は書込前に Tier 判定し、social-hit term を含めば `~/.claude/references-private/` へ振る (canonical: `commands/memory-save.md` Tier B)。**Serena `write_memory` / `onboarding` / `edit_memory` での保存は全 project 禁止** (`.serena/memories/` は read のみ可)。保存前に該当 dir の MEMORY.md を Read する。**automation infra (cron / hook / rule / skill) の追加提案は、既存分の効果を 1 か月以上実測してから判断する。実測ゼロなら「追加しない」を推奨 default にする**。詳細: `references/compounding-engineering-cycle.md` / `references/memory-relocation-pattern.md`

## Writing

- **記述対象の使い分け (超重要)**: code = How / test = What / commit log = Why / code comment = Why not (採らなかった選択肢と理由)。comment は **default 書かない / 上限 2 行 / what 言い換え禁止** (canonical: `guidelines/writing/code-comment.md`、hook が digest を inject)
- 外向き text 前に today's commits を確認する (hook が write-type tool 前に auto-inject)
- 文体規範 canonical: `guidelines/writing/PRINCIPLES.md` + `guidelines/writing/NG-DICTIONARY.md` (AI 定型語 hook block、書込前に先手 sweep)。1 文 100 字 (短文 60 字) 上限
- 外向き doc は種別 guideline を on-demand で 1 本だけ読む (一覧: `guidelines/writing/README.md`)。深い書き直しのみ `/jp-fix`
- 優先順: (1) `guidelines/writing/` → (2) `rules/` → (3) project template。例外 (project 優先): lint / format / CI / license / 法務 footer

## References

`references/INDEX.md` / `references/model-selection.md` / `references/performance-insights.md` / `references/developer-agent-delegation-prompt.md` / `guidelines/writing/README.md`
