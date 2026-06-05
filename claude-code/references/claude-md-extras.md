# CLAUDE.md Extras

Sections externalized from CLAUDE.md to reduce per-turn token cost. CLAUDE.md keeps 1-line pointers.

---

## Definition File Token Saving

`.md` in commands/, skills/, agents/ consume tokens every session. Keep: decision tables, workflow defs, operation guards, prohibitions, 1 example. Remove: sample impl, duplicate explanations, detailed usage. Target: agent ≤300 / command ≤150 / skill 100-130 lines.

**EN 化禁止 file/section**: `rules/en-conversion-protected.md` 参照 (誤訳すると規約・bats test・JP trigger 破壊)。

---

## Discovery / Investigation Routing

Agent startup is the biggest cost source (dozens of seconds to minutes).

| Scope | Tool |
|---|---|
| 1-2 files / specific symbol | Bash grep/find or `mcp__serena__find_symbol` |
| 3+ query / broad search | `Task(explore-agent)` 並列発火 default (domain 数 = 並列数、max 8)、ambiguous 判定不要 |
| Claude Code CLI/SDK/API spec | `claude-code-guide` agent |
| Other genuinely broad analysis | Explore (built-in, last resort) |

**Avoid `general-purpose` agent** (measured highest cost source, max 501s). Metrics: `references/performance-insights.md`

---

## Session Efficiency (full list)

- **Design decisions**: light → `Shift+Tab` Plan Mode / large → `/plan` (PO agent). **Long brainstorm → haiku separate session (`claude --model haiku`), handoff to Opus for impl**
- **Long tasks**: `/rename {type}-{scope}`, `claude --resume` (`references/session-management.md`)
- **Success-criteria principle**: "what defines success" over procedural steps
- **Verify first**: post-impl run test/lint/typecheck (DoD below)
- **MCP tool args: verify spec before writing**: use `ToolSearch select:<tool>` to confirm param names; do not rely on LLM autocorrect `[[hook-principles-path-bug-incident]]`
- **After regex replace, run `git diff --stat` immediately**: serena `replace_content` regex forces DOTALL/MULTILINE — `.*\n` greedy wipe risk. Single line: **literal + trailing `\n`**; multi-line: **non-greedy `.*?` + explicit end anchor** (`[[serena-replace-regex-dotall-pitfall]]`)
- **Minimize confirmation / choice**: execute safe ops without prompting; apply recommended option directly for minor choices. Confirm only for: file deletion / deploy / external send / critical decisions (architecture / cost / irreversible)
- **推奨自走 mode (default ON)**: parent の推奨判断は user 確認なしで実行する。「要決定: A/B/C」echo + 案提示 + user 確認は **以下のみに限定**:
  - 破壊操作 (file/branch 削除 / force push / DB drop / rm -rf 等)
  - external 送信 (PR 作成 / Slack / Notion / Issue / push)
  - 設計分岐で trade-off が大きい (architecture 変更 / cost 影響 / 後戻り不可) **かつ** ユーザが知らないと回らない情報がある場合
  - flow 系の途中 stage で結果が次 stage の前提を変える場合
  上記以外は推奨案を inline で echo + そのまま実行 (例: 「推奨 B で進める」と 1 行宣言 → 即実行)。`A/B/C 案 + どれにする?` 形式は user 体感を損なうため不要な分岐では使わない。違反 (不要な確認発火) は feedback memory 記録対象。
- **ROI gate**: even for "do everything" instructions, re-confirm individually if ultrathink judges low ROI
- **Bulk / 網羅 keyword**: 「全 N 件 / 網羅 / 一斉 / bulk / 大量」要求は parent Opus inline で sample 縮小判断する前に Sonnet 委譲 (read-only=`explore-agent` / edit=`developer-agent`) を第一選択検討。規模・cost を理由に sample 妥協は「Default delegate to Sonnet」原則違反 (`[[sonnet-delegate-bulk-readonly]]`)
- **pwd check**: verify existence before Read/Bash; check `pwd` before `cd`
- **Pre-delegation git status check**: developer-agent 委譲前に `git status` + `git log --oneline -3` で並列 session 作業 (自分が触っていない untracked / modified、直近 commit が自分由来でない) を確認する。検出時は user に「並列実装あり、進めて OK?」確認必須
- **/memory-save 発火条件 (いずれか満たせば対象)**: (a) commit 3+ file 変更 *かつ* 構造的変更 (refactor / 設計変更 / hook 追加) / (b) incident 対応 (root cause 特定 + fix) / (c) 非自明な調査結果 (再現手順 / 計測値 / 罠) / (d) ユーザ feedback で挙動変更を指示された場合。単純 typo fix / docs 微修正 / config 1 行 toggle は対象外
- **Token budget (Read/Bash output)**: use `limit:` / `offset:` for large files (default ~200 lines); truncate long logs with `| head -N` / `| tail -N`. **Full dump accumulates cost**; prefer serena symbol read when available
- **Subagent prompt context budget**: keep delegation prompts ≤500 words with minimum necessary context. **Never dump full conversation** (cheap per-token subagent cost reverses at high input volume; symmetric with "Completion report budget" in `agents/developer-agent.md`)
- **Multi-clause requests: echo intent first**: requests with ≥2 plausible interpretations (≥2 sentences, multi-item, OR single sentence with ambiguous referent like "X 機能" / "重い" / abstract directives) — echo `understood=X / missing=Y` line + ask 1 clarifying question before acting. Trigger = interpretation branches, not sentence length
- **PR/branch scope 言及時は scope 1 行 echo**: user が「PR を切り出す」「branch 分ける」「scope はあくまで X」等 PR/branch 単位の scope を口頭で示した時、`scope=<対象 file/symbol/diff 範囲> / 除外=<明示的に外す範囲>` 1 行を echo してから着手する。scope ずれ churn (`再度 PR 切り出し` / `スコープ違う` 等) の主因 (retrospective 2026-06-01 検出)
- **`/memory-save` rapid-fire guard**: same session, save within last 5 min → prefer diff-append over new memory
- **`/review-fix-push` pre-launch diff echo**: `git diff --stat | tail -1` one-liner before invoke; surfaces runaway diffs
- **Large-repo session split**: Hard reset (`/clear` or new session) at task boundary; never carry session past 1 task / 3h elapsed / 1000 msg / 40% context (whichever first). 1 task = 1 session principle in large repos
- **長文回答 = 冒頭結論 1 行強制**: chat 応答で 5 行超 + 列挙出す時は **1 行目に結論明示**。違反すると `つまり？` 再質問発生。
- **長文出力 = PREP 法**: 5 行超 + 複数項目は **P**oint→**R**eason→**E**xample→**P**oint 構造。抽象語禁止 (軸/層/土台→具体動作)。詳細: `guidelines/writing/PRINCIPLES.md` PREP section
- **decision 要求応答 = 冒頭に決定の枠を提示**: user に decision 要求する応答 (末尾 `?` + 選択肢 A/B・案 1/2・Yes/No・どちらにする等を含む) は冒頭 1 行に `要決定: <選択肢の枠> / <候補数>` を置く。長さ閾値なし (3 行でも適用)。違反すると `どういうこと?` 再質問発生 (root cause: 冒頭結論が `調査結果` で要決定が末尾に隠れる)。詳細: `guidelines/writing/PRINCIPLES.md` decision-frame-first section

