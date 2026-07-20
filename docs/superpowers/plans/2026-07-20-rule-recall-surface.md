# Rule Recall Surface (週次) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** hook block/warn の pattern 発生数を週次で集計し、閾値 (週 100 件超) を越えた pattern を「CLAUDE.md 冒頭 header への昇格候補」として pending-improvements.md に surface する。人が retrospective で triage する前提で、自動 rule 書き換えはしない。

**Architecture:** pattern → 起点 rule file の対応表 TSV (`rule-recall-patterns.tsv`, id/pattern/rule/threshold の 4 列) と、直近 7 日の `jp-quality-block.log` を集計して閾値超 pattern を追記する runner script (`rule-recall-surface.sh`) を新設する。週次 maintenance cron が verification-report の後段で実行する。verification-metrics.tsv には「昇格候補件数」metric を 1 行足し、trend を数値化する。

**Tech Stack:** bash / awk / bats (verification-report と同じ流儀)。

## Global Constraints

- 作業は worktree で行い、完了後 main へ cherry-pick する (`references/on-demand-rules/ai-tools-worktree-flow.md`。ff-merge は別 session commit が入っていた場合 fail するため cherry-pick 経路を第一手にする)
- macOS の `date` を使う (`date -v-7d`、GNU 形式 `date -d` は不可)
- script 失敗で maintenance run 全体を巻き込まない: pattern 単位で握り、`rule-recall-surface.sh` は常に exit 0 (TSV 不在等の設定 error のみ exit 2)
- 追記先 md (`~/ai-tools/memory/pending-improvements.md`) は末尾追記のみ。既存行の書き換え・削除はしない
- 追記 section header は verification-report と区別できるもの (`### 昇格候補 YYYY-MM-DD`)
- 自動で rule file は書き換えない。判断は人 (retrospective)
- 閾値は pattern ごとに TSV で持つ。初期値は「週 100 件超」を全 pattern に適用する
- 初期 pattern は 2 件のみ (100字超文 / 完了)。他 pattern (unknown-en / 禁止語 block 等) は初期投入せず、trend を見て後で足す
- TSV の pattern / rule / threshold field 内に literal tab を入れない
- code comment は最小限 (default 書かない / 上限 2 行 / What 言い換え禁止)
- 完了宣言前に verification-before-completion skill の gate を通す (bats fresh 実行 → 出力全読 → 主張と一致確認)

---

### Task 1: rule-recall-surface.sh 本体 + bats test

**Files:**
- Create: `claude-code/scripts/rule-recall-surface.sh`
- Test: `claude-code/tests/integration/rule-recall-surface.bats`

**Interfaces:**
- Consumes: なし (独立)
- Produces: `rule-recall-surface.sh` — env `RECALL_PATTERNS_TSV` / `RECALL_TARGET_MD` / `RECALL_LOG` / `RECALL_CUTOFF` で入出力を差し替え可能。集計対象 log は `~/.claude/logs/jp-quality-block.log` (default、env override 可)。常に exit 0 (TSV/target 不在等の設定 error のみ exit 2)。TSV 各行の pattern を grep して直近 7 日 (`$1 >= CUTOFF` の lexicographic 比較) の hit 数を数え、threshold 超過時のみ追記 block に 1 行出す。閾値未満は追記しない (block header は必ず出すが、中身は「該当なし」を明示する)

- [ ] **Step 1: failing test を書く**

`claude-code/tests/integration/rule-recall-surface.bats` を以下の内容で作る:

