# Rule Recall Surface Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** rule-recall-surface の最終 review で triage された Minor 5 件をまとめて塞ぐ。regex metachar 誤爆・同日 2 回実行時の重複 block・threshold 未 validate・境界値 test 欠・metric hardcode note を 1 task で処理する。

**Architecture:** すべて既存 file の局所修正で、new file はない。runner script (`rule-recall-surface.sh`) に fix 3 件 (grep -F 化 / same-day dedupe / threshold validate) を当て、bats に境界 test 1 本を足し、`verification-metrics.tsv` の該当行に comment 1 行を添える。

**Tech Stack:** bash / bats (rule-recall と verification と同じ流儀)。

## Global Constraints

- 作業は worktree で行い、完了後 main へ cherry-pick する
- macOS の `date` を使う (`date -v-7d`)
- awk FS で pipe を区切りに使うときは `-F' [|] '` を使う (`-F' \| '` は BSD awk で壊れる)
- script 失敗で maintenance run 全体を巻き込まない (runner は常に exit 0、TSV/target 不在のみ exit 2)
- 追記先 md は末尾追記のみ、既存行の書き換え・削除はしない
- 追記した block を script 自身が読み返して idempotence 判定するのは可。ただし読み取りは末尾数十行に限定する (全文 grep は避ける)
- code comment は最小限 (default 書かない / 上限 2 行 / What 言い換え禁止)
- 完了宣言前に fresh bats 実行 → 出力全読 → 主張と一致確認 (verification-before-completion)

---

### Task 1: runner に 3 fix + bats 2 本追加 (境界 test + regex metachar test)

**Files:**
- Modify: `claude-code/scripts/rule-recall-surface.sh`
- Modify: `claude-code/tests/integration/rule-recall-surface.bats`

**Interfaces:**
- Consumes: なし (runner の内部変更のみ)
- Produces: (1) TSV pattern の literal 一致 (2) 同日重複 block の抑止 (3) 非数値 threshold の skip、の 3 保証を新たに満たす。bats 6 本 → 8 本 (境界 = / regex metachar) に増える

#### fix 1: `grep -c -- "$pattern"` → `grep -F -c -- "$pattern"` (line 33)

TSV pattern を BRE regex ではなく literal 文字列として扱う。将来 `unknown-en:` や `100.超文` のような metachar 混入 pattern を追加した時の silent over-count を防ぐ。

- [ ] **Step 1: regex metachar test を先に書いて RED を作る**

`claude-code/tests/integration/rule-recall-surface.bats` の既存 test 群の末尾に追加:

```bash
@test "pattern に regex metachar が入っても literal 一致で数える" {
  {
    printf '# id\tpattern\trule\tthreshold\n'
    printf 'p-metachar\t100.超文\trules/plain-jp.md\t0\n'
  } > "$RECALL_PATTERNS_TSV"
  {
    printf '2026-07-14T10:00:00+0900 | chat | structural: 100.超文 1文 | warn\n'
    printf '2026-07-15T10:00:00+0900 | chat | structural: 100X超文 1文 | warn\n'
    printf '2026-07-16T10:00:00+0900 | chat | structural: 100Y超文 1文 | warn\n'
  } > "$RECALL_LOG"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q '^- p-metachar: 1 件 (100\.超文' "$RECALL_TARGET_MD"
}
```

- [ ] **Step 2: test が fail することを確認する**

Run: `CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/integration/rule-recall-surface.bats`
Expected: 新規 test 1 本が FAIL (grep が `.` を任意 1 文字として解釈し 3 件になる)

- [ ] **Step 3: `grep -c` → `grep -F -c` に変える**

`claude-code/scripts/rule-recall-surface.sh:33` の該当行を以下に置換:

```bash
count="$(awk -F' [|] ' -v c="$CUTOFF" '$1 >= c { print $3 }' "$LOG_FILE" | grep -F -c -- "$pattern")"
```

- [ ] **Step 4: test が pass することを確認する**

Run: `CLAUDE_PROJECT_DIR=/Users/daichi.hoshina/ghq/github.com/DaichiHoshina/ai-tools bats claude-code/tests/integration/rule-recall-surface.bats`
Expected: 全 test pass (既存 6 本 + 新規 1 本 = 7 本、0 failures)

#### fix 2: 同日重複 block の抑止

runner 冒頭で target md 末尾数十行を読み、当日 header (`### 昇格候補 YYYY-MM-DD`) が既にあれば追記せず「skip: same-day block exists」を stdout に出して exit 0 する。

- [ ] **Step 1: 同日重複 test を追加する**

同 bats file の末尾に追加:

```bash
@test "同日 2 回実行しても block は 1 個だけ (2 回目は skip)" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  today_header_count="$(grep -c '^### 昇格候補 ' "$RECALL_TARGET_MD")"
  [ "$today_header_count" -eq 1 ]
}
```

- [ ] **Step 2: test が fail することを確認する**

Run: 上と同じ command
Expected: 新規 test 1 本が FAIL (2 個目の header が付いて count=2 になる)

- [ ] **Step 3: runner に same-day guard を足す**

`claude-code/scripts/rule-recall-surface.sh` の `block=` を組む前 (line 26 と 27 の間) に以下を挿入:

```bash
today_header="### 昇格候補 $(date +%Y-%m-%d)"
if tail -n 40 "$TARGET_MD" 2>/dev/null | grep -qF -- "$today_header"; then
  echo "skip: same-day block already exists in $TARGET_MD"
  exit 0
fi
```

`tail -n 40` は「同日追記が末尾数十行に収まる前提」の割り切り。verification-report block と自 block を合わせても 20 行以下なので 40 行で十分。

