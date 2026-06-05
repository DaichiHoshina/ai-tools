# Session Efficiency — 詳細 bullets

CLAUDE.md `## Session Efficiency` section の本文詳細。CLAUDE.md には pointer のみ残す。

---

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
