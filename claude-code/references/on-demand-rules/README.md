# On-demand rules index

`references/on-demand-rules/` 配下は auto-load 対象外。下記 trigger を満たしたときのみ該当 file を Read する。

## Trigger 一覧

| Trigger | 参照 file |
|---|---|
| md heading rename | `markdown-anchor-sync.md` |
| EN refactor、`/claude-update-fix` | `en-conversion-protected.md` |
| handler・controller・resolver・api・endpoint 実装 | `api-design.md` |
| `/review`・`/review-fix-push`・`comprehensive-review` skill 発火時 | `review-noise-discard.md` |
| `hooks/` の block・warn 系編集時 | `measure-before-hook-change.md` |
| `commands/`・`agents/`・`references/` の heading・YAML key・step 番号改変時 | `sync-canonical-with-bats.md` |
| incident 調査 (5xx・latency・lock 障害の RCA) | `incident-local-repro-not-root-cause.md` |
| 機能の複数 PR 分割・release 順設計 | `pr-release-order.md` |
| chain PR (base≠main) 操作 | `chain-pr-main-merge.md` |
| screenshot を外向き text に添付 | `screenshot-resize.md` |
| feature flag・maintenance flag・config 切替 release | `feature-flag-deploy-order.md` |
| commit・PR・issue・外向き post 起草時 | `ai-output.md` |
| `git worktree add` 発行・worktree 手順提案時 | `worktree-branch-name-match.md` |
| ai-tools で作業開始・main 反映 (wt 隔離 / ff-merge / sync) 時 | `ai-tools-worktree-flow.md` |
| git merge 承認判断・interrupt 後の再実行・既存 PR branch への push | `git-safety-ops.md` |
| report / HTML 生成 command 実行・生成物の保存先指定 | `report-output-outside-repo.md` |
| PR checks で集約 job のみ FAILURE (CI fail 調査時) | `ci-flaky-aggregate-job.md` |
| 実装中に PRD / DesignDoc と実装の乖離を検出した時 | `dd-first-update.md` |
| MCP 外部 API 利用時・PII 取扱時・AWS SSM 操作時 | `enterprise-security-mcp-pii-ssm.md` |
| public-repo-private-data-block の incident 経緯を確認したい時 | `public-repo-incident-history.md` |

## 運用

- CLAUDE.md 本文は「trigger 一覧: `references/on-demand-rules/README.md`」の 1 行 pointer のみとし、trigger 詳細はここに集約する
- 新 rule を追加するときは本 table に 1 行追加し、対応 file を同じ dir に置く
- 削除するときは table 行と file の両方を消す
