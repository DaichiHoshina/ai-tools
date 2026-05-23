# Markdown anchor 同期 rule

`claude-code/` 配下の markdown heading を rename / EN 化 / 表記変更する commit は、bats test の exact-match anchor・他 file の cross-reference slug・`PARALLEL-PATTERNS.md` の literal を破壊するリスクがある。

## リスクの発生源

| 変更種別 | 破壊対象 |
|---------|---------|
| heading rename / EN 化 | `tests/` 内 `require_anchor` / `grep -qF` 期待値 |
| slug 変更 | 他 file の `#anchor-slug` cross-reference |
| `PARALLEL-PATTERNS.md` 書き換え | `parallel-consistency.bats` の `allowed_summaries` / `forbidden_phrases` exact-match |

## 必須手順（heading 変更前に実行）

変更対象 heading の旧表記 `<heading>` および旧 slug `<slug>` を以下でチェックする。

```bash
# bats 期待値に使われているか確認
grep -rn '"<heading>"' claude-code/tests/
grep -rn "'<heading>'" claude-code/tests/

# cross-reference anchor として使われているか確認
grep -rn '#<slug>\b' claude-code/
```

ヒットがある場合は、heading 変更と同一 commit で bats・cross-ref を更新する。

## `/review` skill 必須オプション

markdown heading を変更する PR のレビューは必ず以下で実行する。

```
/review --focus=consistency
```

最低 iter 2 まで回す（初回 review では bats anchor 破綻を検出できないケースがある）。

## 過去事例（2026-05-23、commit `c67ade1`）

EN 化 commit で以下 3 heading を rename した。

- `## critical path 短縮判定式` → `## Critical-path reduction formula`
- 他 2 heading も同様に EN 化

結果:

- `parallel-consistency.bats:50-52` の exact-match anchor が破綻 → 2 test failed
- `agent-frontmatter.bats:87` の anchor が破綻 → 2 test failed
- `flow.md` の `#worktree-applicability-flow` slug を初回誤記し、bats が catch しない caller が `manager-agent.md` / `po-agent.md` に残留した

review iter 2 で初めて発覚した。iter 1 では見逃した。

## 適用範囲

- 全 markdown rename PR（`claude-code/` 配下）
- developer-agent 委譲 prompt にも、markdown heading 変更が含まれる場合はこの rule を明記する
