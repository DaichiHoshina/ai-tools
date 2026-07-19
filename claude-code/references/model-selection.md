# Model Selection Guide

Default: **Fable 5** (`claude-fable-5`、settings.json.template `model` key canonical)

## Manual switching

| Task | Recommended | Model ID | Switch |
|--------|-----------|---------|------|
| Batch processing, type conversion, formatting, bulk file processing | Haiku 4.5 | `claude-haiku-4-5` | `/model` → haiku |
| Simple fixes, investigation, code reading, normal development | Sonnet 5 | `claude-sonnet-5` | `/model` → sonnet |
| RCA / 設計判断 / 難所全般 / session default | **Fable 5** | `claude-fable-5` | `/model` → fable |
| Task difficulty unknown, dynamic switching | Auto | — | `/model` → auto |

**Use explicit `/model` for switching** (natural language triggers risk misfire).

**Fable 節約運用**: 日常 session を sonnet / auto にし、難所だけ `/fable <task>` で model override 委譲する (`commands/fable.md`)。

**Fable 思考専用運用** (user 指示 2026-07-13、2 回明示): Fable session では判断・設計・統合方針の決定だけを parent が持ち、内容が確定した編集 / commit / 定型生成は developer-agent (Sonnet) へ委譲する。inline 例外 (1 行 fix 等) でも Fable の長文生成を伴うなら委譲を優先する。

**Auto Mode** (v2.1.111+): `/model` → auto で有効化すると Claude が task 難易度で model を自動切替する (`--enable-auto-mode` flag は不要になった)。

## Per-agent auto-assignment

Specified in each agent's frontmatter.

**Policy** (2026-07-11〜): 初手の戦略判断 = Fable 5 / 他 subagent = Sonnet 5。

- **Fable 5 (strategy)**: po-agent (strategy / design decisions — session の初手判断のみ最上位 tier)
- **Sonnet 5 (judgment + impl + execution)**: manager-agent (task decomp / parallelism calculation), root-cause-analyzer (complex bug analysis / 5 Why), developer-agent (impl / refactor), explore-agent (read-only exploration), verify-app (build / test execution), reviewer-agent (12-perspective review), design-review-agent (live UI/UX review)

決定履歴:

- 2026-06-16: judgment 系を Opus 4.7 に pin (Opus 4.8 regression 回避)
- 2026-07-10: 実行系を Sonnet 5 に切替 (judge-panel 34 対 27 で採用)
- 2026-07-11: Opus 4.7 pin 解除。po-agent = Fable 5、判断系他 3 agent (manager / developer / RCA) = Sonnet 5 (user 決定: 初手判断のみ Fable、他は Sonnet 5 相当が適切)
- 2026-07-19: Manual switching 表の Opus 4.7 行を削除した。根拠の 4.8 regression は pin 解除後に再検証しておらず、RCA / 設計判断は Fable 5 と `/fable` 委譲で覆うためだ

再測定の契機: 新 model の追加時か、割当先の品質劣化を疑う兆候が出た時に judge-panel を再実行して割当を見直す。

## Subagent / Workflow の model downgrade

subagent は default で session model を継承する。Fable session では機械的な段を明示 downgrade する。純 fetch / 機械抽出の段のみ `haiku` に落とす。verify / judge / synthesize は `sonnet`、最終品質が要る段のみ継承 (省略) とする。分析を含む探索 (explore-agent 相当) は `haiku` に落とさず sonnet を維持する (explore-agent frontmatter = Sonnet 5 と同じ基準)。走行中の workflow へ適用するには TaskStop → script に model 追記 → `resumeFromRunId` 再開 (完了済 agent は cache が効く)。

- 実測 (2026-07-13 deep-research): downgrade 後でも 102 agent / 355 万 subagent tokens / 約 10 分。全段 Fable 継承なら数倍かかる。徹底調査系は発火前に「claims 上限 × 3 票 ≒ verify agent 数」で概算し、必要なら claims 縮小か budget 指定 (`+500k` 形式) を添える
- 1M context 変種 (`[1m]`) は attention overhead で応答が体感遅い。大規模 codebase 探索など必要な時のみ `/model` で都度切替する

## Effort levels

Control thinking depth per session via `--effort` flag or `/effort`.

| Level | Use | Example |
|--------|------|-----|
| `low` | Simple questions, formatting fixes | `claude --effort low -p "fix typo"` |
| `medium` | Light development / investigation (cost-conscious) | `claude --effort medium` |
| `high` | Normal development | `claude --effort high` |
| `xhigh` | High-difficulty tasks / design decisions / deep analysis | `claude --effort xhigh` |
| `max` | Hardest debugging / large-scale RCA. Not for daily use (reports of overthinking backfire) | `claude --effort max` |

> `xhigh` は Fable 5 / Sonnet 5 / Opus 4.8 / 4.7 で使える (Opus 限定は旧情報。公式 effort doc 準拠)。
> Fable 5 は `high` default で開始する。低 effort でも旧 model の `xhigh` を上回ることが多く、task 完了までが不要に長い時は effort を下げる。
> Sonnet 5 の cross-model 目安: `medium` ≒ Sonnet 4.6 `high`、`high` ≒ Sonnet 4.6 `max`。
> 新 model 群 (Fable 5 / Sonnet 5 / Opus 4.7+) は effort を厳格に守る。複雑な問題で推論が浅い場合は prompt で粘らず effort を上げるのが第一手になる。
> ultracode は API の effort level ではなく、`xhigh` + multi-agent workflow 常時許可の組合せを指す (公式 effort doc 記載)。

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
