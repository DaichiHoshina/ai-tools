# Verification 自動計測 (週次) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** retrospective の Verification 節で人力計測していた log 集計を、週次 cron が数値だけ自動追記する仕組みに置き換える。

**Architecture:** 計測定義を `verification-metrics.tsv` (id / 説明 / command の 3 列) に分離し、`verification-report.sh` が全 metric を実行して `~/ai-tools/memory/pending-improvements.md` 末尾へ「### 自動計測 YYYY-MM-DD」block を追記する。既存の週次 `maintenance-cron-run.sh` に呼び出しを 1 段足す。判断 (増減の解釈・採否) は次回 retrospective の人に残す。

**Tech Stack:** bash / awk / jq / bats (既存 `claude-code/tests/` の流儀)

## Global Constraints

- 作業は worktree で行い、完了後 main へ ff-merge する (`references/on-demand-rules/ai-tools-worktree-flow.md`)
- macOS の `date` を使う (`date -v-7d`、GNU 形式 `date -d` は不可)
- script 失敗で maintenance run 全体を巻き込まない: metric 単位で握り、`verification-report.sh` は常に exit 0
- 対象 log 不在は `N/A`、command 失敗・空出力は `ERR` と記録する (計測断絶を可視化)
- pending-improvements.md への操作は末尾追記のみ。既存行の書き換え・削除はしない
- code comment は最小限 (default 書かない / 上限 2 行 / What 言い換え禁止)
- TSV の command field 内に literal tab を入れない (tab は列区切り)

---

### Task 1: verification-report.sh 本体 + bats test

**Files:**
- Create: `claude-code/scripts/verification-report.sh`
- Test: `claude-code/tests/integration/verification-report.bats`

**Interfaces:**
- Consumes: なし (独立)
- Produces: `verification-report.sh` — env `VERIFICATION_METRICS_TSV` / `VERIFICATION_TARGET_MD` / `VERIFICATION_CUTOFF` で入出力を差し替え可能。metric command には env `CUTOFF` (YYYY-MM-DD) が渡る。常に exit 0 (TSV 不在等の設定 error のみ exit 2)

- [ ] **Step 1: failing test を書く**

`claude-code/tests/integration/verification-report.bats` を以下の内容で作る:

```bash
#!/usr/bin/env bats
# verification-report.sh の追記 block 形式と ERR/N/A 経路を検証する

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/verification-report.sh"
  TMPDIR_T="$(mktemp -d)"
  export VERIFICATION_TARGET_MD="$TMPDIR_T/pending.md"
  export VERIFICATION_METRICS_TSV="$TMPDIR_T/metrics.tsv"
  export VERIFICATION_CUTOFF="2026-07-13"
  printf '## Verification\n\n- 既存行はそのまま残る\n' > "$VERIFICATION_TARGET_MD"
  # 列区切りは literal tab。ok / 空出力(ERR) / N/A の 3 経路 + comment 行 skip
  {
    printf '# comment 行は skip される\n'
    printf 'metric-ok\t件数が出る例\techo 42\n'
    printf 'metric-err\t空出力は ERR\ttrue\n'
    printf 'metric-na\tlog 不在は N/A\tif [ -f /nonexistent-log ]; then echo 1; else echo N/A; fi\n'
    printf 'metric-cutoff\tCUTOFF が届く\techo "$CUTOFF"\n'
  } > "$VERIFICATION_METRICS_TSV"
}

teardown() { rm -rf "$TMPDIR_T"; }

@test "追記 block: header + 各 metric 1 行、既存本文は不変" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '^### 自動計測 20' "$VERIFICATION_TARGET_MD"
  grep -q '^- metric-ok: 42 (件数が出る例)$' "$VERIFICATION_TARGET_MD"
  grep -q '^- 既存行はそのまま残る$' "$VERIFICATION_TARGET_MD"
}

@test "空出力の metric は ERR と記録される" {
  run bash "$SCRIPT"
  grep -q '^- metric-err: ERR (空出力は ERR)$' "$VERIFICATION_TARGET_MD"
}

@test "log 不在 metric は N/A と記録される" {
  run bash "$SCRIPT"
  grep -q '^- metric-na: N/A (log 不在は N/A)$' "$VERIFICATION_TARGET_MD"
}

@test "metric command に CUTOFF が env で渡る" {
  run bash "$SCRIPT"
  grep -q '^- metric-cutoff: 2026-07-13 (CUTOFF が届く)$' "$VERIFICATION_TARGET_MD"
}

@test "TSV 不在なら exit 2 で target md は不変" {
  rm "$VERIFICATION_METRICS_TSV"
  before="$(cat "$VERIFICATION_TARGET_MD")"
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [ "$(cat "$VERIFICATION_TARGET_MD")" = "$before" ]
}
```

