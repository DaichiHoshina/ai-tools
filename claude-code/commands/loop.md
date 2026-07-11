---
allowed-tools: Bash, Read, Write, Edit, TaskCreate, TaskUpdate, TaskList
argument-hint: "init <name> \"<objective>\" --gate \"<cmd>\" | run <name> [--bg] [flags] | status <name> | cron <name> --schedule \"<cron>\""
description: External headless loop — fresh context per iteration via scripts/loop.sh (long-run / cadence / unattended)
---

## /loop - External headless loop (fresh context per iteration)

**Core**: `scripts/loop.sh` が `claude -p` を毎 iteration fresh context で起動し、objective gate (exit code) green まで反復する。同一 session 内で回す `/goal` と違い、context rot / compaction による goal drift が構造的に起きない。iteration 間の継承は state file のみ。

**2-tier 住み分け** (どちらも objective gate + maker/checker 分離):

| | `/goal` (Tier 1) | `/loop` (Tier 2) |
|---|---|---|
| driver | session 内 subagent 反復 | `scripts/loop.sh` + `claude -p` |
| 用途 | 短期 (≤5 iter / ≤30m)、対話中 | 長期 / cadence / 無人 |
| context | 同一 session (rot は 5 iter 上限で許容) | 毎 iteration fresh |

## Syntax

```
/loop init <name> "<objective>" --gate "<cmd>"   # PROMPT.md scaffold + pre-check
/loop run <name> [--bg] [loop.sh flags]          # 実行 (--bg = run_in_background)
/loop status <name>                              # state.md 要約 + 次の一手
/loop cron <name> --schedule "<cron>"            # launchd 定期実行 (条件付き)
```

## Sub-modes

### init

1. `/goal` と同じ 4-condition pre-check (iterative / automated stop-condition / token budget / senior tools)。1 つでも ✗ → 理由を出して abort
2. `~/.claude/loops/<name>/PROMPT.md` を `templates/loop-prompt.md.template` から scaffold し、Objective / Done (gate verbatim) / Constraints / Escalation を埋める
3. state file は `loop.sh` が初回 run で自動生成する (`templates/loop-state.md.template` 準拠)

### run

```bash
~/.claude/scripts/loop.sh --name <name> --gate "<cmd>" [--repo <path>] [--add-dir <path>] \
  [--max-iter 10] [--max-minutes 60] [--max-cost-usd 5.00] [--model sonnet] \
  [--review] [--checker-model haiku] [--checker-cmd "<cmd>"] [--notify]
```

- 初回は必ず `--dry-run` で組立 prompt を確認してから実行する
- `--bg` 指定時は Bash `run_in_background: true` で起動し、完了通知を待つ
- 破壊的 gate (deploy / merge を含む cmd) は禁止。gate は test / lint / build 系の read-only 検証に限る

### status

state.md を Read して 4 行で報告する: Status / 直近 ledger 行 / Lessons 要点 / Blocked 有無。`Status: done` なら **`/memory-save <name>-loop` を Next command として提示** (lessons の恒久化経路)。

### cron

**MVL 順序 enforcement**: state.md に `Status: done` (= `run` の exit 0 実績) がない loop の cron 化は拒否する (`manual run reliable → loop-ify → schedule`)。実績があれば:

```bash
./scripts/install-loop-cron.sh --name <name> --gate "<cmd>" --schedule "<cron>" [--enable]
```

## Exit code 規約 (loop.sh)

| code | 意味 | 対応 |
|---|---|---|
| 0 | gate green | status → memory-save 提示 |
| 2 / 3 / 5 | max-iter / timeout / cost budget | state の Lessons を見て PROMPT.md を直すか scope を割る |
| 4 | no-progress (tree 不変 2 連続) | objective が曖昧。PROMPT.md の Done / Constraints を具体化 |
| 6 | state corrupt (.bak 復元済) | state.md を目視確認して再 run |

## Guard (loop.sh 内蔵、再掲)

hard stop 3 種 (iter / time / cost) + no-progress 検出 + state heading 検証 + gate 出力の private term REDACT + SIGINT で aborted 記録 (自動再開しない)。permission は default `acceptEdits`、`--yolo` は user 明示指示時のみ。

## Headless maker write scope (init 時に必ず考慮)

headless `claude -p` (acceptEdits) の書込可否は 3 段になる: (1) cwd / `--add-dir` 配下の既存 file Edit = auto-accept (2) Write (新規 / 全文上書き) と Bash = deny (3) `~/.claude/` 配下は `--add-dir` を渡しても CLI 組込 guard が Edit ごと deny する。したがって **queue / lessons 等 maker が書く file は `--repo` 内 (untracked) に置き**、PROMPT の Constraints に「更新は Edit tool のみ」を明記する。repo 外で書かせたい dir (memory 等) は `--add-dir` で渡す。state.md への Lessons 書込は deny されるため lessons も repo 内 file に寄せる。実踏: 2026-07-11 memory-brushup loop (iter 空走 4 回)。

## Forbidden patterns

| Pattern | Why |
|---|---|
| gate に merge / push / deploy を含める | 不可逆操作は human review 必須 (loop-engineering.md §30-second check) |
| `run` 実績なしで `cron` | MVL 順序違反 — 「確実に間違い続ける loop」になる |
| subjective gate ("良さそうなら OK") | exit code がなく loop が終了できない |
| maker が書く queue / lessons を `~/.claude/` 配下に置く | CLI 組込 guard で Edit deny → 全 iteration 空振り (§Headless maker write scope) |

## Related

- `scripts/loop.sh` — driver 本体 (exit code / flag の canonical)
- `commands/goal.md` — Tier 1 (session 内短期 loop)
- `references/loop-engineering.md` — 4-condition test / MVL / failure modes / compounding path
- `scripts/install-loop-cron.sh` — launchd 定期実行 installer
