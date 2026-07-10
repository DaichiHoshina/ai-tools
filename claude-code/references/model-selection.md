# Model Selection Guide

Default: **Fable 5** (`claude-fable-5`、settings.json.template `model` key canonical)

## Manual switching

| Task | Recommended | Model ID | Switch |
|--------|-----------|---------|------|
| Batch processing, type conversion, formatting, bulk file processing | Haiku 4.5 | `claude-haiku-4-5-20251001` | `/model` → haiku |
| Simple fixes, investigation, code reading, normal development | **Sonnet 4.6** (default) | `claude-sonnet-4-6` | keep |
| Root cause analysis, design decisions, complex bug analysis, security audit | Opus 4.7 | `claude-opus-4-7` | `/model` → opus |
| Highest-difficulty tasks, session default | **Fable 5** (default) | `claude-fable-5` | `/model` → fable |
| Task difficulty unknown, dynamic switching | Auto (Max subscribers only) | — | `/model` → auto |

**Use explicit `/model` for switching** (natural language triggers risk misfire).

**Auto Mode** (v2.1.111+): Available to Max subscribers with Opus base. `--enable-auto-mode` flag no longer needed. Claude auto-switches model by task difficulty.

## Per-agent auto-assignment

Specified in each agent's frontmatter.

**Policy**: parent (chat) orchestrates with Opus 4.7; subagents split into judgment=Opus 4.7 / execution=Sonnet 4.6 (judgment-Opus is forced to 4.7 since 2026-06-16 due to Opus 4.8 regression — see [[opus-4-8-regression-2026-06]]).

- **Opus 4.7 (judgment subagents)**: po-agent (strategy / design decisions), manager-agent (task decomp / parallelism calculation), root-cause-analyzer (complex bug analysis / 5 Why)
- **Sonnet 4.6 (execution subagents)**: developer-agent (impl / refactor), explore-agent (read-only exploration), verify-app (build / test execution), reviewer-agent (12-perspective review)

## Effort levels

Control thinking depth per session via `--effort` flag or `/effort`.

| Level | Use | Example |
|--------|------|-----|
| `low` | Simple questions, formatting fixes | `claude --effort low -p "fix typo"` |
| `medium` | Light development / investigation (cost-conscious) | `claude --effort medium` |
| `high` | Normal development | `claude --effort high` |
| `xhigh` | High-difficulty tasks / design decisions / deep analysis (Opus only) | `claude --effort xhigh` |
| `max` | Hardest debugging / large-scale RCA. Not for daily use (reports of overthinking backfire) | `claude --effort max` |

> `xhigh` is Opus-only (v2.1.111+; check `claude --help` `--effort` choices). Opus 4.7 default effort is `high`. Other models fall back to `high`.

For scripts with `--print`, also specify `--fallback-model sonnet` for auto-fallback on overload.

## Verifier consult の 2 タイミング (advisor pattern)

出典は Claude API の advisor tool (beta、`advisor-tool-2026-03-01`) に関する Anthropic の測定知見。executor (下位 model) が advisor (上位 model) に相談する最適タイミングは次の 2 点に集約される。

| タイミング | 位置 | 相談内容 |
|---|---|---|
| (a) approach 確定前 | 探索的 read を数回終えた直後、最初の write の前 | 実装方針の妥当性 |
| (b) 完了宣言前 | file 書込と test 結果が transcript に載った後 | done 判定の妥当性 |

Anthropic の測定では、この 2 点で consult すると総 tool call 数と会話長が減り、品質も上がる。

### ai-tools への移植

Claude Code では API の advisor tool 自体は使えない。代わりに Generator → Verifier loop (developer-agent → reviewer-agent / verify-app) のタイミング規範として同じ 2 点を適用する。quality 最優先 mode では次の 2 つを必ず挟む。

- 実装開始前に approach 確認を行う (最初の write の前に Verifier へ方針を諮る)
- done 宣言前に verify を行う (test 結果が出揃った後に Verifier が accept / reject を返す)

### API 側要点の備忘

- executor と advisor の pair には制約がある (advisor は Sonnet 4.6 以上かつ executor と同等以上)
- advisor は tool を持たず、transcript 全体を読んで助言だけを返す
- advisor の `max_tokens` を 2048 に絞ると出力が約 1/7 になり、品質劣化はない
- prompt caching は advisor call 3 回以上で黒字になる
- Haiku executor には turn 2 での consult nudge が +7pt 効くが、Opus executor には逆効果
