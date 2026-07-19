---
allowed-tools: Read, Edit, Write, Glob, Bash, AskUserQuestion
argument-hint: "[--all-reject]"
description: 夜間 sleep pipeline が staging した改善提案を朝に triage する (adopt / hold / reject)
---

## /sleep-review - 夜間提案の triage (SkillOpt-Sleep Adopt 段)

**Core**: `scripts/sleep-cron-run.sh` が夜間に staging した `memory/sleep-proposals-<date>.md` を user 承認で消化する。config / skill への反映は必ずこの対話 command を通す。夜間 process は staging までしか行わない。

## Flow

1. **staged 収集**: `~/ai-tools/memory/sleep-proposals-*.md` を Glob する (`.rejected.md` / `.adopted.md` は除く)。0 件なら「staged なし」と報告して終了する
2. **warn flag 確認**: `~/.claude/sleep/tracked-change-warn` があれば maker の tracked file 変更 (restore 済) を先に報告し、flag を削除する
3. **proposal 表示 + triage**: staged file を Read する。proposal (`### P<n>:`) ごとに 5 field を提示し、AskUserQuestion で adopt / hold / reject を 1 回 1 問で聞く
4. **adopt の適用** (type 別に既存 flow へ委譲し、新規 logic を書かない):

| Type | 適用経路 |
|---|---|
| new-skill | `/skill-add` へ誘導 (skill-creator と skill-lint、sync を含む) |
| skill-edit / hook / command | Target を full Read し、diff 提示と承認後に Edit する。skill は `skill-lint` を実行し、`./claude-code/sync.sh to-local --yes` で反映する |
| claude-md | `/promote` と同 protocol で適用する (full Read + diff 提示 + 承認後 Edit + sync) |
| cursor | `cursor/` 配下の edit か `/cursor-review` へ誘導する |

5. **台帳更新**: `~/ai-tools/memory/pending-improvements.md` を read-modify-write する (`/retrospective` Phase 5 と同形式)。adopt は completed へ、reject は理由付きで remaining へ書き、hold は pending に残す
6. **file 後始末**: 処理し終えた staged file を rename する。adopt が 1 件以上あれば `.adopted.md`、全 reject なら `.rejected.md` にする。hold が残る file は rename せず翌朝に再提示する (staged 3 件滞留で夜間 mine は止まる)

## Guard

- hook 編集を adopt する場合は `references/on-demand-rules/measure-before-hook-change.md` の baseline 計測を先に行う
- config 書き換えは必ず diff 提示と user 承認を経る。無承認 Edit は禁止だ
- `--all-reject` は全 staged を一括 reject して `.rejected.md` に rename する (滞留掃除用)

## Related

- `scripts/sleep-cron-run.sh` — 夜間 staging の driver (exit code / gate の canonical)
- `scripts/sleep-harvest.sh` — Mine 入力の集計
- `commands/retrospective.md` — 週次の深掘り版。sleep は日次の pre-computed 提案消化
- `references/loop-engineering.md` — MVL / compounding path (state → memory → skill)