```bash
#!/usr/bin/env bats
# rule-recall-surface.sh の閾値判定 / 追記 block 形式 / N/A 経路を検証する

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/rule-recall-surface.sh"
  TMPDIR_T="$(mktemp -d)"
  export RECALL_TARGET_MD="$TMPDIR_T/pending.md"
  export RECALL_PATTERNS_TSV="$TMPDIR_T/patterns.tsv"
  export RECALL_LOG="$TMPDIR_T/jp-quality-block.log"
  export RECALL_CUTOFF="2026-07-13"
  printf '## Verification\n\n- 既存行はそのまま残る\n' > "$RECALL_TARGET_MD"
  # 列区切り literal tab。閾値 = 2 で境界を作る
  {
    printf '# id\tpattern\trule\tthreshold\n'
    printf 'p-over\t100字超文\trules/plain-jp.md\t2\n'
    printf 'p-under\t完了\trules/plain-jp.md\t2\n'
    printf 'p-zero\t絶対に出ない語\trules/plain-jp.md\t2\n'
  } > "$RECALL_PATTERNS_TSV"
  # 3 件 hit (over) / 1 件 hit (under) / 0 件 (zero)、cutoff より古い line は無視される
  {
    printf '2026-07-14T10:00:00+0900 | chat | structural: 100字超文 4文 | warn\n'
    printf '2026-07-15T10:00:00+0900 | chat | structural: 100字超文 2文 | block\n'
    printf '2026-07-16T10:00:00+0900 | chat | structural: 100字超文 5文 | warn\n'
    printf '2026-07-14T10:00:00+0900 | chat | 完了,maintenance | warn\n'
    printf '2026-07-10T10:00:00+0900 | chat | structural: 100字超文 1文 | warn\n'
  } > "$RECALL_LOG"
}

teardown() { rm -rf "$TMPDIR_T"; }

@test "block header が末尾に追記される (既存行は不変)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '^### 昇格候補 20' "$RECALL_TARGET_MD"
  grep -q '^- 既存行はそのまま残る$' "$RECALL_TARGET_MD"
}

@test "閾値超 pattern は 1 行として列挙される (件数 / 対応 rule 込み)" {
  run bash "$SCRIPT"
  grep -q '^- p-over: 3 件 (100字超文 → rules/plain-jp.md、閾値 2)$' "$RECALL_TARGET_MD"
}

@test "閾値未満の pattern は列挙されない" {
  run bash "$SCRIPT"
  ! grep -q '^- p-under:' "$RECALL_TARGET_MD"
  ! grep -q '^- p-zero:' "$RECALL_TARGET_MD"
}

@test "全 pattern が閾値未満なら「該当なし」1 行だけ出す" {
  # 閾値を全部 100 に上げる (全 pattern 未満に転落)
  {
    printf '# id\tpattern\trule\tthreshold\n'
    printf 'p-over\t100字超文\trules/plain-jp.md\t100\n'
  } > "$RECALL_PATTERNS_TSV"
  run bash "$SCRIPT"
  grep -q '^- 該当なし (全 pattern 閾値未満)$' "$RECALL_TARGET_MD"
}

@test "log 不在なら block header + N/A 1 行 (script は exit 0)" {
  rm "$RECALL_LOG"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '^- N/A (log 不在: ' "$RECALL_TARGET_MD"
}

@test "TSV 不在なら exit 2 で target md は不変" {
  rm "$RECALL_PATTERNS_TSV"
  before="$(cat "$RECALL_TARGET_MD")"
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [ "$(cat "$RECALL_TARGET_MD")" = "$before" ]
}
```

- [ ] **Step 2: test が fail することを確認する**

Run: `CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/integration/rule-recall-surface.bats`
Expected: 全 6 test FAIL (script 不在で exit 127)

- [ ] **Step 3: script を実装する**

`claude-code/scripts/rule-recall-surface.sh` を以下の内容で作る (`chmod +x` する):

