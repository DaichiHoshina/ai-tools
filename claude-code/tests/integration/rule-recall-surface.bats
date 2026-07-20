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