---

## 派生値禁止 (no derived literals)

**全 project 共通 rule**。canonical source (一次データ) から導出可能な派生値 (count / sum / list 長さ / 集計値) を別 file に literal で書かない、参照のみ。

- **書くな**: 「N 語」「N 件」「合計 N」等の数字を canonical 外 file に literal で
- **書け**: 「source: <path>:<line>」参照のみ。list 全体埋めるなら canonical を **そこに移す** (片方削除)
- **例外**: 不変 magic number (HTTP 200 等) / test fixture 内 expected count (test 自体が canonical)
- **self-check**: 数字書く時「これ別の場所で count 可能?」→ Yes なら literal 禁止
- **review 検出**: `grep -nE '[0-9]+ ?(語|件|個|個所|箇所)' <changed_files>` で派生値疑い

(`[[feedback-no-derived-literals]]`)

---

## Public-repo private-data block

**ai-tools repo は public**。社内 product 名 / 社内識別子を `~/ai-tools/` 配下に書き込み禁止。`pre-tool-use.sh` が hard block。詳細 + social-hit term canonical list: `rules/public-repo-private-data-block.md` (`[[public-repo-social-hit-incident]]`)。

**Hook block 対象**: AI 定型語 / カタカナ造語禁止 / 難読漢語 / 非日常英語 (PRINCIPLES.md の各 list から動的抽出)。英日混在語 (lock / commit / deploy / TX 等) は誤検出多発リスクのため hook block 対象外、PRINCIPLES.md (d) 表 + writing review で manual 検出する。
**PRINCIPLES.md list scope 記法**: `**<name> (block|warn-only)**: <terms>` 形式で scope を明示する。新規 list 追加時は適用 target (chat / 外向き prose / commit message 全許可 or 一部制限) を考慮して block か warn-only を選ぶ。**既存 key (`AI定型語` / `カタカナ造語禁止` / `断定語 (warn-only)`) の name 変更禁止** — hook (`hooks/pre-tool-use.sh:_extract_term_list`) が exact match で参照、rename で silent pass する。

---

## Context Management

- **>40% → suggest `/compact`** (cannot auto-execute). `/clear` at task boundary is best savings point (5+ min idle = prompt cache TTL expired → full cache miss). Session 30 min elapsed → propose `/clear` once in chat (single prompt only, no repeat).
- **同一問題の修正が2回連続失敗 → 容量に関わらず `/clear` + prompt 書き直しを提案** (公式 best practice: 失敗アプローチの context 蓄積が主要 failure mode、容量起因の `/clear` とは別軸)。
- Continue: request "generate next-session mega-prompt" → paste into new session
- Uncontaminated question: `/btw` (overlay, not saved to history)

---

## Compounding Engineering

Claude misbehavior / non-obvious success = signal that config is not reflecting reality. Document immediately → auto-avoid next session (Boris style).

- Misbehavior → record in CLAUDE.md / skill / hook
- Non-obvious success → codify as a rule
- Fix 指示に "update CLAUDE.md or related skill" 追記 → config update trigger。Details: `references/compounding-engineering-cycle.md` / `memory-usage.md`

---

## 書く前の自己確認 (chat 除く)

外向き文章 (PR / commit / Issue / Slack / Notion / DD / PRD / RCA / コードコメント等) は **今日の commit を read してから書く** (`git log --since=midnight --pretty=format:'%h %s'`)。hook が書く系 tool (Write / Edit / Bash commit·gh·glab / Slack MCP / Notion MCP) 直前に自動 inject する。inject は 2 source: (1) 作業中 repo の今日 commit + (2) `~/ai-tools` の `guidelines/` `CLAUDE.md` 限定の今日 commit (別 repo 作業時も writing 規約更新が届く設計)。漏れ時は主体的に確認。
コード内コメントを書く時は `guidelines/writing/code-comment.md` を参照する。
