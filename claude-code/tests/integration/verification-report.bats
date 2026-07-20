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