- [ ] **Step 2: test が fail することを確認する**

Run: `bats claude-code/tests/integration/verification-report.bats`
Expected: 全 5 test FAIL (script 不在)

- [ ] **Step 3: script を実装する**

`claude-code/scripts/verification-report.sh` を以下の内容で作る (`chmod +x` する):

```bash
#!/usr/bin/env bash
# 週次 Verification 自動計測 (maintenance-cron-run.sh から呼ばれる)
# verification-metrics.tsv の各 metric を実行し、pending-improvements.md 末尾へ数値 block を追記する
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METRICS_TSV="${VERIFICATION_METRICS_TSV:-${REPO_ROOT}/scripts/verification-metrics.tsv}"
TARGET_MD="${VERIFICATION_TARGET_MD:-${HOME}/ai-tools/memory/pending-improvements.md}"
export CUTOFF="${VERIFICATION_CUTOFF:-$(date -v-7d +%Y-%m-%d)}"

if [[ ! -f "$METRICS_TSV" ]]; then
  echo "ERROR: metrics TSV が見つからない: $METRICS_TSV" >&2
  exit 2
fi
if [[ ! -f "$TARGET_MD" ]]; then
  echo "ERROR: 追記先 md が見つからない: $TARGET_MD" >&2
  exit 2
fi

block="### 自動計測 $(date +%Y-%m-%d) (window: ${CUTOFF} 以降)"$'\n'
while IFS=$'\t' read -r id desc cmd; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  value="$(bash -c "$cmd" 2>/dev/null)"
  [[ -z "$value" ]] && value="ERR"
  block+="- ${id}: ${value} (${desc})"$'\n'
done < "$METRICS_TSV"

printf '\n%s' "$block" >> "$TARGET_MD"
echo "appended: $TARGET_MD"
```

実装 note: `value=` の行に `|| value=ERR` を付けない。`grep -c` は 0 件時に「0 を出力して exit 1」するため、exit code で判定すると 0 件が ERR に化ける。空出力判定のみ使う。

- [ ] **Step 4: test が pass することを確認する**

Run: `bats claude-code/tests/integration/verification-report.bats`
Expected: 5 tests, 0 failures

- [ ] **Step 5: commit**

```bash
git add claude-code/scripts/verification-report.sh claude-code/tests/integration/verification-report.bats
git commit -m "feat(verification): Verification 自動計測 script と bats test を追加する"
```

---

### Task 2: verification-metrics.tsv (初期 6 metric) + 実 log smoke

**Files:**
- Create: `claude-code/scripts/verification-metrics.tsv`

**Interfaces:**
- Consumes: Task 1 の env 仕様 (`CUTOFF` が YYYY-MM-DD で渡る)
- Produces: 初期 6 metric の定義 (id は下記のとおり固定)

- [ ] **Step 1: TSV を作る**

列区切りは literal tab (エディタで tab を直接入力する)。command 内で `$CUTOFF` (ISO timestamp の lexicographic 比較) を使う:

```text
# id<TAB>説明<TAB>command (stdout に値 1 個、log 不在は N/A)
jp-100char	100字超文 warn/block 件数	f=$HOME/.claude/logs/jp-quality-block.log; if [ -f "$f" ]; then awk -v c="$CUTOFF" '$1 >= c' "$f" | grep -E ' \| (warn|block)$' | grep -c '100字超文'; else echo N/A; fi
jp-ng-block	禁止語 block hit 件数	f=$HOME/.claude/logs/jp-quality-block.log; if [ -f "$f" ]; then awk -v c="$CUTOFF" '$1 >= c' "$f" | grep ' | block$' | grep -vcE 'structural:|unknown-en:'; else echo N/A; fi
jp-unknown-en-12	unknown-en 今回 12 語の出現数	f=$HOME/.claude/logs/jp-quality-block.log; if [ -f "$f" ]; then awk -v c="$CUTOFF" '$1 >= c' "$f" | grep 'unknown-en:' | grep -oE '(gate|adopt|evidence|drift|triage|maintenance|cost|cap|prose|mask|bullet|green)' | wc -l | tr -d ' '; else echo N/A; fi
jp-kanryo	「完了」warn 件数	f=$HOME/.claude/logs/jp-quality-block.log; if [ -f "$f" ]; then awk -v c="$CUTOFF" '$1 >= c' "$f" | grep -vE 'structural:|unknown-en:' | grep ' | warn$' | grep -c '完了'; else echo N/A; fi
session-split-force	force split 件数	f=$HOME/.claude/logs/session-split-warn.log; if [ -f "$f" ]; then awk -v c="$CUTOFF" '$1 >= c' "$f" | grep -c 'level=force'; else echo N/A; fi
pr-recheck	再度コメントチェック出現数	f=$HOME/.claude/history.jsonl; if [ -f "$f" ]; then cut=$(( $(date -j -f %Y-%m-%dT%H:%M:%S "${CUTOFF}T00:00:00" +%s) * 1000 )); jq -r --argjson c "$cut" 'select(.timestamp >= $c) | .display' "$f" | grep -cE '再度コメントチェック|違うコメント'; else echo N/A; fi
```

