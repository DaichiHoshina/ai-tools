# retrospective: agent-oversight-extension (2026-06-19)

## task / goal

agent 出力のスキーマ強制・監視 gate・hook 失敗 test を 5 Phase に分けて実装した。
PO Gate v2 で品質審査を通過後、Manager session limit により parent 直起票 (team_via_parent_proxy mode) で dev9 に委譲。

## Phase 構成

| Phase | 内容 | 対象ファイル数 |
|-------|------|--------------|
| 0 | hook event payload map canonical 化 | 1 |
| 1 | 4 agent に output schema trailer 規約を導入 | 5 |
| 2 | 監視 gate を 3 file に追加 (brainstorm / design-review / Discovery Routing) | 3 |
| 3 | post-tool-use-failure stub を bats で test 固定 | 1 |
| 4 | bench + sync 完了 record + retrospective | 1 |

## stage 履歴

### retry

- stage1 (Phase 0/1 相当): 1 回 (dev4 → dev4-fix1)
  - 原因: user が dev4 成果物を reject (scope 超過 or 品質不足)
- Phase 2/3/4: retry 0 回

### bundle

- stage1: 3 bundle (dev2/dev3/dev4 が同一 sweep で 1 commit に混入)
  - 原因: Manager が file_count=1 制約を task に明示していなかった
- Phase 2/3/4: bundle 0 回 (file_count=1 + bundle_justification 強制が機能)

## hook-bench 結果 (warmup=5, runs=15)

前回 log 不在のため今回値を baseline として記録する。退行判定は次回以降。

| hook | median | p95 |
|------|--------|-----|
| bash spawn (baseline) | 34ms | - |
| session-start.sh | 128ms | 155ms |
| user-prompt-submit.sh | 123ms | 135ms |
| post-compact-reload.sh | 101ms | 116ms |
| session-end.sh | 102ms | 109ms |
| setup.sh | 66ms | 90ms |
| pre-tool-use.sh | 81ms | 94ms |
| post-tool-use.sh | 97ms | 105ms |
| post-tool-use-failure.sh | 83ms | 92ms |
| permission-denied.sh | 88ms | 102ms |
| subagent-start.sh | 92ms | 102ms |
| subagent-stop.sh | 87ms | 102ms |
| task-completed.sh | 86ms | 103ms |
| teammate-idle.sh | 93ms | 102ms |
| worktree-remove.sh / pre-compact.sh / stop.sh / stop-failure.sh / serena-hook.sh | skip (副作用あり) | - |

退行判定: 前回 log 不在 → baseline 記録のみ (次回実行時に比較可能)

## compounding engineering record

### PO Gate v1 → v2 進化

- v1: literal 固定のみ (単純な入力チェック)
- v2: 8 観点チェック (scope / file_count / bundle_justification / quality / type-safety / DoD / verify / impl_notes)
- 今 sweep で v2 が実際に機能し、bundle 違反 0 を達成した

### file_count=1 + bundle_justification 強制の実証

- Phase 2/3/4 で bundle 0 を確認
- task prompt に `file_count: 1, bundle_justification: null` を明示すること → developer が 1 task = 1 file を厳守
- stage1 の bundle=3 との対比で効果が明確

### team_via_parent_proxy mode の品質担保

- Manager session limit により PO が直接 dev9 に委譲
- 品質担保 chain (PO Gate → verify → impl_notes) は維持
- agent 階層の一部が欠けても chain が機能することを確認

## next sweep 候補

### Task #12: 原則の明文化

対象: CLAUDE.md / commands/flow.md / agents/manager-agent.md
内容:
- parent 監視責任 (PO が Developer 成果物を直接確認する義務)
- 1 dev = 1 file 原則を agent 定義に追加
- bundle 違反検出を Manager の Gate 項目に組み込む

### agent-team-contract 拡張

対象: references/agent-team-contract.md §1.1
内容: `task_type: edit | ops` field 追加の検討
- edit: ファイル変更を伴う実装タスク
- ops: commit / push / sync 等の操作タスク
- 目的: Manager が task 性質をより正確に把握して委譲する
