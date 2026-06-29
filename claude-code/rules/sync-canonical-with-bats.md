# sync-canonical-with-bats (canonical edit と bats literal の同時更新)

`commands/` / `agents/` / `references/` 配下の **bats が `grep -F` で literal match 検証している heading・section title・YAML key 等を改変**するときは、同 commit で対応 bats も同時更新する。

refactor / 圧縮 / 改名のみで bats 連動更新を怠ると、test は silent fail 状態で残り、次の `bats -r tests/` 実行までドリフトが顕在化しない。

## 原則

canonical file (`commands/*.md` / `agents/*.md` / `references/*.md`) の以下要素を変更する場合、同 commit 内で `tests/` 配下の対応する `grep -F` / `grep -cF` literal を同期する。

- 見出し (`## …` / `### …`) の文言改変・改名・短縮・圧縮
- YAML field key (`oversight_trigger:` / `modify_target_task_ids:` 等)
- step 番号 + 名称 (`6.3. **PO Gate**` 等の番号付き bullet)
- enum literal (`verdict: pass | fail | modify` 等)
- 構造化 block の title (`## Allocation plan format` 等)

## 適用範囲

- `tests/integration/*.bats` / `tests/unit/*.bats` で `grep -F` / `grep -cF` / `grep -cE` を使って canonical literal を検証している箇所が対象
- prose 本文・コード block 中身・コメントの改変は対象外 (bats が literal match していないため)

## 手順

```bash
# 1. canonical edit 前に該当 literal を bats で grep してヒット箇所を把握する
grep -rn 'grep -cF "<old-literal>"' tests/

# 2. canonical edit と同 commit で bats 側の literal も差し替える
# 3. bats を該当 file 単位で実行して PASS を確認する
bats tests/integration/<target>.bats
```

## 違反時

drift を発見したら、`canonical 改変 commit の subject` を git blame で特定して memory に `feedback-bats-drift-*.md` を残す。次回以降の同種改修で再発しないよう、改修 PR template / commit hook で bats grep 結果差分を warn する自動化を検討する。

## Why

2026-06-29 session で `tests/integration/po-oversight-gate.bats` test #5 が `a6c1fca refactor(commands): flow.md を 150 行に圧縮` 由来の literal drift で silent fail 状態だったことを発見した (`**PO Gate (Manager allocation oversight)**` → `**PO Gate**` への短縮で grep miss)。

bats を回さない限り顕在化しないため、`/flow` orchestration の品質 gate が事実上 1 件分機能しない状態が約 4 日間継続していた。同種 drift の再発防止のため canonical edit と bats literal を同時更新するルールを明文化する。

## 参照

- `tests/integration/po-oversight-gate.bats` — 本 rule trigger となった drift 検出箇所
- `references/retrospectives/2026-06-22_manager-hallucination.md` — drift 修正を含む改修 retrospective
- `references/compounding-engineering-cycle.md` — incident → rule 化サイクル
- CLAUDE.md `## Compounding Engineering`