- [ ] **Step 2: 実 log に対して smoke run し、人力計測と突き合わせる**

```bash
VERIFICATION_TARGET_MD=/tmp/verification-smoke.md sh -c 'printf "## Verification\n" > "$VERIFICATION_TARGET_MD"; bash claude-code/scripts/verification-report.sh; cat "$VERIFICATION_TARGET_MD"'
```

Expected: 6 metric すべて数値または N/A (ERR が出たら該当 command を修正)。うち 1 件 (jp-100char) を手動 grep で再計算して一致を確認する:

```bash
awk -v c="$(date -v-7d +%Y-%m-%d)" '$1 >= c' ~/.claude/logs/jp-quality-block.log | grep -E ' \| (warn|block)$' | grep -c '100字超文'
```

一致しなければ TSV の command を実 log format に合わせて直す (特に jp-ng-block の `' | block$'` は禁止語行以外を拾っていないか目視 3 行確認)。

- [ ] **Step 3: commit**

```bash
git add claude-code/scripts/verification-metrics.tsv
git commit -m "feat(verification): 初期 6 metric の計測定義 TSV を追加する"
```

---

### Task 3: maintenance-cron-run.sh へ組み込み + 案内追記

**Files:**
- Modify: `claude-code/scripts/maintenance-cron-run.sh` (first-ctx-check 段の後、toolchain-health-report 段の前)
- Modify: `~/ai-tools/memory/pending-improvements.md` の Verification 節 (repo 外、commit 対象外)

**Interfaces:**
- Consumes: Task 1 の `verification-report.sh` (引数なし、default path 動作、常に exit 0 / 設定 error のみ exit 2)
- Produces: 週次 launchd job (`com.daichi.ai-tools-maintenance.weekly`) 経由の自動実行

- [ ] **Step 1: maintenance-cron-run.sh に段を足す**

`first-ctx-check` の段の直後に追記する:

```bash
# Verification 自動計測 (数値追記のみ、判断は retrospective に残す)
printf '=== verification-report (%s) ===\n' "$(date '+%F %T')" >> "$log_file"
"${REPO_ROOT}/scripts/verification-report.sh" >> "$log_file" 2>&1 \
  || printf 'WARN: verification-report failed\n' >> "$log_file"
```

- [ ] **Step 2: cron 経路の smoke (script 単体を default path で 1 回実行)**

```bash
bash claude-code/scripts/verification-report.sh
tail -10 ~/ai-tools/memory/pending-improvements.md
```

Expected: `appended:` 出力 + pending-improvements.md 末尾に当日 block。実運用初回追記なのでそのまま残す (rollback 不要、節は追記専用)。

- [ ] **Step 3: pending-improvements.md の Verification 節冒頭に運用 note を 1 行足す**

Verification 節 header 直下に追記する (Claude Code の Edit で行う):

```markdown
> 自動計測: 週次 maintenance cron が本節末尾へ「### 自動計測 YYYY-MM-DD」block を追記する (定義: `claude-code/scripts/verification-metrics.tsv`、追記は末尾限定・数値のみ)
```

- [ ] **Step 4: 既存 bats が壊れていないことを確認して commit**

```bash
bats claude-code/tests/integration/verification-report.bats
git add claude-code/scripts/maintenance-cron-run.sh
git commit -m "feat(verification): 週次 maintenance run に自動計測の段を追加する"
```

Expected: 5 tests, 0 failures → commit 成功

---

## 完了後

- worktree から main へ ff-merge して push する (ai-tools flow)
- 次回 retrospective で: 自動計測 block の数値を見て採否判断する。target の出し入れは TSV 編集 + prose 側は従来どおり
