#!/usr/bin/env bats
# Smoke test: flow-baseline-summary-cron.sh
#   dedup / 時刻フィルタ / --diff / 異常系の動作確認。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROJECT_ROOT
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/flow-baseline-summary-cron.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  mkdir -p "${TEST_HOME}/.claude/logs"
  LOG_DIR="${TEST_HOME}/.claude/logs"
  export LOG_DIR
  TSV_HEADER=$'date\tsession_id\ttopic\tn_dev_agents\tpeak_concurrency\ttotal_wall_sec\tavg_task_sec\tbundle_violations\tnote\tcost_usd\tmsg_count\ttoken_used\treview_iter'
  export TSV_HEADER
}

teardown() {
  [[ -d "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
}

_date_ymd_ago() {
  date -v-"$1"d +%Y%m%d 2>/dev/null || date -d "$1 days ago" +%Y%m%d
}

_ts_ago() {
  date -v-"$1"d '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -d "$1 days ago" '+%Y-%m-%dT%H:%M:%S'
}

@test "--help は usage を表示して exit 0" {
  run bash "$SCRIPT_FILE" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage: flow-baseline-summary-cron.sh" ]]
}

@test "TSV も warn log も無い状態でクラッシュしない" {
  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "files: 0"
  echo "$output" | grep -q "rows(dedup): 0"
  echo "$output" | grep -q "count: 0"
}

@test "dedup: 同一 8 key 行が複数 TSV に重複しても集計は 1 回だけ" {
  local d1 d2 dup_row uniq_row
  d1="$(_date_ymd_ago 1)"
  d2="$(_date_ymd_ago 0)"
  dup_row=$'2026-07-18\tsess-abc\ttopic-x\t4\t3\t100\t20\t4\tnote1\t1.0\t10\t100\t0'
  uniq_row=$'2026-07-19\tsess-def\ttopic-y\t2\t1\t50\t10\t0\tnote2\t0.5\t5\t50\t0'

  printf '%s\n%s\n' "$TSV_HEADER" "$dup_row" > "${LOG_DIR}/flow-baseline-${d1}.tsv"
  printf '%s\n%s\n%s\n' "$TSV_HEADER" "$dup_row" "$uniq_row" > "${LOG_DIR}/flow-baseline-${d2}.tsv"

  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "rows(dedup): 2"
  echo "$output" | grep -q "n_dev=4    count=1"
  echo "$output" | grep -q "n_dev=2    count=1"
}

@test "時刻フィルタ: cutoff 前の scope_declared_mismatch は window 外でカウントされない" {
  local ts_old ts_recent
  ts_old="$(_ts_ago 10)"
  ts_recent="$(_ts_ago 1)"
  {
    printf '%s | sess-old | scope_declared_mismatch | declared_n=2 | elapsed_ms=100\n' "$ts_old"
    printf '%s | sess-new | scope_declared_mismatch | declared_n=3 | elapsed_ms=200\n' "$ts_recent"
  } > "${LOG_DIR}/bundle-violation-warn.log"

  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out" --warn-since 3d
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "count: 1"
}

@test "dev_count= / serial_reason_declared は scope_declared_mismatch としてカウントされない" {
  local ts_recent
  ts_recent="$(_ts_ago 1)"
  {
    printf '%s | sess-a | dev_count=2 | elapsed_ms=100\n' "$ts_recent"
    printf '%s | sess-b | serial_reason_declared | elapsed_ms=200\n' "$ts_recent"
  } > "${LOG_DIR}/bundle-violation-warn.log"

  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out" --warn-since 7d
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "count: 0"
}

@test "--tsv-since / --warn-since override が反映される" {
  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out" --tsv-since 5d --warn-since 2d
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "since 5d"
  echo "$output" | grep -q "since 2d"
}

@test "出力ファイルが生成されセクション見出しを含む" {
  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out"
  [ "$status" -eq 0 ]
  local today
  today="$(date +%Y%m%d)"
  [ -f "${TEST_HOME}/out/flow-baseline-summary-${today}.log" ]
  [ -f "${TEST_HOME}/out/flow-baseline-summary-history.tsv" ]
  grep -q "=== flow-baseline TSV 集計" "${TEST_HOME}/out/flow-baseline-summary-${today}.log"
  grep -q "=== bundle-violation scope_declared_mismatch" "${TEST_HOME}/out/flow-baseline-summary-${today}.log"
}

@test "--diff は history TSV の前回行と比較表示する" {
  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out"
  [ "$status" -eq 0 ]

  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out" --diff
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "=== --diff: 前回 history 行との比較 ==="
  echo "$output" | grep -q "prev: date="
  echo "$output" | grep -q "curr: date="
  [ "$(wc -l < "${TEST_HOME}/out/flow-baseline-summary-history.tsv" | tr -d ' ')" -eq 3 ]
}

@test "列数不足の壊れた TSV 行でクラッシュしない" {
  local d broken_row
  d="$(_date_ymd_ago 0)"
  broken_row=$'broken\trow\tonly3'
  printf '%s\n%s\n' "$TSV_HEADER" "$broken_row" > "${LOG_DIR}/flow-baseline-${d}.tsv"

  run bash "$SCRIPT_FILE" --out-dir "${TEST_HOME}/out"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "rows(dedup): 0"
}