- [ ] **Step 4: 全 test が pass することを確認する**

Run: 上と同じ command
Expected: 全 test pass (既存 6 + regex metachar 1 + same-day 1 = 8 本、0 failures)

#### fix 3: 非数値 threshold の skip

TSV の threshold field が非数値 (空文字 / 負数 / 文字混じり) のとき、runner が「0 件で閾値超」と誤って surface するのを防ぐ。既存 test では 0 件は surface されない (`count > threshold` の strict `>` で 0 > 0 が false) が、threshold が負数 (`-1`) の場合は `0 > -1` が true になり「0 件」と surface される。

- [ ] **Step 1: 非数値 threshold test を追加する**

同 bats file の末尾に追加:

```bash
@test "非数値 threshold の行は skip される (0 件で surface しない)" {
  {
    printf '# id\tpattern\trule\tthreshold\n'
    printf 'p-negative\t絶対に出ない\trules/plain-jp.md\t-1\n'
    printf 'p-empty\t絶対に出ない\trules/plain-jp.md\t\n'
  } > "$RECALL_PATTERNS_TSV"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q '^- p-negative:' "$RECALL_TARGET_MD"
  ! grep -q '^- p-empty:' "$RECALL_TARGET_MD"
}
```

- [ ] **Step 2: test が fail することを確認する**

Expected: 新規 test 1 本が FAIL (p-negative が「0 件」で surface される)

- [ ] **Step 3: runner に threshold 検証を足す**

`claude-code/scripts/rule-recall-surface.sh` の `while IFS=$'\t' read -r id pattern rule threshold; do` の直後、`[[ -z "$id" || "$id" == \#* ]] && continue` の次の行に挿入:

```bash
[[ "$threshold" =~ ^[0-9]+$ ]] || continue
```

正の整数 (0 含む) 以外は skip する。0 も含めるのは「pattern を list に載せるが surface はしない」用途 (dry run) を残せるため。

- [ ] **Step 4: 全 test が pass することを確認する**

Expected: 全 test pass (既存 6 + regex 1 + same-day 1 + threshold 1 = 9 本、0 failures)

#### 境界値 test の追加 (`count == threshold` は surface されない)

- [ ] **Step 1: 境界 test を追加する**

同 bats file の末尾に追加:

```bash
@test "count == threshold は surface されない (strict >)" {
  {
    printf '# id\tpattern\trule\tthreshold\n'
    printf 'p-boundary\t100字超文\trules/plain-jp.md\t3\n'
  } > "$RECALL_PATTERNS_TSV"
  # 3 件 hit vs threshold 3 (equal) → surface されない、「該当なし」1 行が出る
  {
    printf '2026-07-14T10:00:00+0900 | chat | structural: 100字超文 4文 | warn\n'
    printf '2026-07-15T10:00:00+0900 | chat | structural: 100字超文 2文 | block\n'
    printf '2026-07-16T10:00:00+0900 | chat | structural: 100字超文 5文 | warn\n'
  } > "$RECALL_LOG"
  run bash "$SCRIPT"
  ! grep -q '^- p-boundary:' "$RECALL_TARGET_MD"
  grep -q '^- 該当なし' "$RECALL_TARGET_MD"
}
```

- [ ] **Step 2: 全 test が pass することを確認する**

Expected: 全 test pass (既存 6 + regex 1 + same-day 1 + threshold 1 + boundary 1 = 10 本、0 failures)

#### commit

- [ ] **commit**

```bash
git add claude-code/scripts/rule-recall-surface.sh claude-code/tests/integration/rule-recall-surface.bats
git commit -m "fix(recall): regex metachar 対策・同日重複抑止・threshold validate と bats 4 本追加する"
```

---

### Task 2: verification-metrics.tsv の recall-surfaced 行に hardcode note を添える

**Files:**
- Modify: `claude-code/scripts/verification-metrics.tsv`

**Interfaces:**
- Consumes: なし
- Produces: recall-surfaced 行の説明 field に「patterns / threshold は TSV 側と手動で同期する」旨を追記する。TSV 内で完結する

- [ ] **Step 1: 説明 field を書き換える**

`claude-code/scripts/verification-metrics.tsv` の recall-surfaced 行の 2 列目 (説明) を以下に置換:

```
昇格候補件数 (patterns / threshold は rule-recall-patterns.tsv と手動で同期する、初期は 100字超文 / 完了 / 100)
```

現行の説明文 (`昇格候補件数 (rule-recall-surface で閾値超えた pattern の週次件数)`) と入れ替える。command 列と threshold 値は変えない。

- [ ] **Step 2: tab 数と smoke で regression がないことを確認する**

```bash
awk -F'\t' '{print NF}' claude-code/scripts/verification-metrics.tsv
VERIFICATION_TARGET_MD=/tmp/verification-smoke-followup.md sh -c 'printf "## Verification\n" > "$VERIFICATION_TARGET_MD"; bash claude-code/scripts/verification-report.sh; grep recall-surfaced "$VERIFICATION_TARGET_MD"'
```

Expected: 全行 NF=3、smoke で `recall-surfaced: <数値> (patterns / threshold は …)` が出る。

- [ ] **Step 3: commit**

```bash
git add claude-code/scripts/verification-metrics.tsv
git commit -m "docs(recall): recall-surfaced metric に hardcode 同期 note を添える"
```

---

## 完了後

- worktree から main へ cherry-pick で反映して push する
- 次回 retrospective で: recall-surfaced の値が引き続き 2 か、pattern 追加時に metric hardcode を忘れずに更新できたかを確認する
