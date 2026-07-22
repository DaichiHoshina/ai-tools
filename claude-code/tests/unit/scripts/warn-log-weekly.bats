#!/usr/bin/env bats
# Smoke test: warn-log-weekly.sh
#   4-way log format 分岐 (bracket_pipe / tab_file / tab_severity / pipe_nobracket) の
#   抽出 / 集計 / date filter / 未知 basename fallback を確認する。

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  export PROJECT_ROOT
  export SCRIPT_FILE="${PROJECT_ROOT}/scripts/warn-log-weekly.sh"
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  # LOG_DIR / OUT_DIR は script 内で常に "${HOME}/.claude/logs" になるため、
  # HOME を tmpdir に差し替えるだけで実 ~/.claude/logs を一切触らずに完結する。
  LOG_DIR="$TEST_HOME/.claude/logs"
  export LOG_DIR
  mkdir -p "$LOG_DIR"
}

teardown() {
  [[ -d "${TEST_HOME:-}" ]] && rm -rf "$TEST_HOME"
}

_ts_days_ago() {
  date -v-"$1"d +%Y-%m-%dT%H:%M:%S
}

@test "bracket_pipe (review-pattern-warn.log): pattern 別 breakdown が正しい" {
  local ts
  ts="$(_ts_days_ago 2)"
  {
    printf '[%s] sess1 | migration-safety | /a/b.sql | created_at 欠如\n' "$ts"
    printf '[%s] sess1 | migration-safety | /a/c.sql | updated_at 欠如\n' "$ts"
    printf '[%s] sess1 | churn | /a/d.sh | 3\n' "$ts"
  } > "$LOG_DIR/review-pattern-warn.log"

  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "migration-safety +2"
  echo "$output" | grep -qE "churn +1"
}

@test "tab_file (comment-style-warn.log): file 別 breakdown が正しい" {
  local ts
  ts="$(_ts_days_ago 2)"
  {
    printf '%s\tsess1\tfoo.sh\t体言止め行A\n' "$ts"
    printf '%s\tsess1\tfoo.sh\t体言止め行B\n' "$ts"
    printf '%s\tsess1\tbar.sh\t体言止め行C\n' "$ts"
  } > "$LOG_DIR/comment-style-warn.log"

  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "foo\.sh +2"
  echo "$output" | grep -qE "bar\.sh +1"
}

@test "tab_severity (comment-quantity-warn.log): severity 別 breakdown が正しい" {
  local ts
  ts="$(_ts_days_ago 2)"
  {
    printf '%s\tsess1\tfoo.sh\t2\twarn\n' "$ts"
    printf '%s\tsess1\tbar.sh\t2\twarn\n' "$ts"
    printf '%s\tsess1\tbaz.sh\t3\tblock\n' "$ts"
  } > "$LOG_DIR/comment-quantity-warn.log"

  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "warn +2"
  echo "$output" | grep -qE "block +1"
}

@test "pipe_nobracket (bundle-violation-warn.log): dev_count=N は dev_count に正規化して集約する" {
  local ts
  ts="$(_ts_days_ago 2)"
  {
    printf '%s | sess1 | dev_count=3 | elapsed_ms=100\n' "$ts"
    printf '%s | sess1 | dev_count=5 | elapsed_ms=200\n' "$ts"
    printf '%s | sess1 | dev_count=2 | elapsed_ms=300\n' "$ts"
  } > "$LOG_DIR/bundle-violation-warn.log"

  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  # 値違いの dev_count=N が単一 key "dev_count" に集約されること (fragmented しないこと)
  echo "$output" | grep -qE "dev_count +3"
  ! echo "$output" | grep -qE "dev_count=[0-9]"
}

@test "date filter: last week / this week の entry が正しく分かれる" {
  local ts_last ts_this
  ts_last="$(_ts_days_ago 10)"
  ts_this="$(_ts_days_ago 2)"
  {
    printf '[%s] sess1 | churn | /a.sh | 3\n' "$ts_last"
    printf '[%s] sess1 | churn | /a.sh | 3\n' "$ts_this"
  } > "$LOG_DIR/review-pattern-warn.log"

  run bash "$SCRIPT_FILE"
  [ "$status" -eq 0 ]
  echo "$output" | grep -qE "review-pattern-warn\.log +\(this=1 / last=1 / "
}

@test "log_format: 未知 basename は bracket_pipe へ fallback する (仕様)" {
  run bash -c "
    source <(sed -n '1,/^{\$/p' '$SCRIPT_FILE' | sed '\$d')
    log_format 'totally-unknown-log-name.log'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "bracket_pipe" ]
}
