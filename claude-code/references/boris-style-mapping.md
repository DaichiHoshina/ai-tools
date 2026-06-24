# Boris-style mapping

Boris Cherny 流 ([howborisusesclaudecode.com](https://howborisusesclaudecode.com/)) と公式 best practice ([code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices)) の主要 tip を ai-tools 既存機能に照合する。実装方針が異なる箇所は「方針差」列に明記する。

## 取り込み対応表 (13/13 反映済)

| Boris / 公式 tip | ai-tools 既存機能 | 方針差 |
|---|---|---|
| Worktree 並列 (5 instance default) | `/flow` (parallel forced ON, N=formula 駆動) | 5 fixed でなく formula 算出。`references/PARALLEL-PATTERNS.md` |
| PostCompact で core rule 再 inject | `hooks/post-compact-reload.sh` (既存) | 同方針 |
| PostToolUse auto-format | `hooks/post-tool-use.sh` (gofmt / prettier 含む) | 同方針 |
| SessionStart で動的 context 注入 | `hooks/session-start.sh` (既存) | 同方針 |
| auto mode (classifier permission) | `permissions` allow/deny + autonomous default | classifier 利用なし、ENV / settings 静的判定 |
| `/btw` で context を汚さず質問 | CLAUDE.md `Context Management` 明記済 | 同方針 |
| `/clear` 推奨 (2 回失敗時) | `hooks/user-prompt-submit.sh` 150 / 350 msg warn | msg count + 連続失敗の検出を加えた二段構成 |
| Plan → Implement 分離 | `/plan` → `/dev` / `/flow` | 同方針 |
| Adversarial review (fresh context) | `/review` Stage B = reviewer-agent 委譲 | 同方針 |
| Stop hook で verify を確実に実行 (bash + Go / TS / Py) | `hooks/stop-verify.sh` (opt-in、`STOP_VERIFY_ENFORCE=1`、言語別 runner 自動判定 + 不在は graceful skip) | opt-in |
| perspective-diverse verifier panel | `/review --verifier-panel=N` (default OFF、N=3 で 3 lens correctness / consistency / boundary fan-out + 多数決) | opt-in、token N 倍 cost |
| institutional memory (訂正→CLAUDE.md) | auto-memory + `@path` import + retrospective | 同方針 |
| fan-out workflow orchestration | `/workflow` (Workflow tool で deterministic pipeline / parallel / 多数決を script 化、5 テンプレ提供) | `/flow` (PO/Manager/Dev) と直交。review / migrate / research / understand / judge-panel の軽量 fan-out 用 |
| objective stop-condition loop (`/goal`, Ralph Wiggum guard) | `commands/goal.md` (maker-checker 分離 + objective gate 必須 + hard stop 3 種) | Loop engineering 14-step canonical は `references/loop-engineering.md` |

## 未取り込み (CC native でない third-party 命名)

| Tip | 判断 |
|---|---|
| `/loop` / `/schedule` | **未取り込み** (CC native でない、third-party 命名)。cadence 系は user の cron 設定で代替可能、必要時に future task |

## 関連 memory

- `[[work-context-20260620-boris-uptake]]` 2026-06-20 一括取り込み記録
- `[[verifier-panel-first-run-2026-06-20]]` `/review --verifier-panel=3` 初実走計測