```bash
#!/usr/bin/env bash
# 週次 rule recall surface (maintenance-cron-run.sh から呼ばれる)
# rule-recall-patterns.tsv の各 pattern の 7 日 hit 数を数え、閾値超のみ pending-improvements.md 末尾へ追記する
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATTERNS_TSV="${RECALL_PATTERNS_TSV:-${REPO_ROOT}/scripts/rule-recall-patterns.tsv}"
TARGET_MD="${RECALL_TARGET_MD:-${HOME}/ai-tools/memory/pending-improvements.md}"
LOG_FILE="${RECALL_LOG:-${HOME}/.claude/logs/jp-quality-block.log}"
CUTOFF="${RECALL_CUTOFF:-$(date -v-7d +%Y-%m-%d)}"

if [[ ! -f "$PATTERNS_TSV" ]]; then
  echo "ERROR: patterns TSV が見つからない: $PATTERNS_TSV" >&2
  exit 2
fi
if [[ ! -f "$TARGET_MD" ]]; then
  echo "ERROR: 追記先 md が見つからない: $TARGET_MD" >&2
  exit 2
fi

block="### 昇格候補 $(date +%Y-%m-%d) (window: ${CUTOFF} 以降、閾値超のみ)"$'\n'

if [[ ! -f "$LOG_FILE" ]]; then
  block+="- N/A (log 不在: ${LOG_FILE})"$'\n'
  printf '\n%s' "$block" >> "$TARGET_MD"
  echo "appended: $TARGET_MD"
  exit 0
fi

hit_count=0
while IFS=$'\t' read -r id pattern rule threshold; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  count="$(awk -F' \\| ' -v c="$CUTOFF" '$1 >= c { print $3 }' "$LOG_FILE" | grep -c -- "$pattern")"
  count="${count:-0}"
  if (( count > threshold )); then
    block+="- ${id}: ${count} 件 (${pattern} → ${rule}、閾値 ${threshold})"$'\n'
    hit_count=$((hit_count + 1))
  fi
done < "$PATTERNS_TSV"

if (( hit_count == 0 )); then
  block+="- 該当なし (全 pattern 閾値未満)"$'\n'
fi

printf '\n%s' "$block" >> "$TARGET_MD"
echo "appended: $TARGET_MD"
```

実装 note: `grep -c` は 0 件時に「0 を出力して exit 1」するため exit code は判定しない。stdout の 0 を採って `count="${count:-0}"` で空を 0 に丸める。`(( count > threshold ))` は integer 比較で閾値超のみ拾う。

- [ ] **Step 4: test が pass することを確認する**

Run: `CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/integration/rule-recall-surface.bats`
Expected: 6 tests, 0 failures

- [ ] **Step 5: commit**

```bash
git add claude-code/scripts/rule-recall-surface.sh claude-code/tests/integration/rule-recall-surface.bats
git commit -m "feat(recall): rule recall surface script と bats test を追加する"
```

---

### Task 2: rule-recall-patterns.tsv (初期 2 pattern) + 実 log smoke

**Files:**
- Create: `claude-code/scripts/rule-recall-patterns.tsv`

**Interfaces:**
- Consumes: Task 1 の 4 列 TSV 契約 (id / pattern / rule / threshold)
- Produces: 初期 2 pattern の定義 (100字超文 / 完了、閾値 100)

- [ ] **Step 1: TSV を作る**

列区切りは literal tab (エディタで tab を直接入力する):

```text
# id<TAB>pattern<TAB>rule<TAB>threshold
recall-100char	100字超文	rules/plain-jp.md	100
recall-kanryo	完了	rules/plain-jp.md	100
```

- [ ] **Step 2: 実 log に対して smoke run し、直近 7 日の hit 数と閾値の関係を確認する**

```bash
RECALL_TARGET_MD=/tmp/recall-smoke.md sh -c 'printf "## Verification\n" > "$RECALL_TARGET_MD"; bash claude-code/scripts/rule-recall-surface.sh; cat "$RECALL_TARGET_MD"'
```

Expected: block header が出て、直近 7 日の実 log で 100 件超えていれば pattern 行が出る、超えていなければ「該当なし」が出る。independent 再計算:

```bash
awk -v c="$(date -v-7d +%Y-%m-%d)" '$1 >= c' ~/.claude/logs/jp-quality-block.log | grep -c '100字超文'
awk -v c="$(date -v-7d +%Y-%m-%d)" '$1 >= c' ~/.claude/logs/jp-quality-block.log | grep -c '完了'
```

