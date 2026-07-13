# Boris-style mapping

Boris Cherny 流 ([howborisusesclaudecode.com](https://howborisusesclaudecode.com/)) と公式 best practice ([code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices)) の主要 tip を ai-tools 既存機能に照合する。実装方針が異なる箇所は「方針差」列に明記する。

## 取り込み対応表 (2026-06-20 初回照合 14 件 + 2026-07-13 再照合 5 件)

| Boris / 公式 tip | ai-tools 既存機能 | 方針差 |
|---|---|---|
| Worktree 並列 (5 instance default) | `/flow` (parallel forced ON, N=formula 駆動) | 5 fixed でなく formula 算出。`references/PARALLEL-PATTERNS.md`。Boris 本人は worktree でなく複数 git checkout 派 (local 5 + remote 5-10 session、worktree はチーム他 member の流儀。2026-07-13 deep-research 確認) |
| PostCompact で core rule 再 inject | `hooks/post-compact-reload.sh` (既存) | 同方針 |
| PostToolUse auto-format | `hooks/post-tool-use.sh` (gofmt / prettier 含む) | 同方針 |
| SessionStart で動的 context 注入 | `hooks/session-start.sh` (既存) | 同方針 |
| auto mode (classifier permission) | `permissions` allow/deny + autonomous default | classifier 利用なし、ENV / settings 静的判定 |
| `/btw` で context を汚さず質問 | CLAUDE.md `Context Management` 明記済 | 同方針 |
| `/clear` 推奨 (2 回失敗時) | `hooks/user-prompt-submit.sh` 150 / 350 msg warn | msg count + 連続失敗の検出を加えた二段構成 |
| Plan → Implement 分離 | `/plan` → `/dev` / `/flow` | 同方針。Boris は task の約 80% を plan mode 起点にし、plan 合意で成功率 2-3 倍、合意後は auto-accept edits へ二段遷移 (2026-07-13 確認) |
| Adversarial review (fresh context) | `/review` Stage B = reviewer-agent 委譲 | 同方針 |
| Stop hook で verify を確実に実行 (bash + Go / TS / Py) | `hooks/stop-verify.sh` (opt-in、`STOP_VERIFY_ENFORCE=1`、言語別 runner 自動判定 + 不在は graceful skip) | opt-in。Boris の用途 (test 失敗時に完了報告を止めて修正継続) と一致を 2026-07-13 に確認 |
| perspective-diverse verifier panel | `/review --verifier-panel=N` (default OFF、N=3 で 3 lens correctness / consistency / boundary fan-out + 多数決) | opt-in、token N 倍 cost |
| institutional memory (訂正→CLAUDE.md) | auto-memory + `@path` import + retrospective | 同方針 |
| fan-out workflow orchestration | `/workflow` (Workflow tool で deterministic pipeline / parallel / 多数決を script 化、5 テンプレ提供) | `/flow` (PO/Manager/Dev) と直交。review / migrate / research / understand / judge-panel の軽量 fan-out 用 |
| objective stop-condition loop (`/goal`, Ralph Wiggum guard) | `commands/goal.md` (maker-checker 分離 + objective gate 必須 + hard stop 3 種) | Loop engineering 14-step canonical は `references/loop-engineering.md` |
| `/loop` / `/schedule` (cadence loop) | `commands/loop.md` + `scripts/loop.sh` (external headless loop) + `scripts/install-loop-cron.sh` (launchd) | schedule は manual run 実績 (Status: done) を持つ loop のみ許可 (MVL 順序 enforcement) |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` で早期 auto-compact | 採用しない。手動 「>40% → /compact」 rule (CLAUDE.md) を維持 | 値は model context 上限で cap されるため 200k 級では無意味。公式も 1M context model 以外は未設定を推奨 ([env-vars docs](https://code.claude.com/docs/en/env-vars.md)、2026-07-13 確認) |
| PR comment `@.claude` → CLAUDE.md 自動更新 | `/retrospective` + `/promote` (知見 → CLAUDE.md / skill 昇格 flow) | PR comment 起点でなく session 起点。昇格先を CLAUDE.md 限定にせず skill / rule も選ぶ |
| verify → simplify → ship (`/go` pattern) | `/review-fix-push` (review → fix → 回帰 check → push) + code-simplifier agent | 同方針。simplify は必須 step でなく必要時のみ |
| `claude agents` control plane / `--teleport` / `--name` / `/color` | 対象外 (CLI product 機能で config 化する要素がない) | — |
| adversarial review 2 段構成 (初回並列 review → 反論専任 5 subagent が false positive を落とす) | 未採用。`/review --verifier-panel` は lens 直交 + 多数決型で構造が異なる | 将来候補。verifier-panel の需要実績が出てから第 2 波反論 stage の追加を判断する (2026-07-13 deep-research 確認) |

## 関連 memory

- `[[work-context-20260620-boris-uptake]]` 2026-06-20 一括取り込み記録
- `[[verifier-panel-first-run-2026-06-20]]` `/review --verifier-panel=3` 初実走計測
- 2026-07-13 deep-research workflow で 19 source / 71 claims → 3 票反証検証で 22 claims confirmed、本表の再照合 5 件はその結果
