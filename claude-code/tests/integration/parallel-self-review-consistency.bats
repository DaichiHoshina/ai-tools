#!/usr/bin/env bats
# =============================================================================
# /flow Self-Review 3 gate Consistency Tests
# =============================================================================
# 背景: parallel-self-review.md canonical と commands/flow.md summary の
# 二重管理が desync しないこと、Gate C の lens 分割が完全網羅・上限内に
# 収まることを機械的に検証する。
# =============================================================================

setup() {
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export CANONICAL_FILE="${PROJECT_ROOT}/references/parallel-self-review.md"
  export FLOW_FILE="${PROJECT_ROOT}/commands/flow.md"
}

# ---------------------------------------------------------------------------
# Gate A / B / C section が canonical に存在
# ---------------------------------------------------------------------------
@test "canonical: Gate A / B / C section が存在する" {
  [ -f "$CANONICAL_FILE" ]
  run grep -cE "^## Gate [ABC]:" "$CANONICAL_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -eq 3 ]
}

# ---------------------------------------------------------------------------
# flow.md summary が canonical を参照
# ---------------------------------------------------------------------------
@test "flow.md: parallel-self-review.md canonical 参照が存在" {
  [ -f "$FLOW_FILE" ]
  run grep -cF "references/parallel-self-review.md" "$FLOW_FILE"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# flow-auto.md は 2026-07-05 に /flow --auto へ統合済 (file 削除)。
# 旧 test "flow-auto.md: parallel-self-review.md canonical 参照が存在" は撤去した。

# ---------------------------------------------------------------------------
# Gate C lens 完全網羅 (12 lens 全部 canonical に列挙される)
# ---------------------------------------------------------------------------
@test "Gate C: 12 lens が canonical に完全列挙される" {
  local lenses=(
    "architecture"
    "quality"
    "readability"
    "security"
    "docs"
    "test-coverage"
    "root-cause"
    "logging"
    "writing"
    "silent-failure"
    "type-design"
    "db-concurrency"
  )
  for lens in "${lenses[@]}"; do
    run grep -qF "$lens" "$CANONICAL_FILE"
    [ "$status" -eq 0 ] || { echo "missing lens in canonical: $lens"; false; }
  done
}

# ---------------------------------------------------------------------------
# Gate C stage 分割が 8 Dev limit + 9 concurrent session limit 内
# ---------------------------------------------------------------------------
@test "Gate C: stage 1 + stage 2 lens 合計が 12 (重複なし、漏れなし)" {
  # canonical の "stage 1: N lens" "stage 2: M lens" を抽出して N + M == 12 を検証
  local s1=$(grep -oE "stage 1: [0-9]+ lens" "$CANONICAL_FILE" | head -1 | grep -oE "^stage 1: [0-9]+" | grep -oE "[0-9]+$")
  local s2=$(grep -oE "stage 2: [0-9]+ lens" "$CANONICAL_FILE" | head -1 | grep -oE "^stage 2: [0-9]+" | grep -oE "[0-9]+$")
  [ -n "$s1" ]
  [ -n "$s2" ]
  [ $((s1 + s2)) -eq 12 ] || { echo "lens total mismatch: stage1=$s1 stage2=$s2"; false; }
}

@test "Gate C: stage 1 agent 数が 8 Dev limit + 余裕 1 (= 7) 以下" {
  # canonical: "- stage 1: ... = N agent" の最後の N を取る
  local n=$(grep -E "^- stage 1:" "$CANONICAL_FILE" | head -1 | grep -oE "= [0-9]+ agent" | tail -1 | grep -oE "[0-9]+")
  [ -n "$n" ]
  [ "$n" -le 7 ]
}

@test "Gate C: stage 2 agent 数が 8 Dev limit + 余裕 1 (= 7) 以下" {
  local n=$(grep -E "^- stage 2:" "$CANONICAL_FILE" | head -1 | grep -oE "= [0-9]+ agent" | tail -1 | grep -oE "[0-9]+")
  [ -n "$n" ]
  [ "$n" -le 7 ]
}

# ---------------------------------------------------------------------------
# flow.md summary と canonical の数値整合 (二重管理 desync 検知)
# ---------------------------------------------------------------------------
@test "flow.md / canonical: Gate C stage 1 agent 数が一致" {
  # canonical: "stage 1 = N agent" (= の前後にスペースあり)
  # 末尾の "= N agent" だけ拾う (末尾が agent 数なので tail -1)
  local canon_n=$(grep -E "^- stage 1:" "$CANONICAL_FILE" | head -1 | grep -oE "= [0-9]+ agent" | tail -1 | grep -oE "[0-9]+")
  # flow.md L130: "stage 1=N agent"
  local flow_n=$(grep -oE "stage 1=[0-9]+ agent" "$FLOW_FILE" | head -1 | grep -oE "stage 1=[0-9]+" | grep -oE "[0-9]+$")
  [ -n "$canon_n" ]
  [ -n "$flow_n" ]
  [ "$canon_n" = "$flow_n" ] || { echo "stage 1 agent desync: canonical=$canon_n flow=$flow_n"; false; }
}

@test "flow.md / canonical: Gate C stage 2 agent 数が一致" {
  local canon_n=$(grep -E "^- stage 2:" "$CANONICAL_FILE" | head -1 | grep -oE "= [0-9]+ agent" | tail -1 | grep -oE "[0-9]+")
  local flow_n=$(grep -oE "stage 2=[0-9]+ agent" "$FLOW_FILE" | head -1 | grep -oE "stage 2=[0-9]+" | grep -oE "[0-9]+$")
  [ -n "$canon_n" ]
  [ -n "$flow_n" ]
  [ "$canon_n" = "$flow_n" ] || { echo "stage 2 agent desync: canonical=$canon_n flow=$flow_n"; false; }
}