pattern 行の件数と一致することを確認する。

- [ ] **Step 3: commit**

```bash
git add claude-code/scripts/rule-recall-patterns.tsv
git commit -m "feat(recall): 初期 2 pattern の対応表 TSV を追加する (閾値 100)"
```

---

### Task 3: maintenance-cron-run.sh 組み込み + verification-metrics.tsv に metric 1 行追加

**Files:**
- Modify: `claude-code/scripts/maintenance-cron-run.sh` (verification-report 段の後、toolchain-health-report 段の前)
- Modify: `claude-code/scripts/verification-metrics.tsv` (末尾に 1 行追加)

**Interfaces:**
- Consumes: Task 1 の `rule-recall-surface.sh` (引数なし、default path 動作、常に exit 0 / 設定 error のみ exit 2)
- Produces: 週次 launchd job 経由の自動実行 + 「昇格候補件数」metric の verification block への継続追記

- [ ] **Step 1: maintenance-cron-run.sh に段を足す**

`verification-report` の段の直後に追記する (surface が verification と時系列で連続する形):

```bash
# rule recall surface (閾値超 pattern の昇格候補を surface、判断は retrospective に残す)
printf '=== rule-recall-surface (%s) ===\n' "$(date '+%F %T')" >> "$log_file"
"${REPO_ROOT}/scripts/rule-recall-surface.sh" >> "$log_file" 2>&1 \
  || printf 'WARN: rule-recall-surface failed\n' >> "$log_file"
```

- [ ] **Step 2: verification-metrics.tsv に「昇格候補件数」metric を 1 行足す**

末尾に追加 (literal tab 区切り):

```text
recall-surfaced	昇格候補件数 (rule-recall-surface で閾値超えた pattern の週次件数)	f=$HOME/.claude/logs/jp-quality-block.log; if [ -f "$f" ]; then awk -v c="$CUTOFF" '$1 >= c { if ($3 ~ /100字超文/) c100++; if ($3 ~ /完了/) ck++ } END { n=0; if (c100 > 100) n++; if (ck > 100) n++; print n }' "$f"; else echo N/A; fi
```

実装 note: metric は「今週 surface されたはずの pattern 数」を独立に awk で再計算する。surface script の追記結果を parse するのではなく log を直接読むことで、surface script が失敗しても数値は出る。閾値 100 は TSV の初期値と揃える (将来乖離したら手直しする、初期 2 pattern だけの割り切り)。

- [ ] **Step 3: smoke run で cron 経路を確認する**

```bash
bash claude-code/scripts/rule-recall-surface.sh
tail -8 ~/ai-tools/memory/pending-improvements.md
bash claude-code/scripts/verification-report.sh
tail -12 ~/ai-tools/memory/pending-improvements.md
```

Expected: `### 昇格候補 YYYY-MM-DD` block と、その後の `### 自動計測 YYYY-MM-DD` block に `recall-surfaced: N` 行が入る。ERR / 予期せぬ N/A が出ないこと。

- [ ] **Step 4: bats regression と bash -n を確認して commit**

```bash
CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/integration/verification-report.bats claude-code/tests/integration/rule-recall-surface.bats
bash -n claude-code/scripts/maintenance-cron-run.sh
git add claude-code/scripts/maintenance-cron-run.sh claude-code/scripts/verification-metrics.tsv
git commit -m "feat(recall): 週次 maintenance run に rule recall surface を組み込み、metric に昇格候補件数を追加する"
```

Expected: bats 5 (verification) + 6 (recall) = 11 tests, 0 failures / syntax OK

---

## 完了後

- worktree から main へ cherry-pick で反映して push する (別 session commit で ff-merge fail する可能性が高いので cherry-pick を第一手にする)
- 次回 retrospective で: 昇格候補 block に出た pattern を「header 昇格」「保留」「rule 修正」で triage する。閾値 100 は初期値、triage 感覚がついてから見直す
