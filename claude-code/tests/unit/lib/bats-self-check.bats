#!/usr/bin/env bats
# =============================================================================
# BATS Tests for bats-self-check.sh
# Pass-by-Coincidence パターン検出
# =============================================================================

setup() {
  BATS_SELF_CHECK_TEST_SCRIPT="$(mktemp -t bsc-test.sh.XXXX)"
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../../.." && pwd)"
  LIB="${PROJECT_ROOT}/claude-code/lib/bats-self-check.sh"
}

teardown() {
  rm -f "$BATS_SELF_CHECK_TEST_SCRIPT"
}

# 外部スクリプトで実行（bats 環境での変数展開問題を回避）
run_check() {
  cat > "$BATS_SELF_CHECK_TEST_SCRIPT" <<EOF
#!/bin/bash
source $LIB
$@
EOF
  bash "$BATS_SELF_CHECK_TEST_SCRIPT"
}

@test "bats-self-check: ライブラリが読み込める" {
  run_check "[ -f $LIB ]"
}

@test "bats-self-check: run_bats_check 関数が定義可能" {
  run_check "run_bats_check /dev/null && echo ok" | grep -q ok
}

@test "bats-self-check: 不存在ファイル → exit 0（block しない）" {
  run_check "run_bats_check /tmp/no_such_file.bats"
}
